import Foundation
import AppKit
import Combine
import CoreGraphics

@MainActor
public final class QuickLaunchService: ObservableObject {
    public static let shared = QuickLaunchService()

    @Published public private(set) var pinnedApps: [PinnedApp] = []
    private let storageKey = "jbar.pinned_apps"

    private init() {
        loadPinnedApps()
    }

    public func loadPinnedApps() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let apps = try? JSONDecoder().decode([PinnedApp].self, from: data) {
            self.pinnedApps = apps
        } else {
            // Default initial quick launch items
            var defaults: [PinnedApp] = []
            let candidates = [
                "/System/Library/CoreServices/Finder.app",
                "/Applications/Firefox.app",
                "/Applications/Google Chrome.app",
                "/Applications/Safari.app",
                "/Applications/Ghostty.app",
                "/System/Applications/Utilities/Terminal.app"
            ]

            for path in candidates {
                if FileManager.default.fileExists(atPath: path) {
                    let url = URL(fileURLWithPath: path)
                    let name = url.deletingPathExtension().lastPathComponent
                    defaults.append(PinnedApp(name: name, path: path))
                    if defaults.count >= 3 { break }
                }
            }
            self.pinnedApps = defaults
            savePinnedApps()
        }
    }

    public func savePinnedApps() {
        if let data = try? JSONEncoder().encode(pinnedApps) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    public func isPinned(_ path: String) -> Bool {
        pinnedApps.contains { $0.path == path || ($0.name.lowercased() == "finder" && path.contains("Finder.app")) }
    }

    public func pin(app: InstalledAppInfo) {
        guard !isPinned(app.url.path) else { return }
        let pinned = PinnedApp(name: app.name, path: app.url.path)
        pinnedApps.append(pinned)
        savePinnedApps()
    }

    public func pin(path: String) {
        guard !isPinned(path), FileManager.default.fileExists(atPath: path) else { return }
        let url = URL(fileURLWithPath: path)
        let name = url.deletingPathExtension().lastPathComponent
        let pinned = PinnedApp(name: name, path: path)
        pinnedApps.append(pinned)
        savePinnedApps()
    }

    public func unpin(_ pinned: PinnedApp) {
        pinnedApps.removeAll { $0.id == pinned.id }
        savePinnedApps()
    }

    public func launch(_ pinned: PinnedApp, newWindow: Bool = true) {
        let url = pinned.url
        let name = pinned.name
        let bundleID = Bundle(url: url)?.bundleIdentifier

        if let running = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleURL?.path == pinned.path ||
            $0.localizedName?.lowercased() == name.lowercased() ||
            (bundleID != nil && $0.bundleIdentifier == bundleID)
        }) {
            if newWindow {
                Self.openNewWindow(for: running, url: url, name: name)
            } else {
                running.activate()
                AppIndexService.launchApp(url: url, name: name)
            }
        } else {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
        }
    }

    public static func openNewWindow(for app: NSRunningApplication, url: URL, name: String) {
        let pid = app.processIdentifier
        let bundleID = app.bundleIdentifier ?? Bundle(url: url)?.bundleIdentifier ?? ""

        app.activate()

        // 1. Scriptable app specialization
        if bundleID == "com.apple.finder" || name.lowercased() == "finder" {
            let script = "tell application \"Finder\" to make new Finder window\ntell application \"Finder\" to activate"
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
            return
        }

        if bundleID == "com.apple.Terminal" || name.lowercased() == "terminal" {
            let script = "tell application \"Terminal\" to do script \"\"\ntell application \"Terminal\" to activate"
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
            return
        }

        if bundleID == "com.apple.Safari" || name.lowercased() == "safari" {
            let script = "tell application \"Safari\" to make new document\ntell application \"Safari\" to activate"
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
            return
        }

        if bundleID.contains("google.Chrome") || bundleID.contains("Brave") || bundleID.contains("Edge") || bundleID.contains("Arc") {
            let script = "tell application id \"\(bundleID)\" to make new window\ntell application id \"\(bundleID)\" to activate"
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
            return
        }

        if bundleID.contains("iTerm") {
            let script = "tell application \"iTerm\" to create window with default profile\ntell application \"iTerm\" to activate"
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
            return
        }

        // 2. Press "New Window" or "New" via Accessibility API
        if AXIsProcessTrusted() {
            let appElement = AXUIElementCreateApplication(pid)
            var menuBarRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
               let menuBar = menuBarRef {
                var menuBarItemsRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &menuBarItemsRef) == .success,
                   let menuBarItems = menuBarItemsRef as? [AXUIElement] {
                    for item in menuBarItems {
                        var titleRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef) == .success,
                           let title = titleRef as? String,
                           title.localizedCaseInsensitiveContains("file") || title == "File" {

                            var menuRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(item, kAXChildrenAttribute as CFString, &menuRef) == .success,
                               let subMenus = menuRef as? [AXUIElement],
                               let fileMenu = subMenus.first {

                                var fileMenuItemsRef: CFTypeRef?
                                if AXUIElementCopyAttributeValue(fileMenu, kAXChildrenAttribute as CFString, &fileMenuItemsRef) == .success,
                                   let fileMenuItems = fileMenuItemsRef as? [AXUIElement] {

                                    for menuItem in fileMenuItems {
                                        var itemTitleRef: CFTypeRef?
                                        if AXUIElementCopyAttributeValue(menuItem, kAXTitleAttribute as CFString, &itemTitleRef) == .success,
                                           let itemTitle = itemTitleRef as? String {
                                            let cleanTitle = itemTitle.lowercased()
                                            if cleanTitle == "new window" || cleanTitle.hasPrefix("new window") || cleanTitle == "new" {
                                                let result = AXUIElementPerformAction(menuItem, kAXPressAction as CFString)
                                                if result == .success {
                                                    return
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // 3. Fallback: post Cmd+N key event
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let src = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x2D, keyDown: true)
            keyDown?.flags = .maskCommand
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x2D, keyDown: false)
            keyUp?.flags = .maskCommand

            keyDown?.postToPid(pid)
            keyUp?.postToPid(pid)
        }
    }
}

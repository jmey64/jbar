import Foundation
import AppKit

@MainActor
public final class AppIndexService: ObservableObject {
    public static let shared = AppIndexService()

    @Published public private(set) var installedApps: [InstalledAppInfo] = []
    @Published public private(set) var isLoading: Bool = false

    private init() {
        loadApplications()
    }

    public func loadApplications() {
        self.isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let searchDirs = [
                URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: "/System/Applications"),
                URL(fileURLWithPath: "/System/Applications/Utilities"),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            ]

            var apps: [InstalledAppInfo] = []
            let fileManager = FileManager.default

            // Explicitly add Finder
            let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            if fileManager.fileExists(atPath: finderURL.path) {
                apps.append(InstalledAppInfo(url: finderURL, name: "Finder"))
            }

            for dir in searchDirs {
                guard let enumerator = fileManager.enumerator(
                    at: dir,
                    includingPropertiesForKeys: [.isApplicationKey],
                    options: [.skipsPackageDescendants, .skipsHiddenFiles]
                ) else { continue }

                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension == "app" {
                        let name = fileURL.deletingPathExtension().lastPathComponent
                        apps.append(InstalledAppInfo(url: fileURL, name: name))
                    }
                }
            }

            let sorted = apps
                .reduce(into: [String: InstalledAppInfo]()) { dict, app in
                    if dict[app.name] == nil {
                        dict[app.name] = app
                    }
                }
                .values
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async {
                self?.installedApps = Array(sorted)
                self?.isLoading = false
            }
        }
    }

    public func search(query: String) -> [InstalledAppInfo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return installedApps
        }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    public func launch(app: InstalledAppInfo) {
        Self.launchApp(url: app.url, name: app.name)
    }

    public static func launchApp(url: URL, name: String) {
        let bundleID = Bundle(url: url)?.bundleIdentifier

        let running = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleURL?.path == url.path ||
            $0.localizedName?.lowercased() == name.lowercased() ||
            (bundleID != nil && $0.bundleIdentifier == bundleID)
        })

        if let running = running {
            running.activate()

            if name.lowercased() == "finder" || (bundleID == "com.apple.finder") || url.path.contains("Finder.app") {
                QuickLaunchService.openFinder(newWindow: false)
                return
            }

            // Raise / unminimize existing window if present
            let windows = AccessibilityService.fetchWindows(for: running.processIdentifier)
            if let minimizedWin = windows.first(where: { $0.isMinimized }) {
                AccessibilityService.raise(window: minimizedWin.axElement, of: running.processIdentifier)
            } else if let firstWin = windows.first {
                AccessibilityService.raise(window: firstWin.axElement, of: running.processIdentifier)
            }

            // Send reopen & activate AppleEvent to ensure main window opens if no windows exist
            let appIdentifier = (bundleID != nil && !bundleID!.isEmpty) ? "id \"\(bundleID!)\"" : "\"\(name)\""
            let scriptSource = """
            tell application \(appIdentifier)
                reopen
                activate
            end tell
            """
            if let script = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }

            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
        } else {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
        }
    }
}

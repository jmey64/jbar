import Foundation
import AppKit
import Combine
import SwiftUI
import CoreGraphics

@MainActor
public final class AppTrackingService: ObservableObject {
    public static let shared = AppTrackingService()

    @Published public private(set) var runningApps: [RunningAppInfo] = []
    @Published public private(set) var frontmostAppPID: pid_t?

    private var customOrder: [pid_t] = []
    private var customItemOrder: [String] = []
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    private init() {
        setupObservers()
        refreshApps()
        startPeriodicRefresh()
    }

    private func setupObservers() {
        let center = NSWorkspace.shared.notificationCenter

        center.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshApps() }
            .store(in: &cancellables)

        center.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshApps() }
            .store(in: &cancellables)

        center.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self?.frontmostAppPID = app.processIdentifier
                }
                self?.refreshApps()
            }
            .store(in: &cancellables)

        center.publisher(for: NSWorkspace.didHideApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshApps() }
            .store(in: &cancellables)

        center.publisher(for: NSWorkspace.didUnhideApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshApps() }
            .store(in: &cancellables)

        center.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshApps() }
            .store(in: &cancellables)
    }

    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshApps()
            }
        }
    }

    public func refreshApps() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        self.frontmostAppPID = frontPID

        let apps = NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular &&
                app.processIdentifier != currentPID &&
                !(app.bundleIdentifier?.contains("jbar") ?? false)
            }

        let pids = apps.map { $0.processIdentifier }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let onScreenList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

            var onScreenPIDs = Set<pid_t>()
            var fullscreenScreenIDs = Set<String>()
            let screens = NSScreen.screens
            let primaryHeight = screens.first?.frame.height ?? 1440

            for win in onScreenList {
                let pid = win[kCGWindowOwnerPID as String] as? pid_t ?? 0
                let layer = win[kCGWindowLayer as String] as? Int ?? 0
                let bounds = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
                let width = bounds["Width"] as? Double ?? 0
                let height = bounds["Height"] as? Double ?? 0
                let x = bounds["X"] as? Double ?? 0
                let y = bounds["Y"] as? Double ?? 0
                
                // Normal document/app windows are at layer 0. Filter out layer > 0 (tooltips, menus, overlays)
                if layer == 0 && width >= 100 && height >= 80 {
                    onScreenPIDs.insert(pid)
                }

                // Check fullscreen bounds for active/regular apps (covers a display)
                if pids.contains(pid) && layer == 0 {
                    for screen in screens {
                        let sf = screen.frame
                        let screenQuartzY = primaryHeight - (sf.origin.y + sf.height)
                        let screenQuartzX = sf.origin.x

                        if abs(x - screenQuartzX) <= 2 && abs(y - screenQuartzY) <= 2 &&
                           width >= sf.width - 2 && height >= sf.height - 2 {
                            let sID = AccessibilityService.screenIdentifier(for: screen)
                            fullscreenScreenIDs.insert(sID)
                        }
                    }
                }
            }

            var windowMap: [pid_t: [WindowInfo]] = [:]
            for pid in pids {
                if onScreenPIDs.contains(pid) || pid == frontPID {
                    windowMap[pid] = AccessibilityService.fetchWindows(for: pid)
                } else {
                    windowMap[pid] = []
                }
            }

            // Check if frontmost window or any window is reported as FullScreen via Accessibility
            if let frontPID = frontPID {
                let frontWindows = windowMap[frontPID] ?? []
                for win in frontWindows {
                    if let element = win.axElement, AccessibilityService.isWindowFullScreen(windowElement: element) {
                        if let sID = win.screenID {
                            fullscreenScreenIDs.insert(sID)
                        } else if let mainScreen = screens.first {
                            fullscreenScreenIDs.insert(AccessibilityService.screenIdentifier(for: mainScreen))
                        }
                    }
                }
            }

            // Constrain standard non-fullscreen windows so they do not draw behind jbar
            let barHeight = TaskbarPanelController.defaultBarHeight
            for (pid, windows) in windowMap {
                guard onScreenPIDs.contains(pid) || pid == frontPID else { continue }
                for win in windows where !win.isMinimized {
                    guard let element = win.axElement else { continue }
                    if AccessibilityService.isWindowFullScreen(windowElement: element) {
                        continue
                    }
                    let targetScreen = screens.first { AccessibilityService.screenIdentifier(for: $0) == win.screenID } ?? screens.first
                    if let screen = targetScreen {
                        AccessibilityService.constrainWindowToUsableScreenArea(
                            windowElement: element,
                            screen: screen,
                            barHeight: barHeight
                        )
                    }
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Update fullscreen visibility for all screens
                for screen in screens {
                    let sID = AccessibilityService.screenIdentifier(for: screen)
                    let isFS = fullscreenScreenIDs.contains(sID)
                    TaskbarPanelController.shared.setScreenFullscreen(screenID: sID, isFullscreen: isFS)
                }

                var orderedPIDs = self.customOrder
                for pid in pids where !orderedPIDs.contains(pid) {
                    orderedPIDs.append(pid)
                }
                orderedPIDs.removeAll { !pids.contains($0) }
                self.customOrder = orderedPIDs

                let appMap = Dictionary(uniqueKeysWithValues: apps.map { ($0.processIdentifier, $0) })
                let updatedApps = orderedPIDs.compactMap { pid -> RunningAppInfo? in
                    guard let app = appMap[pid] else { return nil }

                    let isOnCurrentSpace = onScreenPIDs.contains(pid) || (pid == frontPID)
                    guard isOnCurrentSpace else { return nil }

                    let windows = windowMap[pid] ?? []
                    let isActive = (pid == frontPID)
                    return RunningAppInfo(
                        runningApplication: app,
                        windows: windows,
                        isActive: isActive
                    )
                }
                self.runningApps = updatedApps
            }
        }
    }

    public func apps(for screenID: String) -> [RunningAppInfo] {
        let screens = NSScreen.screens
        let isSingleScreen = (screens.count <= 1)

        if isSingleScreen {
            return runningApps
        }

        let isPrimary = (screens.isEmpty || screenID == AccessibilityService.screenIdentifier(for: screens.first ?? NSScreen.main!))

        return runningApps.compactMap { app in
            let screenWindows = app.windows.filter { $0.screenID == screenID }

            if !screenWindows.isEmpty {
                var filteredApp = app
                filteredApp.windows = screenWindows
                return filteredApp
            }

            if isPrimary {
                let hasWindowsOnOtherScreens = app.windows.contains { win in
                    if let winScreenID = win.screenID, winScreenID != screenID {
                        return true
                    }
                    return false
                }

                if !hasWindowsOnOtherScreens {
                    return app
                }
            }

            return nil
        }
    }

    public func taskbarItems(for screenID: String) -> [TaskbarItem] {
        let displayApps = apps(for: screenID)
        var generatedItems: [TaskbarItem] = []

        for app in displayApps {
            if app.windows.isEmpty {
                if app.isActive {
                    generatedItems.append(TaskbarItem(app: app, window: nil))
                }
            } else {
                for win in app.windows {
                    generatedItems.append(TaskbarItem(app: app, window: win))
                }
            }
        }

        let currentIDs = Set(generatedItems.map { $0.id })
        var orderedIDs = customItemOrder.filter { currentIDs.contains($0) }
        for item in generatedItems where !orderedIDs.contains(item.id) {
            orderedIDs.append(item.id)
        }
        self.customItemOrder = orderedIDs

        let itemMap = Dictionary(uniqueKeysWithValues: generatedItems.map { ($0.id, $0) })
        return orderedIDs.compactMap { itemMap[$0] }
    }

    public func moveItem(from sourceID: String, to targetID: String) {
        guard let sourceIndex = customItemOrder.firstIndex(of: sourceID),
              let targetIndex = customItemOrder.firstIndex(of: targetID),
              sourceIndex != targetIndex else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            let moved = customItemOrder.remove(at: sourceIndex)
            customItemOrder.insert(moved, at: targetIndex)
        }
    }

    public func activate(item: TaskbarItem) {
        if let win = item.window {
            if item.isWindowActive {
                AccessibilityService.minimize(window: win.axElement, minimize: true)
            } else {
                AccessibilityService.raise(window: win.axElement, of: item.app.id)
            }
        } else {
            activate(app: item.app)
        }
        refreshApps()
    }

    public func activate(app: RunningAppInfo) {
        if app.isActive {
            if let firstWindow = app.windows.first(where: { !$0.isMinimized }) {
                AccessibilityService.minimize(window: firstWindow.axElement, minimize: true)
            } else if let minimizedWindow = app.windows.first(where: { $0.isMinimized }) {
                AccessibilityService.raise(window: minimizedWindow.axElement, of: app.id)
            } else {
                app.runningApplication.hide()
            }
        } else {
            if let mainWin = app.windows.first(where: { $0.isMain }) ?? app.windows.first {
                AccessibilityService.raise(window: mainWin.axElement, of: app.id)
            } else {
                app.runningApplication.activate()
            }
        }
        refreshApps()
    }

    public func activate(window: WindowInfo, in app: RunningAppInfo) {
        AccessibilityService.raise(window: window.axElement, of: app.id)
        refreshApps()
    }

    public func handleMiddleClick(item: TaskbarItem) {
        if let win = item.window {
            closeWindow(win, in: item.app)
        } else {
            closeApp(item.app)
        }
    }

    public func handleMiddleClick(app: RunningAppInfo) {
        if let mainWin = app.windows.first(where: { $0.isMain }) ?? app.windows.first {
            AccessibilityService.close(window: mainWin.axElement)
        } else {
            closeApp(app)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.refreshApps()
        }
    }

    public func closeWindow(_ window: WindowInfo, in app: RunningAppInfo) {
        AccessibilityService.close(window: window.axElement)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.refreshApps()
        }
    }

    public func closeApp(_ app: RunningAppInfo) {
        app.runningApplication.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.refreshApps()
        }
    }

    public func forceQuitApp(_ app: RunningAppInfo) {
        app.runningApplication.forceTerminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.refreshApps()
        }
    }

    public func hideApp(_ app: RunningAppInfo) {
        if app.isHidden {
            app.runningApplication.unhide()
        } else {
            app.runningApplication.hide()
        }
        refreshApps()
    }
}

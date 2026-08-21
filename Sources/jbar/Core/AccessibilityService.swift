import Foundation
import AppKit
import ApplicationServices
import Combine

@MainActor
public final class AccessibilityService: ObservableObject {
    public static let shared = AccessibilityService()

    @Published public private(set) var isTrusted: Bool = AXIsProcessTrusted()
    private var pollTimer: Timer?

    private init() {
        self.isTrusted = AXIsProcessTrusted()
        startPolling()
    }

    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let trusted = AXIsProcessTrusted()
                if self.isTrusted != trusted {
                    self.isTrusted = trusted
                    AppTrackingService.shared.refreshApps()
                }
            }
        }
    }

    public func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public nonisolated static func screenIdentifier(for screen: NSScreen) -> String {
        if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "\(num.uint32Value)"
        }
        return "\(screen.frame.origin.x),\(screen.frame.origin.y)"
    }

    public nonisolated static func determineScreenID(for point: CGPoint, size: CGSize) -> String? {
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let primaryHeight = primaryScreen.frame.height

        let windowCenterAX = CGPoint(x: point.x + size.width / 2, y: point.y + size.height / 2)
        let appKitY = primaryHeight - windowCenterAX.y
        let appKitPoint = NSPoint(x: windowCenterAX.x, y: appKitY)

        let targetScreen = NSScreen.screens.first { $0.frame.contains(appKitPoint) } ?? primaryScreen
        return screenIdentifier(for: targetScreen)
    }

    public nonisolated static func fetchWindows(for pid: pid_t) -> [WindowInfo] {
        guard AXIsProcessTrusted() else { return [] }

        let appElement = AXUIElementCreateApplication(pid)
        var windowsList: [AXUIElement] = []

        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let list = windowsRef as? [AXUIElement] {
            windowsList = list
        }

        // Fallback to focused window or main window if list is empty
        if windowsList.isEmpty {
            var focusedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success,
               let win = focusedRef {
                windowsList.append(win as! AXUIElement)
            } else {
                var mainRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainRef) == .success,
                   let win = mainRef {
                    windowsList.append(win as! AXUIElement)
                }
            }
        }

        var windowInfos: [WindowInfo] = []
        for (index, windowElement) in windowsList.enumerated() {
            var titleRef: CFTypeRef?
            var title = ""
            if AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef) == .success,
               let t = titleRef as? String {
                title = t.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var minimizedRef: CFTypeRef?
            var isMinimized = false
            if AXUIElementCopyAttributeValue(windowElement, kAXMinimizedAttribute as CFString, &minimizedRef) == .success,
               let min = minimizedRef as? Bool {
                isMinimized = min
            }

            var mainRef: CFTypeRef?
            var isMain = false
            if AXUIElementCopyAttributeValue(windowElement, kAXMainAttribute as CFString, &mainRef) == .success,
               let m = mainRef as? Bool {
                isMain = m
            }

            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            var point = CGPoint.zero
            var size = CGSize.zero
            if AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &posRef) == .success,
               let val = posRef {
                AXValueGetValue(val as! AXValue, .cgPoint, &point)
            }
            if AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeRef) == .success,
               let val = sizeRef {
                AXValueGetValue(val as! AXValue, .cgSize, &size)
            }

            let screenID = determineScreenID(for: point, size: size)

            let id = "\(pid)-\(index)-\(title.hashValue)"
            windowInfos.append(WindowInfo(
                id: id,
                axElement: windowElement,
                title: title,
                isMinimized: isMinimized,
                isMain: isMain,
                screenID: screenID
            ))
        }

        return windowInfos
    }

    public nonisolated static func raise(window: AXUIElement?, of pid: pid_t) {
        if let window = window {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        }

        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
        }
    }

    public nonisolated static func minimize(window: AXUIElement?, minimize: Bool = true) {
        guard let window = window else { return }
        let value: CFBoolean = minimize ? kCFBooleanTrue : kCFBooleanFalse
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, value)
    }

    public nonisolated static func close(window: AXUIElement?) {
        guard let window = window else { return }
        var closeButtonRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeButtonRef) == .success,
           let closeButton = closeButtonRef {
            AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString)
        }
    }
}

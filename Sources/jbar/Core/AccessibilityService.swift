import Foundation
import AppKit
import ApplicationServices
import Combine

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError

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

    public nonisolated static func isStandardWindow(
        role: String?,
        subrole: String?,
        size: CGSize,
        isMinimized: Bool = false,
        hasTitle: Bool = true,
        hasWindowButtons: Bool = true,
        isMain: Bool = false
    ) -> Bool {
        // 1. Role must be AXWindow
        guard let role = role, role == (kAXWindowRole as String) else {
            return false
        }

        // 2. Subrole filtering: Disallow known auxiliary / tooltip / popover / floating subroles
        if let subrole = subrole {
            let disallowedSubroles: Set<String> = [
                "AXHelpTag",
                "AXPopover",
                "AXFloatingWindow",
                "AXSystemFloatingMenu",
                "AXMenu",
                "AXDrawer",
                "AXUnknown"
            ]
            if disallowedSubroles.contains(subrole) {
                return false
            }

            let allowedStandardSubroles: Set<String> = [
                kAXStandardWindowSubrole as String,
                kAXDialogSubrole as String,
                kAXSystemDialogSubrole as String
            ]

            if !allowedStandardSubroles.contains(subrole) {
                // If it is a custom/unspecified subrole, ensure it has standard window characteristics
                if !isMinimized && (size.width < 100 || size.height < 80) {
                    return false
                }
                if !hasTitle && !hasWindowButtons && !isMain {
                    return false
                }
            }
        } else {
            // No subrole specified: check dimensions and traits
            if !isMinimized && (size.width < 100 || size.height < 80) {
                return false
            }
            if !hasTitle && !hasWindowButtons && !isMain {
                return false
            }
        }

        // 3. Size check for non-minimized windows: tooltips and hidden helpers are tiny
        if !isMinimized && (size.width < 100 || size.height < 50) {
            return false
        }

        return true
    }

    public nonisolated static func isWindowFullScreen(windowElement: AXUIElement) -> Bool {
        var fullScreenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(windowElement, "AXFullScreen" as CFString, &fullScreenRef) == .success,
           let isFS = fullScreenRef as? Bool {
            return isFS
        }
        return false
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
        for windowElement in windowsList {
            var roleRef: CFTypeRef?
            var role = ""
            if AXUIElementCopyAttributeValue(windowElement, kAXRoleAttribute as CFString, &roleRef) == .success,
               let r = roleRef as? String {
                role = r
            }

            var subroleRef: CFTypeRef?
            var subrole: String?
            if AXUIElementCopyAttributeValue(windowElement, kAXSubroleAttribute as CFString, &subroleRef) == .success,
               let sr = subroleRef as? String {
                subrole = sr
            }

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

            var closeBtnRef: CFTypeRef?
            var minBtnRef: CFTypeRef?
            let hasCloseBtn = (AXUIElementCopyAttributeValue(windowElement, kAXCloseButtonAttribute as CFString, &closeBtnRef) == .success && closeBtnRef != nil)
            let hasMinBtn = (AXUIElementCopyAttributeValue(windowElement, kAXMinimizeButtonAttribute as CFString, &minBtnRef) == .success && minBtnRef != nil)
            let hasButtons = hasCloseBtn || hasMinBtn

            // Validate standard window traits (exclude tooltips, popovers, menus, etc.)
            guard isStandardWindow(
                role: role,
                subrole: subrole,
                size: size,
                isMinimized: isMinimized,
                hasTitle: !title.isEmpty,
                hasWindowButtons: hasButtons,
                isMain: isMain
            ) else {
                continue
            }

            let screenID = determineScreenID(for: point, size: size)

            var wid: CGWindowID = 0
            let id: String
            if _AXUIElementGetWindow(windowElement, &wid) == .success && wid > 0 {
                id = "\(pid)-win-\(wid)"
            } else {
                id = "\(pid)-ax-\(CFHash(windowElement))"
            }

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

    public nonisolated static func constrainWindowToUsableScreenArea(
        windowElement: AXUIElement,
        screen: NSScreen,
        barHeight: CGFloat = 26
    ) {
        guard let primaryScreen = NSScreen.screens.first else { return }
        let primaryHeight = primaryScreen.frame.height

        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        var point = CGPoint.zero
        var size = CGSize.zero

        guard AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &posRef) == .success,
              let pVal = posRef,
              AXValueGetValue(pVal as! AXValue, .cgPoint, &point),
              AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let sVal = sizeRef,
              AXValueGetValue(sVal as! AXValue, .cgSize, &size) else {
            return
        }

        // Quartz screen coordinates
        let screenQuartzY = primaryHeight - (screen.frame.origin.y + screen.frame.height)
        let screenQuartzBottom = screenQuartzY + screen.frame.height
        let usableBottom = screenQuartzBottom - barHeight

        let windowBottom = point.y + size.height

        // Check if window bottom extends into jbar's bottom area
        if windowBottom > usableBottom {
            if point.y < usableBottom {
                let newHeight = usableBottom - point.y
                if newHeight >= 80 && abs(newHeight - size.height) > 1.0 {
                    var newSize = CGSize(width: size.width, height: newHeight)
                    if let newSizeVal = AXValueCreate(.cgSize, &newSize) {
                        AXUIElementSetAttributeValue(windowElement, kAXSizeAttribute as CFString, newSizeVal)
                    }
                }
            } else {
                // Window origin is entirely inside or below jbar: move it up
                let targetY = usableBottom - min(size.height, 200)
                if targetY >= screenQuartzY {
                    var newPoint = CGPoint(x: point.x, y: targetY)
                    if let newPointVal = AXValueCreate(.cgPoint, &newPoint) {
                        AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute as CFString, newPointVal)
                    }
                }
            }
        }
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

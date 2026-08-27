import Foundation
import AppKit
import CoreGraphics
import jbarLib

public struct WindowFilteringAndAvoidanceTests {
    public static func suite() -> TestSuite {
        let suite = TestSuite(name: "Window Filtering, Fullscreen & Margin Tests")

        suite.addTest("Standard window role and subrole is accepted") {
            let isValid = AccessibilityService.isStandardWindow(
                role: "AXWindow",
                subrole: "AXStandardWindow",
                size: CGSize(width: 800, height: 600),
                isMinimized: false,
                hasTitle: true,
                hasWindowButtons: true,
                isMain: true
            )
            try assertTrue(isValid)
        }

        suite.addTest("Dialog window subrole is accepted") {
            let isValid = AccessibilityService.isStandardWindow(
                role: "AXWindow",
                subrole: "AXDialog",
                size: CGSize(width: 400, height: 300),
                isMinimized: false,
                hasTitle: true,
                hasWindowButtons: true,
                isMain: false
            )
            try assertTrue(isValid)
        }

        suite.addTest("Tooltips with AXHelpTag subrole are rejected") {
            let isValid = AccessibilityService.isStandardWindow(
                role: "AXWindow",
                subrole: "AXHelpTag",
                size: CGSize(width: 120, height: 60),
                isMinimized: false,
                hasTitle: false,
                hasWindowButtons: false,
                isMain: false
            )
            try assertFalse(isValid)
        }

        suite.addTest("Popovers and floating menus are rejected") {
            let popoverValid = AccessibilityService.isStandardWindow(
                role: "AXWindow",
                subrole: "AXPopover",
                size: CGSize(width: 200, height: 150),
                isMinimized: false,
                hasTitle: false,
                hasWindowButtons: false,
                isMain: false
            )
            try assertFalse(popoverValid)

            let menuValid = AccessibilityService.isStandardWindow(
                role: "AXWindow",
                subrole: "AXSystemFloatingMenu",
                size: CGSize(width: 200, height: 300),
                isMinimized: false,
                hasTitle: false,
                hasWindowButtons: false,
                isMain: false
            )
            try assertFalse(menuValid)
        }

        suite.addTest("Non-AXWindow roles like AXScrollArea or AXHelpTag are rejected") {
            let scrollAreaValid = AccessibilityService.isStandardWindow(
                role: "AXScrollArea",
                subrole: nil,
                size: CGSize(width: 2560, height: 1440),
                isMinimized: false,
                hasTitle: false,
                hasWindowButtons: false,
                isMain: false
            )
            try assertFalse(scrollAreaValid)

            let helpTagRoleValid = AccessibilityService.isStandardWindow(
                role: "AXHelpTag",
                subrole: nil,
                size: CGSize(width: 80, height: 30),
                isMinimized: false,
                hasTitle: false,
                hasWindowButtons: false,
                isMain: false
            )
            try assertFalse(helpTagRoleValid)
        }

        suite.addTest("Tiny non-minimized windows are rejected") {
            let tinyValid = AccessibilityService.isStandardWindow(
                role: "AXWindow",
                subrole: "AXStandardWindow",
                size: CGSize(width: 50, height: 30),
                isMinimized: false,
                hasTitle: false,
                hasWindowButtons: false,
                isMain: false
            )
            try assertFalse(tinyValid)
        }

        suite.addTest("Quartz screen bottom coordinate calculation") {
            let primaryHeight: CGFloat = 1440
            let screenAppKitFrame = NSRect(x: 0, y: 0, width: 2560, height: 1440)
            let barHeight: CGFloat = 26

            let screenQuartzY = primaryHeight - (screenAppKitFrame.origin.y + screenAppKitFrame.height)
            let screenQuartzBottom = screenQuartzY + screenAppKitFrame.height
            let usableBottom = screenQuartzBottom - barHeight

            try assertEqual(screenQuartzY, 0.0)
            try assertEqual(screenQuartzBottom, 1440.0)
            try assertEqual(usableBottom, 1414.0)

            // Window extending to bottom of screen (1440)
            let windowY: CGFloat = 100
            let windowHeight: CGFloat = 1340
            let windowBottom = windowY + windowHeight

            try assertEqual(windowBottom, 1440.0)
            try assertTrue(windowBottom > usableBottom)

            // New constrained height
            let newHeight = usableBottom - windowY
            try assertEqual(newHeight, 1314.0)
            try assertEqual(windowY + newHeight, usableBottom)
        }

        suite.addTest("Multi-monitor secondary display margin calculation") {
            let primaryHeight: CGFloat = 1440
            // Secondary monitor placed to the right with different height: 1920x1080 at (2560, 0)
            let secondaryFrame = NSRect(x: 2560, y: 0, width: 1920, height: 1080)
            let barHeight: CGFloat = 26

            let screenQuartzY = primaryHeight - (secondaryFrame.origin.y + secondaryFrame.height)
            let screenQuartzBottom = screenQuartzY + secondaryFrame.height
            let usableBottom = screenQuartzBottom - barHeight

            try assertEqual(screenQuartzY, 360.0)
            try assertEqual(screenQuartzBottom, 1440.0)
            try assertEqual(usableBottom, 1414.0)

            // Window covering full height of secondary monitor
            let windowY: CGFloat = 360.0
            let windowHeight: CGFloat = 1080.0
            let windowBottom = windowY + windowHeight

            try assertEqual(windowBottom, 1440.0)
            try assertTrue(windowBottom > usableBottom)

            let constrainedHeight = usableBottom - windowY
            try assertEqual(constrainedHeight, 1054.0)
            try assertEqual(windowY + constrainedHeight, usableBottom)
        }

        suite.addTest("Stable window ID persistence across tab and title changes") {
            // Simulated window with stable CGWindowID (e.g. wid = 2794 for Firefox)
            let stableWindowID = "94185-win-2794"
            let runningApp = NSRunningApplication.current
            let appInfo = RunningAppInfo(runningApplication: runningApp, windows: [], isActive: true)

            // Tab 1: YouTube
            let window1 = WindowInfo(id: stableWindowID, title: "YouTube - Mozilla Firefox", isMinimized: false, isMain: true)
            let item1 = TaskbarItem(app: appInfo, window: window1)

            // Tab 2: User opens new tab / changes URL -> title changes, but window ID is persistent
            let window2 = WindowInfo(id: stableWindowID, title: "New Tab - Mozilla Firefox", isMinimized: false, isMain: true)
            let item2 = TaskbarItem(app: appInfo, window: window2)

            // IDs must remain identical so the taskbar slot never shifts
            try assertEqual(item1.id, item2.id)
            try assertEqual(item1.title, "YouTube - Mozilla Firefox")
            try assertEqual(item2.title, "New Tab - Mozilla Firefox")
        }

        suite.addTest("Fullscreen window bounds detection logic") {
            let screen = NSRect(x: 0, y: 0, width: 2560, height: 1440)
            let primaryHeight: CGFloat = 1440

            // Helper to check fullscreen coverage
            func isCoveringScreen(windowX: Double, windowY: Double, windowW: Double, windowH: Double) -> Bool {
                let screenQuartzY = Double(primaryHeight - (screen.origin.y + screen.height))
                let screenQuartzX = Double(screen.origin.x)
                return abs(windowX - screenQuartzX) <= 2 &&
                       abs(windowY - screenQuartzY) <= 2 &&
                       windowW >= Double(screen.width) - 2 &&
                       windowH >= Double(screen.height) - 2
            }

            // Normal window
            try assertFalse(isCoveringScreen(windowX: 100, windowY: 100, windowW: 1200, windowH: 800))

            // Fullscreen YouTube video window covering 2560x1440 display
            try assertTrue(isCoveringScreen(windowX: 0, windowY: 0, windowW: 2560, windowH: 1440))
        }

        return suite
    }
}

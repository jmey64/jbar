import AppKit
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an accessory / agent application (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Show Taskbars on all connected monitors
        TaskbarPanelController.shared.showTaskbars()

        // Check Accessibility permissions
        if !AccessibilityService.shared.isTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AccessibilityService.shared.requestAccessibilityPermission()
            }
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

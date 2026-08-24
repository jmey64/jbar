import Foundation
import AppKit
import jbarLib

public struct TaskbarItemTests {
    public static func suite() -> TestSuite {
        let suite = TestSuite(name: "Taskbar Item Model Tests")

        suite.addTest("Window title is used when available") {
            let runningApp = NSRunningApplication.current
            let appInfo = RunningAppInfo(runningApplication: runningApp, windows: [], isActive: true)
            let window = WindowInfo(id: "win-1", title: "My Document - TextEdit", isMinimized: false, isMain: true)
            let item = TaskbarItem(app: appInfo, window: window)

            try assertEqual(item.title, "My Document - TextEdit")
        }

        suite.addTest("Falls back to app name when window title is empty") {
            let runningApp = NSRunningApplication.current
            let appInfo = RunningAppInfo(runningApplication: runningApp, windows: [], isActive: true)
            let window = WindowInfo(id: "win-2", title: "", isMinimized: false, isMain: true)
            let item = TaskbarItem(app: appInfo, window: window)

            try assertEqual(item.title, appInfo.localizedName)
        }

        suite.addTest("Falls back to app name when window title is generic 'Window'") {
            let runningApp = NSRunningApplication.current
            let appInfo = RunningAppInfo(runningApplication: runningApp, windows: [], isActive: true)
            let window = WindowInfo(id: "win-3", title: "Window", isMinimized: false, isMain: true)
            let item = TaskbarItem(app: appInfo, window: window)

            try assertEqual(item.title, appInfo.localizedName)
        }

        suite.addTest("Active window state determination") {
            let runningApp = NSRunningApplication.current
            let activeApp = RunningAppInfo(runningApplication: runningApp, windows: [], isActive: true)
            let inactiveApp = RunningAppInfo(runningApplication: runningApp, windows: [], isActive: false)

            let mainWindow = WindowInfo(id: "win-1", title: "Main", isMinimized: false, isMain: true)
            let nonMainWindow = WindowInfo(id: "win-2", title: "Other", isMinimized: false, isMain: false)

            let activeMainItem = TaskbarItem(app: activeApp, window: mainWindow)
            try assertTrue(activeMainItem.isWindowActive)

            let activeNonMainItem = TaskbarItem(app: activeApp, window: nonMainWindow)
            try assertFalse(activeNonMainItem.isWindowActive)

            let inactiveMainItem = TaskbarItem(app: inactiveApp, window: mainWindow)
            try assertFalse(inactiveMainItem.isWindowActive)
        }

        suite.addTest("Identity and Equality") {
            let runningApp = NSRunningApplication.current
            let appInfo = RunningAppInfo(runningApplication: runningApp, windows: [], isActive: true)
            let window1 = WindowInfo(id: "win-1", title: "Doc", isMinimized: false, isMain: true)
            let window2 = WindowInfo(id: "win-1", title: "Doc", isMinimized: false, isMain: true)
            let window3 = WindowInfo(id: "win-2", title: "Doc", isMinimized: false, isMain: true)

            let item1 = TaskbarItem(app: appInfo, window: window1)
            let item2 = TaskbarItem(app: appInfo, window: window2)
            let item3 = TaskbarItem(app: appInfo, window: window3)

            try assertEqual(item1, item2)
            try assertEqual(item1.id, item2.id)
            try assertTrue(item1.id != item3.id)
        }

        return suite
    }
}

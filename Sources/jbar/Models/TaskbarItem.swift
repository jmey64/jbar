import Foundation
import AppKit

public struct TaskbarItem: Identifiable, Hashable {
    public let id: String
    public let app: RunningAppInfo
    public let window: WindowInfo?

    public init(app: RunningAppInfo, window: WindowInfo?) {
        self.app = app
        self.window = window
        if let win = window {
            self.id = "\(app.id)-\(win.id)"
        } else {
            self.id = "\(app.id)-none"
        }
    }

    public var title: String {
        if let win = window, !win.title.isEmpty, win.title.lowercased() != "window" {
            return win.title
        }
        return app.localizedName
    }

    public var isWindowActive: Bool {
        if app.isActive {
            if let win = window {
                return win.isMain
            }
            return true
        }
        return false
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: TaskbarItem, rhs: TaskbarItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.isWindowActive == rhs.isWindowActive &&
        lhs.window?.isMinimized == rhs.window?.isMinimized
    }
}

import Foundation
import AppKit
import ApplicationServices

public struct WindowInfo: Identifiable, Hashable {
    public let id: String
    public let axElement: AXUIElement?
    public var title: String
    public var isMinimized: Bool
    public var isMain: Bool
    public var screenID: String?

    public init(
        id: String,
        axElement: AXUIElement? = nil,
        title: String,
        isMinimized: Bool = false,
        isMain: Bool = false,
        screenID: String? = nil
    ) {
        self.id = id
        self.axElement = axElement
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isMinimized = isMinimized
        self.isMain = isMain
        self.screenID = screenID
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.isMinimized == rhs.isMinimized &&
        lhs.screenID == rhs.screenID
    }
}

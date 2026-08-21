import Foundation
import AppKit

public struct PinnedApp: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let path: String
    public let bundleIdentifier: String?

    public init(name: String, path: String, bundleIdentifier: String? = nil) {
        self.id = path
        self.name = name
        self.path = path
        self.bundleIdentifier = bundleIdentifier
    }

    public var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    public var url: URL {
        URL(fileURLWithPath: path)
    }
}

import AppKit

public struct InstalledAppInfo: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let url: URL
    public let icon: NSImage

    public init(url: URL, name: String? = nil) {
        self.id = url.path
        self.url = url
        self.name = name ?? url.deletingPathExtension().lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: InstalledAppInfo, rhs: InstalledAppInfo) -> Bool {
        lhs.id == rhs.id
    }
}

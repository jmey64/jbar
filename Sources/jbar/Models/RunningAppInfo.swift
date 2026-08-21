import AppKit

public struct RunningAppInfo: Identifiable, Equatable {
    public let id: pid_t
    public let bundleIdentifier: String?
    public let localizedName: String
    public let icon: NSImage
    public var isActive: Bool
    public var isHidden: Bool
    public var windows: [WindowInfo]
    public let runningApplication: NSRunningApplication

    public init(
        runningApplication: NSRunningApplication,
        windows: [WindowInfo] = [],
        isActive: Bool = false
    ) {
        self.id = runningApplication.processIdentifier
        self.bundleIdentifier = runningApplication.bundleIdentifier
        self.localizedName = runningApplication.localizedName ?? "Application"
        self.icon = runningApplication.icon ?? NSWorkspace.shared.icon(for: .application)
        self.isActive = isActive
        self.isHidden = runningApplication.isHidden
        self.windows = windows
        self.runningApplication = runningApplication
    }

    public static func == (lhs: RunningAppInfo, rhs: RunningAppInfo) -> Bool {
        lhs.id == rhs.id &&
        lhs.isActive == rhs.isActive &&
        lhs.isHidden == rhs.isHidden &&
        lhs.windows == rhs.windows
    }
}

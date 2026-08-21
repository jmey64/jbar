import AppKit
import SwiftUI
import Combine

@MainActor
public final class TaskbarPanelController: ObservableObject {
    public static let shared = TaskbarPanelController()

    public let barHeight: CGFloat = 26
    private var panels: [String: TaskbarPanel] = [:]
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupScreenObserver()
    }

    public func showTaskbars() {
        rebuildPanels()
    }

    private func setupScreenObserver() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildPanels()
            }
            .store(in: &cancellables)
    }

    public func rebuildPanels() {
        let currentScreens = NSScreen.screens
        let currentScreenIDs = Set(currentScreens.map { AccessibilityService.screenIdentifier(for: $0) })

        // Remove panels for disconnected screens
        for (id, panel) in panels where !currentScreenIDs.contains(id) {
            panel.close()
            panels.removeValue(forKey: id)
        }

        // Create or update panel for each connected screen
        for screen in currentScreens {
            let id = AccessibilityService.screenIdentifier(for: screen)
            let frame = calculateFrame(for: screen)

            if let existingPanel = panels[id] {
                existingPanel.setFrame(frame, display: true, animate: false)
            } else {
                let panel = TaskbarPanel(contentRect: frame)
                let rootView = TaskbarView(screen: screen)
                let hostingView = NSHostingView(rootView: rootView)
                hostingView.autoresizingMask = [.width, .height]
                panel.contentView = hostingView
                panel.setFrame(frame, display: true)
                panel.orderFrontRegardless()
                panels[id] = panel
            }
        }
    }

    private func calculateFrame(for screen: NSScreen) -> NSRect {
        let sf = screen.frame
        return NSRect(
            x: sf.minX,
            y: sf.minY,
            width: sf.width,
            height: barHeight
        )
    }
}

import SwiftUI

public struct TaskbarView: View {
    let screen: NSScreen
    let screenID: String
    @State private var isStartMenuOpen = false

    public init(screen: NSScreen) {
        self.screen = screen
        self.screenID = AccessibilityService.screenIdentifier(for: screen)
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Apps Menu Button
            StartButtonView(isPresented: $isStartMenuOpen)
                .fixedSize()
                .popover(isPresented: $isStartMenuOpen, arrowEdge: .top) {
                    StartMenuView(isPresented: $isStartMenuOpen)
                }

            // Quick Launch Bar
            QuickLaunchBarView()
                .fixedSize()

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 14)

            // Running Applications Bar (Filtered for this screen)
            RunningAppsBarView(screenID: screenID)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 0)
        .padding(.trailing, 6)
        .frame(height: 26)
        .background(.ultraThinMaterial)
        .overlay(
            VStack {
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                Spacer()
            }
        )
    }
}

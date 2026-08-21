import SwiftUI

public struct RunningAppItemView: View {
    let item: TaskbarItem
    let targetWidth: CGFloat
    @ObservedObject var appTracking = AppTrackingService.shared
    @State private var isHovered = false
    @State private var isDropTarget = false

    public init(item: TaskbarItem, targetWidth: CGFloat = 160) {
        self.item = item
        self.targetWidth = targetWidth
    }

    public var body: some View {
        Button(action: {
            appTracking.activate(item: item)
        }) {
            ZStack(alignment: .bottom) {
                // Background Highlight
                RoundedRectangle(cornerRadius: 4)
                    .fill(item.isWindowActive ? Color.white.opacity(0.18) : (isHovered ? Color.white.opacity(0.10) : Color.white.opacity(0.04)))
                    .padding(.vertical, 2)

                HStack(spacing: 5) {
                    Image(nsImage: item.app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)

                    if targetWidth > 44 {
                        Text(item.title)
                            .font(.system(size: 11.5, weight: item.isWindowActive ? .semibold : .regular))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, targetWidth <= 44 ? 4 : 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Drag & Drop targeted indicator
                if isDropTarget {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                        .padding(.vertical, 2)
                }

                // Active / Open Pill indicator at bottom
                if item.isWindowActive {
                    Capsule()
                        .fill(Color.blue)
                        .frame(height: 2)
                        .padding(.horizontal, targetWidth <= 44 ? 4 : 6)
                        .padding(.bottom, 2)
                } else {
                    Capsule()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 10, height: 1.5)
                        .padding(.bottom, 2)
                }
            }
            .frame(height: 22)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onMiddleClick {
            appTracking.handleMiddleClick(item: item)
        }
        .draggable(item.id)
        .dropDestination(for: String.self) { items, location in
            guard let first = items.first else { return false }
            appTracking.moveItem(from: first, to: item.id)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isDropTarget = targeted
            }
        }
        .contextMenu {
            if let win = item.window {
                Button("Close Window") {
                    appTracking.closeWindow(win, in: item.app)
                }
                Button(win.isMinimized ? "Unminimize" : "Minimize") {
                    if win.isMinimized {
                        AccessibilityService.raise(window: win.axElement, of: item.app.id)
                    } else {
                        AccessibilityService.minimize(window: win.axElement, minimize: true)
                    }
                }
                Divider()
            }

            Button(item.app.isHidden ? "Unhide" : "Hide") {
                appTracking.hideApp(item.app)
            }

            Button("Quit") {
                appTracking.closeApp(item.app)
            }

            Button("Force Quit") {
                appTracking.forceQuitApp(item.app)
            }
        }
    }
}

import SwiftUI

public struct QuickLaunchBarView: View {
    @ObservedObject var quickLaunch = QuickLaunchService.shared
    @State private var showAddPicker = false
    @State private var hoveredAppID: String? = nil

    public init() {}

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(quickLaunch.pinnedApps) { app in
                Button(action: {
                    quickLaunch.launch(app, newWindow: true)
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(hoveredAppID == app.id ? Color.white.opacity(0.15) : Color.white.opacity(0.04))

                        Image(nsImage: app.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                    }
                    .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .onHover { hovered in
                    hoveredAppID = hovered ? app.id : nil
                }
                .help("\(app.name) (Click to launch new window)")
                .contextMenu {
                    Button("Open New Window") {
                        quickLaunch.launch(app, newWindow: true)
                    }
                    Divider()
                    Button("Add Quick Launcher...") {
                        showAddPicker = true
                    }
                    Button("Remove from Quick Launch") {
                        quickLaunch.unpin(app)
                    }
                }
            }
        }
        .contextMenu {
            Button("Add Quick Launcher...") {
                showAddPicker = true
            }
        }
        .popover(isPresented: $showAddPicker, arrowEdge: .top) {
            AddQuickLaunchView(isPresented: $showAddPicker)
        }
        .fixedSize()
    }
}

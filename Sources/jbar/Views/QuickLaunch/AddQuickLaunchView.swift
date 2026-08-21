import SwiftUI

public struct AddQuickLaunchView: View {
    @ObservedObject var appIndex = AppIndexService.shared
    @ObservedObject var quickLaunch = QuickLaunchService.shared
    @Binding var isPresented: Bool
    @State private var searchText = ""

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add to Quick Launch")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.top, .horizontal], 12)
            .padding(.bottom, 8)

            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search apps to pin...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider().opacity(0.4)

            // Application List
            ScrollView {
                LazyVStack(spacing: 2) {
                    let apps = appIndex.search(query: searchText)
                    if apps.isEmpty {
                        Text("No applications found")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(apps) { app in
                            let isPinned = quickLaunch.isPinned(app.url.path)
                            HStack(spacing: 10) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 22, height: 22)

                                Text(app.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Spacer()

                                Button(action: {
                                    if isPinned {
                                        if let pinned = quickLaunch.pinnedApps.first(where: { $0.path == app.url.path }) {
                                            quickLaunch.unpin(pinned)
                                        }
                                    } else {
                                        quickLaunch.pin(app: app)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
                                            .font(.system(size: 11))
                                        Text(isPinned ? "Unpin" : "Pin")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(isPinned ? Color.red.opacity(0.2) : Color.accentColor.opacity(0.2))
                                    .foregroundColor(isPinned ? .red : .accentColor)
                                    .cornerRadius(5)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(8)
            }
            .frame(height: 300)
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

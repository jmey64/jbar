import SwiftUI

public struct StartMenuView: View {
    @ObservedObject var appIndex = AppIndexService.shared
    @ObservedObject var quickLaunch = QuickLaunchService.shared
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Bar Header
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Type here to search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                    .onSubmit {
                        let apps = appIndex.search(query: searchText)
                        if let topApp = apps.first {
                            appIndex.launch(app: topApp)
                            isPresented = false
                        }
                    }
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(8)
            .padding([.top, .horizontal], 12)
            .padding(.bottom, 8)

            Divider().opacity(0.4)

            // App List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    let apps = appIndex.search(query: searchText)
                    if apps.isEmpty {
                        Text(appIndex.isLoading ? "Indexing applications..." : "No applications found")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                            let isPinned = quickLaunch.isPinned(app.url.path)
                            let isTopMatch = !searchText.isEmpty && index == 0
                            HStack(spacing: 4) {
                                Button(action: {
                                    appIndex.launch(app: app)
                                    isPresented = false
                                }) {
                                    HStack(spacing: 10) {
                                        Image(nsImage: app.icon)
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                        Text(app.name)
                                            .font(.system(size: 13, weight: isTopMatch ? .medium : .regular))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                        if isTopMatch {
                                            Image(systemName: "return")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.secondary.opacity(0.8))
                                                .padding(.trailing, 4)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(StartMenuItemButtonStyle(isTopMatch: isTopMatch))

                                Button(action: {
                                    if isPinned {
                                        if let pinned = quickLaunch.pinnedApps.first(where: { $0.path == app.url.path }) {
                                            quickLaunch.unpin(pinned)
                                        }
                                    } else {
                                        quickLaunch.pin(app: app)
                                    }
                                }) {
                                    Image(systemName: isPinned ? "pin.fill" : "pin")
                                        .font(.system(size: 11))
                                        .foregroundColor(isPinned ? Color.accentColor : Color.secondary.opacity(0.6))
                                        .padding(6)
                                }
                                .buttonStyle(.plain)
                                .help(isPinned ? "Unpin from Quick Launch" : "Pin to Quick Launch")
                            }
                            .contextMenu {
                                Button("Launch") {
                                    appIndex.launch(app: app)
                                    isPresented = false
                                }
                                Button(isPinned ? "Unpin from Quick Launch" : "Pin to Quick Launch") {
                                    if isPinned {
                                        if let pinned = quickLaunch.pinnedApps.first(where: { $0.path == app.url.path }) {
                                            quickLaunch.unpin(pinned)
                                        }
                                    } else {
                                        quickLaunch.pin(app: app)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
            }
            .frame(maxHeight: 380)

            Divider().opacity(0.4)

            // Bottom System & Power Bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                    Text(NSFullUserName())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()

                Menu {
                    Button("Lock Screen") {
                        let libHandle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)
                        let sym = dlsym(libHandle, "SACLockScreenImmediate")
                        typealias SACLockScreenImmediateFunc = @convention(c) () -> Void
                        if let sym = sym {
                            let lockFunc = unsafeBitCast(sym, to: SACLockScreenImmediateFunc.self)
                            lockFunc()
                        }
                        isPresented = false
                    }
                    Button("Sleep") {
                        let source = "tell application \"System Events\" to sleep"
                        if let script = NSAppleScript(source: source) {
                            script.executeAndReturnError(nil)
                        }
                        isPresented = false
                    }
                    Button("Restart...") {
                        let source = "tell application \"System Events\" to restart"
                        if let script = NSAppleScript(source: source) {
                            script.executeAndReturnError(nil)
                        }
                        isPresented = false
                    }
                    Button("Shut Down...") {
                        let source = "tell application \"System Events\" to shut down"
                        if let script = NSAppleScript(source: source) {
                            script.executeAndReturnError(nil)
                        }
                        isPresented = false
                    }
                    Divider()
                    Button("Quit jbar") {
                        NSApp.terminate(nil)
                    }
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.15))
        }
        .frame(width: 340, height: 460)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 15, x: 0, y: 5)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
    }
}

struct StartMenuItemButtonStyle: ButtonStyle {
    var isTopMatch: Bool = false
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        configuration.isPressed
                        ? Color.accentColor.opacity(0.4)
                        : (isHovered
                            ? Color.white.opacity(0.15)
                            : (isTopMatch ? Color.accentColor.opacity(0.18) : Color.clear))
                    )
            )
            .onHover { isHovered = $0 }
    }
}

import SwiftUI

public struct StartButtonView: View {
    @Binding var isPresented: Bool
    @State private var isHovered = false

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        Button(action: {
            isPresented.toggle()
        }) {
            ZStack {
                // Background Highlight
                RoundedRectangle(cornerRadius: 4)
                    .fill(isPresented ? Color.accentColor : (isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.06)))
                    .padding(.leading, 3)
                    .padding(.trailing, 2)
                    .padding(.vertical, 2)

                HStack(spacing: 5) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isPresented ? .white : .primary)

                    Text("Apps")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(isPresented ? .white : .primary)
                }
                .padding(.leading, 8)
                .padding(.trailing, 7)
            }
            .frame(height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { isHovered = $0 }
    }
}

import SwiftUI

public struct VolumeControlView: View {
    @ObservedObject var systemStatus = SystemStatusService.shared
    @State private var showSlider = false
    @State private var isHovered = false

    public init() {}

    private var volumeIconName: String {
        if systemStatus.isMuted || systemStatus.volume == 0 {
            return "speaker.slash.fill"
        } else if systemStatus.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if systemStatus.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    public var body: some View {
        Button(action: {
            showSlider.toggle()
        }) {
            Image(systemName: volumeIconName)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .popover(isPresented: $showSlider, arrowEdge: .top) {
            VStack(spacing: 12) {
                HStack {
                    Text("Volume")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(Int(systemStatus.volume * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    Button(action: {
                        systemStatus.toggleMute()
                    }) {
                        Image(systemName: systemStatus.isMuted ? "speaker.slash.fill" : "speaker.fill")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)

                    Slider(value: Binding(
                        get: { Double(systemStatus.volume) },
                        set: { systemStatus.setVolume(Float($0)) }
                    ), in: 0...1)
                }
            }
            .frame(width: 200)
            .padding(12)
        }
    }
}

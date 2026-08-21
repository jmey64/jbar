import SwiftUI

public struct BatteryIndicatorView: View {
    @ObservedObject var systemStatus = SystemStatusService.shared

    public init() {}

    private var batteryIconName: String {
        if systemStatus.isCharging {
            return "battery.100.bolt"
        }
        switch systemStatus.batteryLevel {
        case 0...15: return "battery.0"
        case 16...35: return "battery.25"
        case 36...65: return "battery.50"
        case 66...85: return "battery.75"
        default: return "battery.100"
        }
    }

    public var body: some View {
        if systemStatus.hasBattery {
            HStack(spacing: 4) {
                Image(systemName: batteryIconName)
                    .font(.system(size: 13))
                    .foregroundColor(systemStatus.batteryLevel <= 20 && !systemStatus.isCharging ? .red : .primary)
                Text("\(systemStatus.batteryLevel)%")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))
            .cornerRadius(4)
        }
    }
}

import SwiftUI

public struct ClockCalendarView: View {
    @ObservedObject var systemStatus = SystemStatusService.shared
    @State private var showCalendar = false
    @State private var isHovered = false

    public init() {}

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy"
        return formatter
    }

    public var body: some View {
        Button(action: {
            showCalendar.toggle()
        }) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(timeFormatter.string(from: systemStatus.currentDate))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                Text(dateFormatter.string(from: systemStatus.currentDate))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .popover(isPresented: $showCalendar, arrowEdge: .top) {
            VStack(spacing: 10) {
                DatePicker(
                    "Calendar",
                    selection: .constant(Date()),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            }
            .padding(10)
        }
    }
}

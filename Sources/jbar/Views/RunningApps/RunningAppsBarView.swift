import SwiftUI

public struct RunningAppsBarView: View {
    @ObservedObject var appTracking = AppTrackingService.shared
    let screenID: String

    public init(screenID: String) {
        self.screenID = screenID
    }

    public var body: some View {
        let items = appTracking.taskbarItems(for: screenID)

        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let count = items.count
            let spacing: CGFloat = 3
            let maxItemWidth: CGFloat = 160
            let minItemWidth: CGFloat = 36

            // Calculate item width based on available space and count
            let totalSpacing = count > 1 ? CGFloat(count - 1) * spacing : 0
            let availableForItems = max(0, availableWidth - totalSpacing)
            let calculatedWidth = count > 0 ? availableForItems / CGFloat(count) : maxItemWidth
            let itemWidth = max(minItemWidth, min(maxItemWidth, calculatedWidth))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(items) { item in
                        RunningAppItemView(item: item, targetWidth: itemWidth)
                            .frame(width: itemWidth)
                    }
                }
                .frame(minHeight: geometry.size.height)
                .animation(.easeInOut(duration: 0.2), value: items.map { $0.id })
                .animation(.easeInOut(duration: 0.2), value: itemWidth)
            }
            .frame(width: availableWidth, height: geometry.size.height, alignment: .leading)
        }
    }
}

import Foundation
import CoreGraphics

public struct TaskbarLayoutCalculator {
    public static let defaultSpacing: CGFloat = 3
    public static let defaultMaxItemWidth: CGFloat = 160
    public static let defaultMinItemWidth: CGFloat = 36
    public static let iconOnlyThreshold: CGFloat = 44

    public static func calculateItemWidth(
        availableWidth: CGFloat,
        itemCount: Int,
        spacing: CGFloat = defaultSpacing,
        maxItemWidth: CGFloat = defaultMaxItemWidth,
        minItemWidth: CGFloat = defaultMinItemWidth
    ) -> CGFloat {
        guard itemCount > 0 else { return maxItemWidth }
        let totalSpacing = itemCount > 1 ? CGFloat(itemCount - 1) * spacing : 0
        let availableForItems = max(0, availableWidth - totalSpacing)
        let calculatedWidth = availableForItems / CGFloat(itemCount)
        return max(minItemWidth, min(maxItemWidth, calculatedWidth))
    }

    public static func isIconOnly(width: CGFloat, threshold: CGFloat = iconOnlyThreshold) -> Bool {
        return width <= threshold
    }

    public static func requiresScrolling(
        availableWidth: CGFloat,
        itemCount: Int,
        itemWidth: CGFloat,
        spacing: CGFloat = defaultSpacing
    ) -> Bool {
        guard itemCount > 0 else { return false }
        let totalContentWidth = CGFloat(itemCount) * itemWidth + CGFloat(max(0, itemCount - 1)) * spacing
        return totalContentWidth > availableWidth
    }
}

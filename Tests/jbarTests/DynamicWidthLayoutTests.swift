import Foundation
import jbarLib

public struct DynamicWidthLayoutTests {
    public static func suite() -> TestSuite {
        let suite = TestSuite(name: "Dynamic Taskbar Width & Layout Tests")

        suite.addTest("Zero items returns max width") {
            let width = TaskbarLayoutCalculator.calculateItemWidth(availableWidth: 1000, itemCount: 0)
            try assertEqual(width, 160)
        }

        suite.addTest("Single item clamps to max width") {
            let width = TaskbarLayoutCalculator.calculateItemWidth(availableWidth: 1000, itemCount: 1)
            try assertEqual(width, 160)
        }

        suite.addTest("Few items clamp to max width") {
            let width = TaskbarLayoutCalculator.calculateItemWidth(availableWidth: 1000, itemCount: 4)
            try assertEqual(width, 160)
        }

        suite.addTest("Shrinks proportionally when space is constrained") {
            let width = TaskbarLayoutCalculator.calculateItemWidth(availableWidth: 1000, itemCount: 10)
            try assertEqualDouble(Double(width), 97.3, accuracy: 0.1)
            try assertFalse(TaskbarLayoutCalculator.isIconOnly(width: width))
            try assertFalse(TaskbarLayoutCalculator.requiresScrolling(availableWidth: 1000, itemCount: 10, itemWidth: width))
        }

        suite.addTest("Clamps to min width when many items present") {
            let width = TaskbarLayoutCalculator.calculateItemWidth(availableWidth: 800, itemCount: 35)
            try assertEqual(width, 36)
            try assertTrue(TaskbarLayoutCalculator.isIconOnly(width: width))
            try assertTrue(TaskbarLayoutCalculator.requiresScrolling(availableWidth: 800, itemCount: 35, itemWidth: width))
        }

        suite.addTest("Icon only threshold detection") {
            try assertTrue(TaskbarLayoutCalculator.isIconOnly(width: 36))
            try assertTrue(TaskbarLayoutCalculator.isIconOnly(width: 44))
            try assertFalse(TaskbarLayoutCalculator.isIconOnly(width: 45))
            try assertFalse(TaskbarLayoutCalculator.isIconOnly(width: 160))
        }

        suite.addTest("Scrolling requirement detection") {
            try assertTrue(TaskbarLayoutCalculator.requiresScrolling(availableWidth: 1000, itemCount: 10, itemWidth: 100, spacing: 3))
            try assertFalse(TaskbarLayoutCalculator.requiresScrolling(availableWidth: 1000, itemCount: 5, itemWidth: 100, spacing: 3))
        }

        return suite
    }
}

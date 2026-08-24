import Foundation

public struct TestAssertionError: Error {
    public let message: String
    public let file: String
    public let line: Int

    public init(message: String, file: String, line: Int) {
        self.message = message
        self.file = (file as NSString).lastPathComponent
        self.line = line
    }
}

public func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard a == b else {
        let msg = message.isEmpty ? "Expected '\(a)' to equal '\(b)'" : message
        throw TestAssertionError(message: msg, file: file, line: line)
    }
}

public func assertEqualDouble(_ a: Double, _ b: Double, accuracy: Double = 0.01, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard abs(a - b) <= accuracy else {
        let msg = message.isEmpty ? "Expected '\(a)' to equal '\(b)' within \(accuracy)" : message
        throw TestAssertionError(message: msg, file: file, line: line)
    }
}

public func assertTrue(_ condition: Bool, _ message: String = "Expected condition to be true", file: String = #file, line: Int = #line) throws {
    guard condition else {
        throw TestAssertionError(message: message, file: file, line: line)
    }
}

public func assertFalse(_ condition: Bool, _ message: String = "Expected condition to be false", file: String = #file, line: Int = #line) throws {
    guard !condition else {
        throw TestAssertionError(message: message, file: file, line: line)
    }
}

public class TestSuite {
    public let name: String
    public var tests: [(String, () throws -> Void)] = []

    public init(name: String) {
        self.name = name
    }

    public func addTest(_ name: String, _ block: @escaping () throws -> Void) {
        tests.append((name, block))
    }
}

public class TestRunner {
    public static let shared = TestRunner()
    public var suites: [TestSuite] = []

    private init() {}

    public func addSuite(_ suite: TestSuite) {
        suites.append(suite)
    }

    public func run() -> Bool {
        var totalPassed = 0
        var totalFailed = 0

        print("\n🧪 Running jbar Test Suite")
        print("========================================")

        for suite in suites {
            print("\n📁 Suite: \(suite.name)")
            for (name, test) in suite.tests {
                do {
                    try test()
                    print("  ✅ \(name)")
                    totalPassed += 1
                } catch let error as TestAssertionError {
                    print("  ❌ \(name)")
                    print("     └─ \(error.message) [\(error.file):\(error.line)]")
                    totalFailed += 1
                } catch {
                    print("  ❌ \(name)")
                    print("     └─ Unexpected error: \(error)")
                    totalFailed += 1
                }
            }
        }

        print("\n========================================")
        if totalFailed == 0 {
            print("🎉 All tests passed! (\(totalPassed) passed, \(totalPassed + totalFailed) total)\n")
        } else {
            print("💥 Some tests failed! (\(totalPassed) passed, \(totalFailed) failed, \(totalPassed + totalFailed) total)\n")
        }

        return totalFailed == 0
    }
}

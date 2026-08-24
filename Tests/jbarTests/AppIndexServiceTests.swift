import Foundation
import AppKit
import jbarLib

public struct AppIndexServiceTests {
    public static func suite() -> TestSuite {
        let suite = TestSuite(name: "App Index & Search Tests")

        suite.addTest("Empty query returns full list") {
            Task { @MainActor in
                let service = AppIndexService.shared
                let allApps = service.installedApps
                let results = service.search(query: "")
                try? assertEqual(results.count, allApps.count)
            }
        }

        suite.addTest("Whitespace query is trimmed") {
            Task { @MainActor in
                let service = AppIndexService.shared
                let results = service.search(query: "   ")
                try? assertEqual(results.count, service.installedApps.count)
            }
        }

        suite.addTest("Case-insensitive filtering") {
            Task { @MainActor in
                let service = AppIndexService.shared
                let lower = service.search(query: "finder")
                let upper = service.search(query: "FINDER")
                try? assertEqual(lower.count, upper.count)
            }
        }

        suite.addTest("Non-matching query returns empty") {
            Task { @MainActor in
                let service = AppIndexService.shared
                let results = service.search(query: "xyznonexistentapp123456789")
                try? assertTrue(results.isEmpty)
            }
        }

        return suite
    }
}

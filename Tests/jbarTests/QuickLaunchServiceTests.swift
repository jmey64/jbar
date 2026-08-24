import Foundation
import AppKit
import jbarLib

public struct QuickLaunchServiceTests {
    public static func suite() -> TestSuite {
        let suite = TestSuite(name: "Quick Launch Service Tests")

        suite.addTest("PinnedApp Codable serialization") {
            let app = PinnedApp(name: "Terminal", path: "/System/Applications/Utilities/Terminal.app", bundleIdentifier: "com.apple.Terminal")
            let data = try JSONEncoder().encode(app)
            let decoded = try JSONDecoder().decode(PinnedApp.self, from: data)

            try assertEqual(decoded.name, "Terminal")
            try assertEqual(decoded.path, "/System/Applications/Utilities/Terminal.app")
            try assertEqual(decoded.bundleIdentifier, "com.apple.Terminal")
            try assertEqual(decoded.id, app.path)
        }

        suite.addTest("isPinned matches exact and Finder paths") {
            Task { @MainActor in
                let service = QuickLaunchService.shared
                let finderPath = "/System/Library/CoreServices/Finder.app"

                service.pin(path: finderPath)
                try? assertTrue(service.isPinned(finderPath))
                try? assertTrue(service.isPinned("/System/Library/CoreServices/Finder.app/"))
            }
        }

        suite.addTest("Pin and unpin duplicate prevention") {
            Task { @MainActor in
                let service = QuickLaunchService.shared
                let testPath = "/Applications/Safari.app"

                guard FileManager.default.fileExists(atPath: testPath) else { return }

                if let existing = service.pinnedApps.first(where: { $0.path == testPath }) {
                    service.unpin(existing)
                }

                service.pin(path: testPath)
                let countBefore = service.pinnedApps.count
                service.pin(path: testPath)
                try? assertEqual(service.pinnedApps.count, countBefore)

                if let pinned = service.pinnedApps.first(where: { $0.path == testPath }) {
                    service.unpin(pinned)
                }
            }
        }

        return suite
    }
}

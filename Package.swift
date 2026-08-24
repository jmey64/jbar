// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "jbar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "jbar",
            targets: ["jbar"]
        ),
        .executable(
            name: "jbarTestRunner",
            targets: ["jbarTestRunner"]
        ),
        .library(
            name: "jbarLib",
            targets: ["jbarLib"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "jbarLib",
            dependencies: [],
            path: "Sources/jbar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreAudio")
            ]
        ),
        .executableTarget(
            name: "jbar",
            dependencies: ["jbarLib"],
            path: "Sources/jbarApp"
        ),
        .executableTarget(
            name: "jbarTestRunner",
            dependencies: ["jbarLib"],
            path: "Tests/jbarTests"
        )
    ]
)

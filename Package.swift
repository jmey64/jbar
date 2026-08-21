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
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "jbar",
            dependencies: [],
            path: "Sources/jbar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreAudio")
            ]
        )
    ]
)

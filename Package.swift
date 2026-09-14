// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "xBar",
    defaultLocalization: "en",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .executable(
            name: "xBar",
            targets: ["xBar"]
        ),
    ],
    dependencies: [
        .package(path: "Packages/AXSwift6"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern.git", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", "1.0.0" ..< "1.1.0"),
        .package(url: "https://github.com/apple/swift-algorithms.git", "1.2.0" ..< "1.3.0"),
        .package(url: "https://github.com/apple/swift-collections.git", exact: "1.1.4"),
    ],
    targets: [
        .executableTarget(
            name: "xBar",
            dependencies: [
                .product(name: "AXSwift6", package: "AXSwift6"),
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
            ],
            path: "xBar",
            exclude: [
                "Resources",
            ],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .unsafeFlags([
                    "-Xfrontend", "-default-isolation",
                    "-Xfrontend", "MainActor",
                ]),
            ]
        ),
    ]
)

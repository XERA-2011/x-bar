// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AXSwift6",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "AXSwift6",
            targets: ["AXSwift6"]
        ),
    ],
    targets: [
        .target(
            name: "AXSwift6"
        ),
    ]
)

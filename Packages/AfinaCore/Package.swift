// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AfinaCore",
    defaultLocalization: "pt-PT",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AfinaCore", targets: ["AfinaCore"]),
    ],
    targets: [
        .target(name: "AfinaCore"),
        .testTarget(name: "AfinaCoreTests", dependencies: ["AfinaCore"]),
    ]
)

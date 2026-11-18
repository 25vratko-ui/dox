// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Dox",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Dox", targets: ["Dox"]),
        .library(name: "DoxCore", targets: ["DoxCore"]),
    ],
    targets: [
        // Pure model + logic layer. No AppKit/SwiftUI, fully unit-testable.
        .target(name: "DoxCore"),
        // The macOS app: AppKit panels + SwiftUI views.
        .executableTarget(
            name: "Dox",
            dependencies: ["DoxCore"]
        ),
        .testTarget(name: "DoxCoreTests", dependencies: ["DoxCore"]),
    ]
)

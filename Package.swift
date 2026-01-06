// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftPrimitives",
    platforms: [
            .macOS(.v10_15),   // macOS Catalina or later
            .iOS(.v13),        // iOS 13 or later
            .tvOS(.v13),       // tvOS 13 or later
            .watchOS(.v6)      // watchOS 6 or later
        ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftPrimitives",
            targets: ["SwiftPrimitives"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftPrimitives",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "SwiftPrimitivesTests",
            dependencies: ["SwiftPrimitives"]
        ),
    ]
)

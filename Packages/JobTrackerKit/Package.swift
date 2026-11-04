// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "JobTrackerKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Persistence", targets: ["Persistence"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Persistence"),
        .testTarget(
            name: "PersistenceTests",
            dependencies: ["Persistence"]
        ),
    ]
)

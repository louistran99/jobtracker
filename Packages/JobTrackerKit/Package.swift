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
        .library(name: "ViewModels", targets: ["ViewModels"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Persistence", dependencies: ["Domain"]),
        .target(name: "ViewModels", dependencies: ["Domain"]),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"]
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: ["Persistence", "Domain"]
        ),
        .testTarget(
            name: "ViewModelsTests",
            dependencies: ["ViewModels", "Domain"]
        ),
    ]
)

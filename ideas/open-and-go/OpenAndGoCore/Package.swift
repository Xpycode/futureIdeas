// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenAndGoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "OpenAndGoCore", targets: ["OpenAndGoCore"]),
    ],
    targets: [
        .target(name: "OpenAndGoCore"),
        .testTarget(
            name: "OpenAndGoCoreTests",
            dependencies: ["OpenAndGoCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

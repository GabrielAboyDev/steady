// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PredictiveEngine",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "PredictiveEngine", targets: ["PredictiveEngine"])
    ],
    targets: [
        .target(
            name: "PredictiveEngine",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PredictiveEngineTests",
            dependencies: ["PredictiveEngine"]
        )
    ]
)

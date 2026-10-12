// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PredictiveEngine",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "PredictiveEngine", targets: ["PredictiveEngine"]),
        // Offline tool that compiles word/bigram lists into Resources/en.sdict.
        .executable(name: "sdict-compile", targets: ["sdict-compile"]),
    ],
    targets: [
        .target(
            name: "PredictiveEngine",
            exclude: ["Resources/LICENSES.md"],
            resources: [.copy("Resources/en.sdict")]
        ),
        .executableTarget(
            name: "sdict-compile",
            dependencies: ["PredictiveEngine"]
        ),
        .testTarget(
            name: "PredictiveEngineTests",
            dependencies: ["PredictiveEngine"]
        )
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CVGeneratorAI",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "CVGeneratorAI",
            targets: ["CVGeneratorAI"]
        ),
        .executable(
            name: "CVGeneratorDemo",
            targets: ["CVGeneratorDemo"]
        ),
    ],
    targets: [
        .target(
            name: "CVGeneratorAI",
            dependencies: [],
            path: "Sources/CVGeneratorAI"
        ),
        .executableTarget(
            name: "CVGeneratorDemo",
            dependencies: ["CVGeneratorAI"],
            path: "Sources/CVGeneratorDemo"
        ),
        .testTarget(
            name: "CVGeneratorAITests",
            dependencies: ["CVGeneratorAI"],
            path: "Tests/CVGeneratorAITests"
        ),
    ]
)

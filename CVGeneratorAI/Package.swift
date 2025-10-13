// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CVGeneratorAI",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0")
    ],
    products: [
        .library(
            name: "CVGeneratorAI",
            targets: ["CVGeneratorAI"]
        ),
    ],
    targets: [
        .target(
            name: "CVGeneratorAI",
            dependencies: [],
            path: "Sources/CVGeneratorAI"
        ),
        .testTarget(
            name: "CVGeneratorAITests",
            dependencies: ["CVGeneratorAI"],
            path: "Tests/CVGeneratorAITests"
        ),
    ]
)

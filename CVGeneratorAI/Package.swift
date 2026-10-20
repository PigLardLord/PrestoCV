// swift-tools-version: 6.0
import PackageDescription

// AI Drafting (docs/architecture/modules.md). The targets are empty until the migration fills them.
var products: [Product] = [
    .library(name: "CVDrafting", targets: ["CVDrafting"]),
]
var targets: [Target] = [
    .target(name: "CVDrafting"),
]

// Apple-only adapter (the platform column of docs/architecture/modules.md): not part of a Linux build.
#if !os(Linux)
products.append(.library(name: "CVDraftingFoundationModels", targets: ["CVDraftingFoundationModels"]))
targets.append(.target(name: "CVDraftingFoundationModels", dependencies: ["CVDrafting"]))
#endif

// Legacy targets: declared only on Apple hosts, and deleted when their replacement is wired in (ADR 0012).
#if !os(Linux)
products.append(.library(name: "CVGeneratorAI", targets: ["CVGeneratorAI"]))
targets += [
    .target(name: "CVGeneratorAI", dependencies: [], path: "Sources/CVGeneratorAI"),
    .testTarget(name: "CVGeneratorAITests", dependencies: ["CVGeneratorAI"], path: "Tests/CVGeneratorAITests"),
]
#endif

let package = Package(
    name: "CVGeneratorAI",
    platforms: [.iOS("26.5"), .macOS("26.0")],
    products: products,
    targets: targets
)

// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Drafting",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "CVDrafting", targets: ["CVDrafting"]),
        .library(name: "CVDraftingFoundationModels", targets: ["CVDraftingFoundationModels"]),
    ],
    targets: [
        .target(name: "CVDrafting"),
        .target(name: "CVDraftingFoundationModels", dependencies: ["CVDrafting"]),
    ]
)

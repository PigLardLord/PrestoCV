// swift-tools-version: 6.0
import PackageDescription

// CV Tailoring (docs/architecture/modules.md, ADR 0013). TailoringModel holds the model; the other four targets are empty until their tickets fill them.
let package = Package(
    name: "CVTailoring",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "TailoringModel", targets: ["TailoringModel"]),
        .library(name: "AdvertAnalysis", targets: ["AdvertAnalysis"]),
        .library(name: "ContentChecks", targets: ["ContentChecks"]),
        .library(name: "Provenance", targets: ["Provenance"]),
        .library(name: "Tailoring", targets: ["Tailoring"]),
    ],
    targets: [
        .target(name: "TailoringModel"),
        .target(name: "AdvertAnalysis", dependencies: ["TailoringModel"]),
        .target(name: "ContentChecks", dependencies: ["TailoringModel"]),
        .target(name: "Provenance", dependencies: ["TailoringModel", "AdvertAnalysis", "ContentChecks"]),
        .target(name: "Tailoring", dependencies: ["TailoringModel", "AdvertAnalysis", "ContentChecks", "Provenance"]),
        .testTarget(name: "TailoringModelTests", dependencies: ["TailoringModel"]),
    ]
)

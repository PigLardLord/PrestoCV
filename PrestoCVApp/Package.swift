// swift-tools-version: 6.1
import PackageDescription

// App integration and presentation (docs/architecture/modules.md). The targets are empty until step 5 fills them;
// the Xcode app starts depending on this package then (#88, #89).
var products: [Product] = [
    .library(name: "PrestoCVWorkflowPorts", targets: ["PrestoCVWorkflowPorts"]),
    .library(name: "PrestoCVIntegration", targets: ["PrestoCVIntegration"]),
    .library(name: "PrestoCVPresentation", targets: ["PrestoCVPresentation"]),
]
var targets: [Target] = [
    .target(name: "PrestoCVWorkflowPorts", dependencies: [
        .product(name: "PrestoCVApplication", package: "PrestoCVCore"),
        .product(name: "PrestoCVDomain", package: "PrestoCVCore"),
    ]),
    .target(name: "PrestoCVIntegration", dependencies: [
        "PrestoCVWorkflowPorts",
        .product(name: "PrestoCVApplication", package: "PrestoCVCore"),
        .product(name: "PrestoCVDomain", package: "PrestoCVCore"),
        .product(name: "CVDocumentModel", package: "CVPDFExporter"),
        .product(name: "CVDesignCatalog", package: "CVPDFExporter"),
        .product(name: "CVRendering", package: "CVPDFExporter"),
        .product(name: "CVDrafting", package: "CVGeneratorAI"),
    ]),
    .target(name: "PrestoCVPresentation", dependencies: [
        "PrestoCVWorkflowPorts",
        .product(name: "PrestoCVApplication", package: "PrestoCVCore"),
        .product(name: "PrestoCVDomain", package: "PrestoCVCore"),
    ]),
]

// The composition root is Apple-only (docs/architecture/modules.md): it wires the platform adapters.
#if !os(Linux)
products.append(.library(name: "PrestoCVComposition", targets: ["PrestoCVComposition"]))
targets.append(.target(name: "PrestoCVComposition", dependencies: [
    "PrestoCVIntegration", "PrestoCVPresentation", "PrestoCVWorkflowPorts",
    .product(name: "PrestoCVApplication", package: "PrestoCVCore"),
    .product(name: "PrestoCVDomain", package: "PrestoCVCore"),
    .product(name: "PrestoCVPersistence", package: "PrestoCVCore"),
    .product(name: "CVDocumentModel", package: "CVPDFExporter"),
    .product(name: "CVDesignCatalog", package: "CVPDFExporter"),
    .product(name: "CVDesignCatalogFileStore", package: "CVPDFExporter"),
    .product(name: "CVBundledDesigns", package: "CVPDFExporter"),
    .product(name: "CVRendering", package: "CVPDFExporter"),
    .product(name: "CVRenderingWebKitSupport", package: "CVPDFExporter"),
    .product(name: "CVRenderingIOS", package: "CVPDFExporter", condition: .when(platforms: [.iOS])),
    .product(name: "CVRenderingMacOS", package: "CVPDFExporter", condition: .when(platforms: [.macOS])),
    .product(name: "CVRenderingPDFKitInspector", package: "CVPDFExporter"),
    .product(name: "CVDrafting", package: "CVGeneratorAI"),
    .product(name: "CVDraftingFoundationModels", package: "CVGeneratorAI"),
]))
#endif

let package = Package(
    name: "PrestoCVApp",
    platforms: [.iOS("26.5"), .macOS("26.0")],
    products: products,
    dependencies: [
        .package(path: "../PrestoCVCore"),
        .package(path: "../CVPDFExporter"),
        .package(path: "../CVGeneratorAI"),
    ],
    targets: targets
)

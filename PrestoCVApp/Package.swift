// swift-tools-version: 6.1
import PackageDescription

// App integration and presentation (docs/architecture/modules.md). Step 5 fills the targets one by one (#62); the
// app target, PrestoCV, links the composition and the presentation (#88, #89).
var products: [Product] = [
    .library(name: "PrestoCVWorkflowPorts", targets: ["PrestoCVWorkflowPorts"]),
    .library(name: "PrestoCVIntegration", targets: ["PrestoCVIntegration"]),
    .library(name: "PrestoCVPresentation", targets: ["PrestoCVPresentation"]),
    .library(name: "PrestoCVImportFiles", targets: ["PrestoCVImportFiles"]),
    .library(name: "PrestoCVExportFiles", targets: ["PrestoCVExportFiles"]),
    .library(name: "PrestoCVLegacyLeftovers", targets: ["PrestoCVLegacyLeftovers"]),
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
        .product(name: "PrestoCVImporting", package: "PrestoCVCore"),
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
    // The files handed to the import: a portable outbound adapter, tested on Linux against the real file system
    .target(name: "PrestoCVImportFiles", dependencies: [
        "PrestoCVWorkflowPorts",
        .product(name: "PrestoCVImporting", package: "PrestoCVCore"),
        .product(name: "DiagnosticLogging", package: "DiagnosticLogging"),
    ]),
    // The file of an export's share: a portable outbound adapter, tested on Linux against the real file system
    .target(name: "PrestoCVExportFiles", dependencies: [
        "PrestoCVWorkflowPorts",
        .product(name: "DiagnosticLogging", package: "DiagnosticLogging"),
    ]),
    // What the released app left that holds nothing the person wrote: a portable outbound adapter, tested on Linux against
    // the real file system
    .target(name: "PrestoCVLegacyLeftovers", dependencies: [
        "PrestoCVWorkflowPorts",
        .product(name: "DiagnosticLogging", package: "DiagnosticLogging"),
    ]),
]

targets.append(.testTarget(name: "PrestoCVIntegrationTests", dependencies: [
    "PrestoCVIntegration", "PrestoCVWorkflowPorts",
    .product(name: "PrestoCVApplication", package: "PrestoCVCore"),
    .product(name: "PrestoCVDomain", package: "PrestoCVCore"),
    .product(name: "PrestoCVCoreTestSupport", package: "PrestoCVCore"),
    .product(name: "PrestoCVImporting", package: "PrestoCVCore"),
    .product(name: "PrestoCVImportingTestSupport", package: "PrestoCVCore"),
    .product(name: "CVDocumentModel", package: "CVPDFExporter"),
    .product(name: "CVDesignCatalog", package: "CVPDFExporter"),
    .product(name: "CVRendering", package: "CVPDFExporter"),
    .product(name: "CVRenderingTestSupport", package: "CVPDFExporter"),
    .product(name: "CVBundledHeadings", package: "CVPDFExporter"),
]))
targets.append(.testTarget(name: "PrestoCVImportFilesTests", dependencies: [
    "PrestoCVImportFiles", "PrestoCVWorkflowPorts",
    .product(name: "PrestoCVImporting", package: "PrestoCVCore"),
    .product(name: "DiagnosticLogging", package: "DiagnosticLogging"),
    .product(name: "DiagnosticLoggingTestSupport", package: "DiagnosticLogging"),
]))
targets.append(.testTarget(name: "PrestoCVExportFilesTests", dependencies: [
    "PrestoCVExportFiles", "PrestoCVWorkflowPorts",
    .product(name: "DiagnosticLogging", package: "DiagnosticLogging"),
    .product(name: "DiagnosticLoggingTestSupport", package: "DiagnosticLogging"),
]))
targets.append(.testTarget(name: "PrestoCVLegacyLeftoversTests", dependencies: [
    "PrestoCVLegacyLeftovers", "PrestoCVWorkflowPorts",
    .product(name: "DiagnosticLogging", package: "DiagnosticLogging"),
    .product(name: "DiagnosticLoggingTestSupport", package: "DiagnosticLogging"),
]))
targets.append(.testTarget(name: "PrestoCVPresentationTests", dependencies: [
    "PrestoCVPresentation", "PrestoCVWorkflowPorts",
    .product(name: "PrestoCVDomain", package: "PrestoCVCore"),
    .product(name: "PrestoCVApplication", package: "PrestoCVCore"),
    .product(name: "PrestoCVCoreTestSupport", package: "PrestoCVCore"),
]))

// The composition root is Apple-only (docs/architecture/modules.md): it wires the platform adapters.
#if !os(Linux)
targets.append(.target(name: "PrestoCVTipsStoreKit", dependencies: [
    "PrestoCVWorkflowPorts",
    .product(name: "DiagnosticLogging", package: "DiagnosticLogging"),
]))
targets.append(.testTarget(name: "PrestoCVTipsStoreKitTests", dependencies: [
    "PrestoCVTipsStoreKit", "PrestoCVWorkflowPorts",
    .product(name: "DiagnosticLogging", package: "DiagnosticLogging"),
]))
products.append(.library(name: "PrestoCVComposition", targets: ["PrestoCVComposition"]))
targets.append(.target(name: "PrestoCVComposition", dependencies: [
    "PrestoCVImportFiles", "PrestoCVExportFiles", "PrestoCVLegacyLeftovers", "PrestoCVIntegration", "PrestoCVPresentation", "PrestoCVWorkflowPorts",
    "PrestoCVTipsStoreKit",
    .product(name: "PrestoCVApplication", package: "PrestoCVCore"),
    .product(name: "PrestoCVDomain", package: "PrestoCVCore"),
    .product(name: "PrestoCVImporting", package: "PrestoCVCore"),
    .product(name: "PrestoCVImportingPDFKit", package: "PrestoCVCore"),
    .product(name: "PrestoCVApplicationNaturalLanguage", package: "PrestoCVCore"),
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
    .product(name: "CVBundledHeadings", package: "CVPDFExporter"),
    .product(name: "DiagnosticLogging", package: "DiagnosticLogging"),
    .product(name: "DiagnosticLoggingOSLog", package: "DiagnosticLogging"),
    .product(name: "DiagnosticTrace", package: "DiagnosticTrace"),
    .product(name: "DiagnosticTraceFiles", package: "DiagnosticTrace"),
    .product(name: "DiagnosticTraceDistribution", package: "DiagnosticTrace"),
]))
targets.append(.testTarget(name: "PrestoCVCompositionTests", dependencies: [
    "PrestoCVComposition", "PrestoCVLegacyLeftovers", "PrestoCVIntegration", "PrestoCVPresentation", "PrestoCVWorkflowPorts",
    .product(name: "PrestoCVApplication", package: "PrestoCVCore"),
    .product(name: "PrestoCVDomain", package: "PrestoCVCore"),
    .product(name: "PrestoCVImporting", package: "PrestoCVCore"),
    .product(name: "PrestoCVPersistence", package: "PrestoCVCore"),
    .product(name: "PrestoCVCoreTestSupport", package: "PrestoCVCore"),
    .product(name: "CVBundledDesigns", package: "CVPDFExporter"),
    .product(name: "CVDesignCatalog", package: "CVPDFExporter"),
    .product(name: "CVRendering", package: "CVPDFExporter"),
    .product(name: "CVRenderingTestSupport", package: "CVPDFExporter"),
    .product(name: "CVRenderingWebKitSupport", package: "CVPDFExporter"),
    .product(name: "DiagnosticLogging", package: "DiagnosticLogging"),
    .product(name: "DiagnosticLoggingTestSupport", package: "DiagnosticLogging"),
    .product(name: "DiagnosticTrace", package: "DiagnosticTrace"),
    .product(name: "DiagnosticTraceTestSupport", package: "DiagnosticTrace"),
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
        .package(path: "../DiagnosticLogging"),
        .package(path: "../DiagnosticTrace"),
    ],
    targets: targets
)

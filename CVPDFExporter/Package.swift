// swift-tools-version: 6.0
import PackageDescription

// Design Catalog and Document Rendering: standalone, no dependency on any PrestoCV package (ADR 0002), and portable to
// a Linux backend. The targets are empty until the migration fills them (docs/architecture/modules.md).
var products: [Product] = [
    .library(name: "CVDocumentModel", targets: ["CVDocumentModel"]),
    .library(name: "CVDesignCatalog", targets: ["CVDesignCatalog"]),
    .library(name: "CVDesignCatalogFileStore", targets: ["CVDesignCatalogFileStore"]),
    .library(name: "CVBundledDesigns", targets: ["CVBundledDesigns"]),
    .library(name: "CVRendering", targets: ["CVRendering"]),
]
var dependencies: [Package.Dependency] = []
var targets: [Target] = [
    .target(name: "CVDocumentModel"),
    .target(name: "CVDesignCatalog"),
    .target(name: "CVDesignCatalogFileStore", dependencies: ["CVDesignCatalog"]),
    .target(name: "CVBundledDesigns", dependencies: ["CVDesignCatalog"], resources: [.copy("Designs")]),
    .target(name: "CVRendering", dependencies: ["CVDocumentModel", "CVDesignCatalog"]),
]

// Apple-only adapters (the platform column of docs/architecture/modules.md): not part of a Linux build.
#if !os(Linux)
products += [
    .library(name: "CVRenderingWebKitSupport", targets: ["CVRenderingWebKitSupport"]),
    .library(name: "CVRenderingIOS", targets: ["CVRenderingIOS"]),
    .library(name: "CVRenderingMacOS", targets: ["CVRenderingMacOS"]),
    .library(name: "CVRenderingPDFKitInspector", targets: ["CVRenderingPDFKitInspector"]),
]
targets += [
    .target(name: "CVRenderingWebKitSupport", dependencies: ["CVRendering"]),
    .target(name: "CVRenderingIOS", dependencies: ["CVRenderingWebKitSupport", "CVRendering"]),
    .target(name: "CVRenderingMacOS", dependencies: ["CVRenderingWebKitSupport", "CVRendering"]),
    .target(name: "CVRenderingPDFKitInspector", dependencies: ["CVRendering"]),
]
#endif

// Legacy targets: declared only on Apple hosts, and deleted when their replacement is wired in (ADR 0012).
#if !os(Linux)
products.append(.library(name: "CVPDFExporter", targets: ["CVPDFExporter"]))
dependencies.append(.package(path: "../PrestoCVCore"))
targets += [
    .target(
        name: "CVPDFExporter",
        dependencies: [.product(name: "PrestoCVCore", package: "PrestoCVCore")],
        path: "Sources/CVPDFExporter",
        resources: [.copy("../../Resources/Templates")]
    ),
    .testTarget(name: "CVPDFExporterTests", dependencies: ["CVPDFExporter"], path: "Tests/CVPDFExporterTests"),
    .executableTarget(
        name: "CVPDFExporterDemo",
        dependencies: ["CVPDFExporter"],
        path: "Demo",
        sources: ["main.swift", "RenderCVDemo.swift", "PlatformRenderer.swift", "GenerateTemplatePreviews.swift"],
        swiftSettings: [.unsafeFlags(["-parse-as-library"])]
    ),
    .executableTarget(name: "CVExportDemoApp", dependencies: ["CVPDFExporter"], path: "Example"),
    .executableTarget(name: "TestExport", dependencies: ["CVPDFExporter"], path: "Demo", sources: ["TestExport.swift"]),
    .executableTarget(name: "TemplateViewer", dependencies: ["CVPDFExporter"], path: "TemplateViewer"),
]
#endif

let package = Package(
    name: "CVPDFExporter",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: products,
    dependencies: dependencies,
    targets: targets
)

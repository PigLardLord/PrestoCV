// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "App",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    dependencies: [.package(path: "../Core"), .package(path: "../Exporter"), .package(path: "../Drafting")],
    targets: [
        .target(name: "PrestoCVWorkflowPorts", dependencies: [
            .product(name: "PrestoCVApplication", package: "Core"), .product(name: "PrestoCVDomain", package: "Core"),
        ]),
        .target(name: "PrestoCVIntegration", dependencies: [
            "PrestoCVWorkflowPorts",
            .product(name: "PrestoCVApplication", package: "Core"), .product(name: "PrestoCVDomain", package: "Core"),
            .product(name: "CVDocumentModel", package: "Exporter"), .product(name: "CVRendering", package: "Exporter"),
            .product(name: "CVDesignCatalog", package: "Exporter"),
            .product(name: "CVDrafting", package: "Drafting"),
        ]),
        .target(name: "PrestoCVPresentation", dependencies: [
            "PrestoCVWorkflowPorts",
            .product(name: "PrestoCVApplication", package: "Core"), .product(name: "PrestoCVDomain", package: "Core"),
        ]),
        .target(name: "PrestoCVComposition", dependencies: [
            "PrestoCVIntegration", "PrestoCVPresentation", "PrestoCVWorkflowPorts",
            .product(name: "PrestoCVPersistence", package: "Core"), .product(name: "PrestoCVApplication", package: "Core"),
            .product(name: "CVRenderingIOS", package: "Exporter", condition: .when(platforms: [.iOS])),
            .product(name: "CVRenderingMacOS", package: "Exporter", condition: .when(platforms: [.macOS])),
            .product(name: "CVDraftingFoundationModels", package: "Drafting", condition: .when(platforms: [.iOS, .macOS])),
        ]),
        .testTarget(name: "AppTests", dependencies: [
            "PrestoCVIntegration", "PrestoCVPresentation", "PrestoCVWorkflowPorts",
            .product(name: "PrestoCVDomain", package: "Core"), .product(name: "PrestoCVApplication", package: "Core"),
            .product(name: "PrestoCVCoreTestSupport", package: "Core"),
            .product(name: "CVRenderingTestSupport", package: "Exporter"),
            .product(name: "CVDocumentModel", package: "Exporter"), .product(name: "CVDesignCatalog", package: "Exporter"),
            .product(name: "CVRendering", package: "Exporter"), .product(name: "CVDrafting", package: "Drafting"),
        ]),
    ]
)

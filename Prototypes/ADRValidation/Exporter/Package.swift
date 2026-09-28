// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Exporter",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "CVDocumentModel", targets: ["CVDocumentModel"]),
        .library(name: "CVDesignCatalog", targets: ["CVDesignCatalog"]),
        .library(name: "CVBundledDesigns", targets: ["CVBundledDesigns"]),
        .library(name: "CVRendering", targets: ["CVRendering"]),
        .library(name: "CVRenderingIOS", targets: ["CVRenderingIOS"]),
        .library(name: "CVRenderingMacOS", targets: ["CVRenderingMacOS"]),
        .library(name: "CVRenderingTestSupport", targets: ["CVRenderingTestSupport"]),
    ],
    targets: [
        .target(name: "CVDocumentModel"),
        .target(name: "CVDesignCatalog"),
        .target(name: "CVBundledDesigns", dependencies: ["CVDesignCatalog"], resources: [.copy("Resources")]),
        .target(name: "CVRendering", dependencies: ["CVDocumentModel", "CVDesignCatalog"], resources: [.copy("Resources")]),
        .target(name: "CVRenderingWebKitSupport", dependencies: ["CVRendering"]),
        .target(name: "CVRenderingIOS", dependencies: ["CVRenderingWebKitSupport", "CVRendering"]),
        .target(name: "CVRenderingMacOS", dependencies: ["CVRenderingWebKitSupport", "CVRendering"]),
        .target(name: "CVRenderingTestSupport", dependencies: ["CVRendering", "CVDocumentModel", "CVDesignCatalog"]),
        .testTarget(name: "CVRenderingTests", dependencies: ["CVRendering", "CVRenderingTestSupport", "CVDocumentModel", "CVBundledDesigns", "CVDesignCatalog"],
                    resources: [.copy("Golden")]),
        .testTarget(name: "CVDesignCatalogTests", dependencies: ["CVDesignCatalog", "CVBundledDesigns"]),
    ]
)

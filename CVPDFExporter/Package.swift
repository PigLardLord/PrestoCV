// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CVPDFExporter",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "CVPDFExporter",
            targets: ["CVPDFExporter"]
        )
    ],
    dependencies: [
        .package(path: "../PrestoCVCore")
    ],
    targets: [
        .target(
            name: "CVPDFExporter",
            dependencies: [
                .product(name: "PrestoCVCore", package: "PrestoCVCore")
            ],
            path: "Sources/CVPDFExporter"
        ),
        .testTarget(
            name: "CVPDFExporterTests",
            dependencies: ["CVPDFExporter"],
            path: "Tests/CVPDFExporterTests"
        ),
        .executableTarget(
            name: "CVPDFExporterDemo",
            dependencies: ["CVPDFExporter"],
            path: "Demo",
            sources: ["main.swift", "RenderCVDemo.swift", "PlatformRenderer.swift"],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .executableTarget(
            name: "CVExportDemoApp",
            dependencies: ["CVPDFExporter"],
            path: "Example"
        ),
        .executableTarget(
            name: "TestExport",
            dependencies: ["CVPDFExporter"],
            path: "Demo",
            sources: ["TestExport.swift"]
        ),
        .executableTarget(
            name: "TemplateViewer",
            dependencies: ["CVPDFExporter"],
            path: "TemplateViewer"
        )
    ]
)

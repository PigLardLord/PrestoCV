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
        // No external dependencies - pure Swift + system frameworks
    ],
    targets: [
        .target(
            name: "CVPDFExporter",
            dependencies: [],
            path: "Sources/CVPDFExporter",
            exclude: ["Templates/Bundled/Professional.html"]
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
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)
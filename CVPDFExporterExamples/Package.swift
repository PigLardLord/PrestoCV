// swift-tools-version: 6.0
import PackageDescription

// The exporter's demos, apart from the library, which contains no executables (R14). They use the legacy exporter, so
// they build on Apple hosts only and go when it does (ADR 0012, #47).
var targets: [Target] = []

#if !os(Linux)
let exporter: Target.Dependency = .product(name: "CVPDFExporter", package: "CVPDFExporter")
targets += [
    .executableTarget(
        name: "CVPDFExporterDemo",
        dependencies: [exporter],
        path: "Demo",
        swiftSettings: [.unsafeFlags(["-parse-as-library"])]
    ),
    .executableTarget(name: "CVExportDemoApp", dependencies: [exporter], path: "Example"),
]
#endif

let package = Package(
    name: "CVPDFExporterExamples",
    platforms: [.iOS("26.5"), .macOS("26.0")],
    dependencies: [.package(path: "../CVPDFExporter")],
    targets: targets
)

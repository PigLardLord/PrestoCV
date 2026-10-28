// swift-tools-version: 6.1
import PackageDescription

// The trace of a test build (ADR 0032, docs/architecture/modules.md): each step of the AI draft and of the import, with the
// text it read and wrote, kept on the device in TestFlight and Debug builds only. It carries CV content, so it is a package
// of its own, apart from the logs, which never do (ADR 0030).
let logging = Target.Dependency.product(name: "DiagnosticLogging", package: "DiagnosticLogging")
let loggingTestSupport = Target.Dependency.product(name: "DiagnosticLoggingTestSupport", package: "DiagnosticLogging")

var products: [Product] = [
    .library(name: "DiagnosticTrace", targets: ["DiagnosticTrace"]),
    .library(name: "DiagnosticTraceFiles", targets: ["DiagnosticTraceFiles"]),
    .library(name: "DiagnosticTraceTestSupport", targets: ["DiagnosticTraceTestSupport"]),
]
var targets: [Target] = [
    .target(name: "DiagnosticTrace", dependencies: [logging]),
    .target(name: "DiagnosticTraceFiles", dependencies: ["DiagnosticTrace", logging]),
    .target(name: "DiagnosticTraceTestSupport", dependencies: ["DiagnosticTrace"]),
    .testTarget(
        name: "DiagnosticTraceTests",
        dependencies: ["DiagnosticTrace", "DiagnosticTraceTestSupport", logging, loggingTestSupport]
    ),
    .testTarget(
        name: "DiagnosticTraceFilesTests",
        dependencies: ["DiagnosticTraceFiles", "DiagnosticTrace", logging, loggingTestSupport]
    ),
]

// Apple-only adapter (the platform column of docs/architecture/modules.md): not part of a Linux build.
#if !os(Linux)
products.append(.library(name: "DiagnosticTraceDistribution", targets: ["DiagnosticTraceDistribution"]))
targets += [
    .target(name: "DiagnosticTraceDistribution", dependencies: ["DiagnosticTrace"]),
]
#endif

let package = Package(
    name: "DiagnosticTrace",
    platforms: [.iOS("26.5"), .macOS("26.0")],
    products: products,
    dependencies: [.package(path: "../DiagnosticLogging")],
    targets: targets
)

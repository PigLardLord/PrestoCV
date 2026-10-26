// swift-tools-version: 6.1
import PackageDescription

// Diagnostic logging (ADR 0030, docs/architecture/modules.md): one interface that carries no CV content, its decorators,
// and the adapters that are its backends. It depends on no other package.
var products: [Product] = [
    .library(name: "DiagnosticLogging", targets: ["DiagnosticLogging"]),
    .library(name: "DiagnosticLoggingTestSupport", targets: ["DiagnosticLoggingTestSupport"]),
]
var targets: [Target] = [
    .target(name: "DiagnosticLogging"),
    .target(name: "DiagnosticLoggingTestSupport", dependencies: ["DiagnosticLogging"]),
    .testTarget(name: "DiagnosticLoggingTests", dependencies: ["DiagnosticLogging", "DiagnosticLoggingTestSupport"]),
]

// Apple-only adapter (the platform column of docs/architecture/modules.md): not part of a Linux build.
#if !os(Linux)
products.append(.library(name: "DiagnosticLoggingOSLog", targets: ["DiagnosticLoggingOSLog"]))
targets += [
    .target(name: "DiagnosticLoggingOSLog", dependencies: ["DiagnosticLogging"]),
    .testTarget(name: "DiagnosticLoggingOSLogTests", dependencies: ["DiagnosticLoggingOSLog", "DiagnosticLogging"]),
]
#endif

let package = Package(
    name: "DiagnosticLogging",
    platforms: [.iOS("26.5"), .macOS("26.0")],
    products: products,
    targets: targets
)

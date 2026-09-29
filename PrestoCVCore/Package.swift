// swift-tools-version: 6.1
import PackageDescription

// CV Authoring (docs/architecture/modules.md). The targets are empty until the migration fills them.
var products: [Product] = [
    .library(name: "PrestoCVDomain", targets: ["PrestoCVDomain"]),
    .library(name: "PrestoCVApplication", targets: ["PrestoCVApplication"]),
    .library(name: "PrestoCVPersistence", targets: ["PrestoCVPersistence"]),
]
var targets: [Target] = [
    .target(name: "PrestoCVDomain"),
    .target(name: "PrestoCVApplication", dependencies: ["PrestoCVDomain"]),
    .target(name: "PrestoCVPersistence", dependencies: ["PrestoCVApplication", "PrestoCVDomain"]),
]

// Legacy targets: declared only on Apple hosts, and deleted when their replacement is wired in (ADR 0012).
#if !os(Linux)
products.append(.library(name: "PrestoCVCore", targets: ["PrestoCVCore"]))
targets += [
    .target(name: "PrestoCVCore"),
    .testTarget(name: "PrestoCVCoreTests", dependencies: ["PrestoCVCore"]),
]
#endif

let package = Package(
    name: "PrestoCVCore",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: products,
    targets: targets
)

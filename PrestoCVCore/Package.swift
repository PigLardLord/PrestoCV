// swift-tools-version: 6.1
import PackageDescription

// CV Authoring, and CV Import downstream of it (docs/architecture/modules.md).
var products: [Product] = [
    .library(name: "PrestoCVDomain", targets: ["PrestoCVDomain"]),
    .library(name: "PrestoCVApplication", targets: ["PrestoCVApplication"]),
    .library(name: "PrestoCVPersistence", targets: ["PrestoCVPersistence"]),
    .library(name: "PrestoCVCoreTestSupport", targets: ["PrestoCVCoreTestSupport"]),
    .library(name: "PrestoCVImporting", targets: ["PrestoCVImporting"]),
]
var targets: [Target] = [
    .target(name: "PrestoCVDomain"),
    .target(name: "PrestoCVApplication", dependencies: ["PrestoCVDomain"]),
    .target(name: "PrestoCVPersistence", dependencies: ["PrestoCVApplication", "PrestoCVDomain"]),
    .target(name: "PrestoCVCoreTestSupport", dependencies: ["PrestoCVApplication", "PrestoCVDomain"]),
    .testTarget(name: "PrestoCVAuthoringTests", dependencies: ["PrestoCVDomain", "PrestoCVApplication", "PrestoCVCoreTestSupport"]),
    .testTarget(name: "PrestoCVPersistenceTests", dependencies: ["PrestoCVPersistence", "PrestoCVDomain", "PrestoCVApplication", "PrestoCVCoreTestSupport"]),
    // CV Import (ADR 0027): downstream of Authoring, whose value objects it reads.
    .target(name: "PrestoCVImporting", dependencies: ["PrestoCVDomain"]),
    // The synthetic corpus is shared with the PDFKit reader's tests, so it sits next to both test targets.
    .testTarget(name: "PrestoCVImportingTests", dependencies: ["PrestoCVImporting", "PrestoCVDomain"], resources: [.copy("../ImportFixtures")]),
]

// Apple-only adapter (the platform column of docs/architecture/modules.md): not part of a Linux build.
#if !os(Linux)
products.append(.library(name: "PrestoCVImportingPDFKit", targets: ["PrestoCVImportingPDFKit"]))
targets += [
    .target(name: "PrestoCVImportingPDFKit", dependencies: ["PrestoCVImporting"]),
    .testTarget(name: "PrestoCVImportingPDFKitTests", dependencies: ["PrestoCVImportingPDFKit", "PrestoCVImporting"], resources: [.copy("../ImportFixtures")]),
]
#endif

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
    platforms: [.iOS("26.5"), .macOS("26.0")],
    products: products,
    targets: targets
)

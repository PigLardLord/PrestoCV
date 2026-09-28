// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "PrestoCVDomain", targets: ["PrestoCVDomain"]),
        .library(name: "PrestoCVApplication", targets: ["PrestoCVApplication"]),
        .library(name: "PrestoCVPersistence", targets: ["PrestoCVPersistence"]),
        .library(name: "PrestoCVCoreTestSupport", targets: ["PrestoCVCoreTestSupport"]),
    ],
    targets: [
        .target(name: "PrestoCVDomain"),
        .target(name: "PrestoCVApplication", dependencies: ["PrestoCVDomain"]),
        .target(name: "PrestoCVPersistence", dependencies: ["PrestoCVApplication", "PrestoCVDomain"]),
        .target(name: "PrestoCVCoreTestSupport", dependencies: ["PrestoCVApplication", "PrestoCVDomain"]),
        .testTarget(name: "CoreTests", dependencies: ["PrestoCVDomain", "PrestoCVApplication", "PrestoCVPersistence", "PrestoCVCoreTestSupport"]),
    ]
)

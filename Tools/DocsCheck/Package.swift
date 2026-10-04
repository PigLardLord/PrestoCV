// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DocsCheck",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "DocsCheckKit"),
        .executableTarget(name: "DocsCheck", dependencies: ["DocsCheckKit"]),
        .testTarget(name: "DocsCheckKitTests", dependencies: ["DocsCheckKit"]),
    ]
)

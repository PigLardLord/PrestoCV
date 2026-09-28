// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ArchitectureCheck",
    platforms: [.macOS(.v13)],
    dependencies: [.package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0")],
    targets: [
        .executableTarget(name: "ArchitectureCheck", dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftParser", package: "swift-syntax"),
        ]),
    ]
)

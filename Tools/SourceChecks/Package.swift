// swift-tools-version: 6.0
import PackageDescription

// Checks of source text: the string catalog, the rules the app's views follow, and what a Release build must not carry.
// They read the repository, which the machines that run the test plans do not have, so `swift test` runs them where it
// is: on the Linux CI job and on the Xcode Cloud build host, after build-for-testing.
let package = Package(
    name: "SourceChecks",
    platforms: [.macOS(.v13)],
    targets: [
        .testTarget(name: "SourceChecksTests"),
    ]
)

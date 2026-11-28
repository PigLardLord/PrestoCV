// swift-tools-version: 6.0
import PackageDescription

// Checks of source text: the string catalog, the rules the app's views follow, how the tests render views off screen,
// what a Release build must not carry, and the texts of the App Store listing.
// They read the repository, which the machines that run the test plans do not have, so `swift test` runs them where it
// is: on the Linux CI job, on the Mac mini's pull request check and on the Xcode Cloud build host, the last two through
// ci_scripts/ci_post_xcodebuild.sh.
// `StoreListing` reads docs/release/store-listing.md; `store-listing-counts` rewrites its counts table:
// `swift run --package-path Tools/SourceChecks store-listing-counts --write`, from the repository root.
let package = Package(
    name: "SourceChecks",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "StoreListing"),
        .executableTarget(name: "store-listing-counts", dependencies: ["StoreListing"]),
        .testTarget(name: "SourceChecksTests", dependencies: ["StoreListing"], exclude: ["Localization/Planted"]),
    ]
)

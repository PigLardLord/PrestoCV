// swift-tools-version: 6.0
import PackageDescription

// Checks of source text: the string catalog, the rules the app's views follow, how the tests render views off screen,
// and what a Release build must not carry.
// They read the repository, which the machines that run the test plans do not have, so `swift test` runs them where it
// is: on the Linux CI job, on the Mac mini's pull request check and on the Xcode Cloud build host, the last two through
// ci_scripts/ci_post_xcodebuild.sh.
let package = Package(
    name: "SourceChecks",
    platforms: [.macOS(.v13)],
    targets: [
        .testTarget(name: "SourceChecksTests"),
    ]
)

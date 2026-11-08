import Foundation
import Testing

// MARK: - Toolchain Check Script Tests

/// `Tools/check-toolchain.sh` passes only the release of the Swift that `.swift-version` pins. These tests run the script
/// against a stand-in `swift` that prints a given banner, so each banner shape it must accept or refuse is one row.
@Suite("check-toolchain.sh")
struct ToolchainCheckScriptTests {

    struct Row: CustomTestStringConvertible, Sendable {
        let pin: String
        let banner: String
        let passes: Bool

        var testDescription: String { "\(passes ? "passes" : "refuses") \"\(banner.prefix { $0 != "\n" })\" for \(pin)" }
    }

    static let rows: [Row] = [
        // Releases of the pinned version.
        Row(pin: "6.4.2", banner: "Swift version 6.4.2 (swift-6.4.2-RELEASE)\nTarget: x86_64-unknown-linux-gnu", passes: true),
        Row(pin: "6.4.0", banner: "Swift version 6.4 (swift-6.4-RELEASE)\nTarget: aarch64-unknown-linux-gnu", passes: true),
        Row(pin: "6.4.2", banner: "Apple Swift version 6.4.2 (swiftlang-6.4.2.1.9 clang-2100.4.1.1)\nTarget: arm64-apple-macosx27.0", passes: true),
        Row(pin: "6.4.0", banner: "Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)", passes: true),
        Row(pin: "6.4.0", banner: "swift-driver version: 1.130.2 Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)", passes: true),
        Row(pin: "6.4.2", banner: "Apple Swift version 6.4.2 (swift-6.4.2-RELEASE)\nTarget: arm64-apple-macosx27.0", passes: true),
        // Another release.
        Row(pin: "6.4.2", banner: "Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)", passes: false),
        Row(pin: "6.4.2", banner: "Swift version 6.3.3 (swift-6.3.3-RELEASE)", passes: false),
        Row(pin: "6.4.2", banner: "Swift version 6.4.20 (swift-6.4.20-RELEASE)", passes: false),
        Row(pin: "6.4.2", banner: "Apple Swift version 6.4.2 (swiftlang-6.4.20.1.9 clang-2100.4.1.1)", passes: false),
        // A banner whose two numbers disagree.
        Row(pin: "6.4.2", banner: "Swift version 6.4.2 (swift-6.4.3-RELEASE)", passes: false),
        Row(pin: "6.4.2", banner: "Apple Swift version 6.4.2 (swiftlang-6.4.3.1.9 clang-2100.4.1.1)", passes: false),
        // Development snapshots, of the pinned number too.
        Row(pin: "6.4.2", banner: "Swift version 6.4.2 (swift-6.4.2-DEVELOPMENT-SNAPSHOT-2026-11-01-a)", passes: false),
        Row(pin: "6.4.2", banner: "Swift version 6.4.2-dev (LLVM 1234abcd, Swift 5678ef01)", passes: false),
        Row(pin: "6.4.0", banner: "Swift version 6.4-dev (LLVM 1234abcd, Swift 5678ef01)", passes: false),
        Row(pin: "6.4.0", banner: "Apple Swift version 6.4-dev (LLVM 1234abcd, Swift 5678ef01)", passes: false),
        // No banner at all.
        Row(pin: "6.4.2", banner: "", passes: false),
    ]

    @Test("The check passes the release of the pinned Swift and nothing else", arguments: rows)
    func checksTheBanner(row: Row) throws {
        let run = try Self.run(pin: row.pin, banner: row.banner)

        if row.passes {
            #expect(run.status == 0, "refused: \(run.error)")
            #expect(run.output == "check-toolchain: Swift \(row.pin), as .swift-version pins\n")
        } else {
            #expect(run.status != 0, "passed: \(run.output)")
            #expect(run.error.contains("check-toolchain: error:"), "no error line: \(run.error)")
        }
    }

    // MARK: Running the script

    struct Run {
        let status: Int32
        let output: String
        let error: String
    }

    /// Runs a copy of the script in a folder of its own, with `.swift-version` holding `pin` and a `swift` first on the PATH
    /// that prints `banner` for `swift --version`.
    static func run(pin: String, banner: String) throws -> Run {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("check-toolchain-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let tools = folder.appendingPathComponent("Tools")
        let bin = folder.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)

        let script = tools.appendingPathComponent("check-toolchain.sh")
        try FileManager.default.copyItem(at: Repository.root.appendingPathComponent("Tools/check-toolchain.sh"), to: script)
        try "\(pin)\n".write(to: folder.appendingPathComponent(".swift-version"), atomically: true, encoding: .utf8)
        try banner.write(to: folder.appendingPathComponent("banner"), atomically: true, encoding: .utf8)
        let swift = bin.appendingPathComponent("swift")
        try "#!/bin/sh\ncat \"\(folder.path)/banner\"\n".write(to: swift, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: swift.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["bash", script.path]
        process.environment = ["PATH": "\(bin.path):/usr/bin:/bin", "LC_ALL": "C"]
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Run(
            status: process.terminationStatus,
            output: String(decoding: outputData, as: UTF8.self),
            error: String(decoding: errorData, as: UTF8.self)
        )
    }
}

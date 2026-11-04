import Foundation
import Testing

/// The repository the checks read: this file is Tools/SourceChecks/Tests/SourceChecksTests/Repository.swift.
enum Repository {
    static let root = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    /// The files git tracks, as paths relative to the root. A work tree that git cannot read, or one with no tracked file,
    /// throws: a check over an empty list would pass without checking anything.
    static func trackedFiles() throws -> [String] {
        let git = Process()
        git.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        git.arguments = ["git", "ls-files", "-z"]
        git.currentDirectoryURL = root
        var environment = ProcessInfo.processInfo.environment
        for name in environment.keys where name.hasPrefix("GIT_") { environment[name] = nil }
        git.environment = environment
        let output = Pipe()
        git.standardOutput = output
        try git.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        git.waitUntilExit()
        guard git.terminationStatus == 0 else { throw TrackedFilesError.gitFailed(status: git.terminationStatus, root: root.path) }
        let paths = String(decoding: data, as: UTF8.self).split(separator: "\0").map(String.init)
        guard !paths.isEmpty else { throw TrackedFilesError.noFiles(root: root.path) }
        return paths
    }

    /// The text of a file under the root.
    static func text(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}

enum TrackedFilesError: Error, CustomStringConvertible {
    case gitFailed(status: Int32, root: String)
    case noFiles(root: String)

    var description: String {
        switch self {
        case .gitFailed(let status, let root): "`git ls-files` failed with status \(status) in \(root)"
        case .noFiles(let root): "`git ls-files` lists no file in \(root)"
        }
    }
}

@Suite("The repository the source checks read")
struct RepositoryTests {

    /// A scan of a folder that is not there finds nothing wrong, so a wrong root would pass the scans without checking anything.
    @Test("The root holds the app's project, its catalog and the folders whose code ships", arguments: [
        "PrestoCV.xcodeproj/project.xcproj", "PrestoCV/Localizable.xcstrings", "PrestoCV/PrivacyInfo.xcprivacy",
        "PrestoCV/Features", "PrestoCVCore/Sources/PrestoCVCore", "CVPDFExporter/Sources/CVPDFExporter",
        "CVGeneratorAI/Sources/CVGeneratorAI",
    ])
    func rootIsTheRepository(path: String) {
        #expect(FileManager.default.fileExists(atPath: Repository.root.appendingPathComponent(path).path), "\(path) is not under \(Repository.root.path)")
    }

    @Test("The tracked files are relative paths and include the README and a file of a package")
    func trackedFilesAreRelativePaths() throws {
        let tracked = try Repository.trackedFiles()

        #expect(tracked.contains("README.md"))
        #expect(tracked.contains("PrestoCVCore/Package.swift"))
        #expect(tracked.allSatisfy { !$0.hasPrefix("/") }, "git lists a path that is not relative to the root")
    }
}

import Foundation
import Testing

/// The repository the checks read: this file is Tools/SourceChecks/Tests/SourceChecksTests/Repository.swift.
///
/// The checks that walk the repository read the files git tracks (the index), not every file of the work tree: that is what a
/// commit holds and what the check on a pull request sees. A file that is not added is not checked until it is, and a file that
/// is deleted but still in the index is left out by `presentFiles()`.
enum Repository {
    static let root = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    /// The files git tracks, as paths relative to the root. A work tree that git cannot read, or one with no tracked file,
    /// throws: a check over an empty list would pass without checking anything. Git is asked once per run, and every check
    /// that calls this gets the same answer (or the same error).
    static func trackedFiles() throws -> [String] {
        try tracked.get()
    }

    private static let tracked = Result { try listTrackedFiles() }

    /// The tracked files that are in the work tree: the checks that read a file use this list, so that a file deleted but not
    /// yet removed from the index does not fail them.
    static func presentFiles() throws -> [String] {
        present(try trackedFiles())
    }

    /// The paths that are files or folders under `root`.
    static func present(_ paths: [String], under root: URL = Repository.root) -> [String] {
        paths.filter { FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
    }

    /// The text of a file under the root.
    static func text(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    // MARK: - Asking git

    /// Asks git for the tracked files, in `environment` without the variables that bind git to a repository. When the checks
    /// run from a git hook, `GIT_DIR` and `GIT_INDEX_FILE` point at the repository that runs the hook, and `ls-files` would
    /// list that one's index, not this root's. Only those variables are removed: the others, such as `GIT_CONFIG_GLOBAL` or
    /// `GIT_SSH_COMMAND`, are the caller's to keep.
    static func listTrackedFiles(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> [String] {
        let names = try repositoryVariables(environment: environment)
        let listing = try runGit(["ls-files", "-z"], environment: removing(names, from: environment))
        let paths = String(decoding: listing, as: UTF8.self).split(separator: "\0").map(String.init)
        guard !paths.isEmpty else { throw TrackedFilesError.noFiles(root: root.path) }
        return paths
    }

    /// The names of the variables that bind git to a repository, as git lists them (`git rev-parse --local-env-vars`): the
    /// list works outside a repository and with a `GIT_DIR` that is not there.
    static func repositoryVariables(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> [String] {
        let output = try runGit(["rev-parse", "--local-env-vars"], environment: environment)
        return String(decoding: output, as: UTF8.self).split(whereSeparator: \.isNewline).map(String.init)
    }

    /// `environment` without the variables of `names`.
    static func removing(_ names: [String], from environment: [String: String]) -> [String: String] {
        let removed = Set(names)
        return environment.filter { !removed.contains($0.key) }
    }

    private static func runGit(_ arguments: [String], environment: [String: String]) throws -> Data {
        let git = Process()
        git.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        git.arguments = ["git"] + arguments
        git.currentDirectoryURL = root
        git.environment = environment
        let output = Pipe()
        git.standardOutput = output
        try git.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        git.waitUntilExit()
        guard git.terminationStatus == 0 else {
            throw TrackedFilesError.gitFailed(command: arguments.prefix(2).joined(separator: " "), status: git.terminationStatus, root: root.path)
        }
        return data
    }
}

enum TrackedFilesError: Error, CustomStringConvertible {
    case gitFailed(command: String, status: Int32, root: String)
    case noFiles(root: String)

    var description: String {
        switch self {
        case .gitFailed(let command, let status, let root): "`git \(command)` failed with status \(status) in \(root)"
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

    /// Run from a git hook, the checks inherit the hook's `GIT_DIR` and `GIT_INDEX_FILE`.
    @Test("The tracked files are those of this root, whatever repository the caller's environment names")
    func trackedFilesIgnoreTheCallersRepository() throws {
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_DIR"] = "/nonexistent/repository"
        environment["GIT_INDEX_FILE"] = "/nonexistent/index"

        let listed = try Repository.listTrackedFiles(environment: environment)

        #expect(listed.contains("README.md"))
        #expect(listed.contains("PrestoCVCore/Package.swift"))
    }

    @Test("Git names the variables that bind it to a repository, and not the others")
    func gitNamesTheRepositoryVariables() throws {
        let names = try Repository.repositoryVariables()

        #expect(names.contains("GIT_DIR"))
        #expect(names.contains("GIT_INDEX_FILE"))
        #expect(names.contains("GIT_WORK_TREE"))
        #expect(!names.contains("GIT_SSH_COMMAND"))
        #expect(!names.contains("PATH"))
    }

    @Test("Only the variables named are removed from an environment, and the others are kept")
    func onlyTheNamedVariablesAreRemoved() {
        let environment = ["GIT_DIR": "a", "GIT_INDEX_FILE": "b", "GIT_SSH_COMMAND": "ssh -i key", "GIT_CONFIG_GLOBAL": "/dev/null", "PATH": "/usr/bin"]

        let kept = Repository.removing(["GIT_DIR", "GIT_INDEX_FILE", "GIT_WORK_TREE"], from: environment)

        #expect(kept == ["GIT_SSH_COMMAND": "ssh -i key", "GIT_CONFIG_GLOBAL": "/dev/null", "PATH": "/usr/bin"])
    }

    @Test("A path deleted from the work tree but still listed is left out, and a folder is kept")
    func presentFilesAreThoseInTheWorkTree() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("repository-present-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try "text".write(to: folder.appendingPathComponent("docs/here.md"), atomically: true, encoding: .utf8)

        let present = Repository.present(["docs/here.md", "docs/gone.md", "docs", "missing"], under: folder)

        #expect(present == ["docs/here.md", "docs"])
    }
}

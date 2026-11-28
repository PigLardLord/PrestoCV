import Foundation

/// The locales still written for 1.0 (`pendingLocales`) on the target branch of a pull request, read with
/// `git show <ref>:<file>`: the list of this branch may only shrink compared with it.
enum TargetBranch {
    /// The variable that names the target branch's ref (`origin/main`): `Tools/check-linux.sh` sets it from its argument and
    /// `ci_scripts/ci_post_xcodebuild.sh` from `CI_PULL_REQUEST_TARGET_BRANCH`. A run with none (a computer, a branch with no
    /// pull request) has nothing to compare with.
    static let variable = "PRESTOCV_TARGET_REF"

    enum Baseline: Equatable {
        /// The target branch has no such file: nothing to compare with.
        case notCompared
        case list([String])
    }

    /// A checkout without the ref (a shallow one) compares with an empty list, as the architecture baseline does.
    static func pendingLocales(ref: String, file: String, in root: URL = Repository.root) throws -> Baseline {
        guard git(["rev-parse", "--verify", "--quiet", "\(ref)^{commit}"], in: root) != nil else { return .list([]) }
        guard let data = git(["show", "\(ref):\(file)"], in: root) else { return .notCompared }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return .list(object?["pendingLocales"] as? [String] ?? [])
    }

    /// The output of git, or nil when it fails. The variables that bind git to a repository are removed, as in `Repository`.
    static func git(_ arguments: [String], in root: URL) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = root
        let environment = ProcessInfo.processInfo.environment
        process.environment = Repository.removing((try? Repository.repositoryVariables(environment: environment)) ?? [], from: environment)
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
}

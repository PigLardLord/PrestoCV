#if DEBUG
import DiagnosticTrace
import Foundation
import PrestoCVApplication
import PrestoCVWorkflowPorts

/// What a UI test asks of a Debug build through its launch arguments, parsed once into a typed value (R13: codes, not
/// sentences). The type exists only in Debug, so a Release build has no code that reads these arguments
/// (`ReleaseHygieneTests`).
///
/// - `-PrestoCVNextStorage <name>`: a folder of that name, which the launches of one test share.
/// - `-PrestoCVNextEmptyStorage`: a new, empty folder for this launch.
/// - `-PrestoCVNextSeed <base 64>`: the CV files to put in that folder before the app reads it, as a JSON map from file name
///   to content. It needs one of the two storage arguments, so that it never writes into the device's own folder.
/// - `-PrestoCVNextDistribution <answer>`: the answer the store would give about how the app was installed (ADR 0032).
/// - `-PrestoCVNextNoSamples`: the examples come from a folder of the fixture that nothing makes, so the app cannot read
///   them. It needs one of the two storage arguments, as the seed does.
/// - `-PrestoCVNextFailRenamesInPairs`: the list's renames are held until a second one comes, and then both fail, so that two
///   failures of two rows are pending at once. It needs one of the two storage arguments, as the seed does.
/// - `-PrestoCVNextShareStandIn`: a share opens a stand-in of the system's share sheet, which a UI test can read and
///   answer (save, send, cancel), and never the system's own. It writes nothing, so it needs no folder.
/// - `-PrestoCVNextOtherWindow <conflict|deleted>`: another window changes the stored CV written first, once, just before
///   that write: it saves the CV (a conflict) or deletes it. It needs one of the two storage arguments, as the seed does.
struct LaunchFixtures: Equatable, Sendable {
    enum Storage: Equatable, Sendable { case device, empty, named(String) }

    /// What another window does to the stored CV written first
    enum OtherWindow: String, CaseIterable, Equatable, Sendable {
        case conflict
        case deleted
    }

    enum Failure: Error, Equatable, Sendable {
        case conflictingStorage
        case missingValue(argument: String)
        case invalidFolderName
        case unreadableSeed
        case unreadableDistribution
        case seedWithoutFolder
        case samplesWithoutFolder
        case failuresWithoutFolder
        case unreadableOtherWindow
        case otherWindowWithoutFolder
        case seedUnwritable
        /// The fixture folder, or a folder inside it, is a link, or leads out of the temporary folder
        case unsafeFolder
    }

    static let storageArgument = "-PrestoCVNextStorage"
    static let emptyStorageArgument = "-PrestoCVNextEmptyStorage"
    static let seedArgument = "-PrestoCVNextSeed"
    static let distributionArgument = "-PrestoCVNextDistribution"
    static let noSamplesArgument = "-PrestoCVNextNoSamples"
    static let failRenamesInPairsArgument = "-PrestoCVNextFailRenamesInPairs"
    static let shareStandInArgument = "-PrestoCVNextShareStandIn"
    static let otherWindowArgument = "-PrestoCVNextOtherWindow"
    private static let prefix = "-PrestoCVNext"

    var storage: Storage = .device
    /// The CV files to write before the app starts, by file name
    var seed: [String: String] = [:]
    var distribution: DistributionAnswer?
    /// The arguments that start like a fixture and are none: ignored, and named so that a test's typo shows
    var unknownArguments: [String] = []
    /// The examples are read from a folder that is not there
    var withoutSamples = false
    /// The list's renames fail two at a time
    var failsRenamesInPairs = false
    /// A share opens the stand-in of the share sheet
    var sharesWithStandIn = false
    /// What another window does to the stored CV written first, nil when no other window changes it
    var otherWindow: OtherWindow?

    /// Reads the arguments the process was launched with (the first is the program).
    static func parse(_ arguments: [String]) throws(Failure) -> LaunchFixtures {
        var fixtures = LaunchFixtures()
        var named: String?
        var empty = false
        var hasSeed = false
        var index = arguments.startIndex + 1
        while index < arguments.endIndex {
            let argument = arguments[index]
            index += 1
            switch argument {
            case emptyStorageArgument:
                empty = true
            case storageArgument:
                named = try value(after: argument, in: arguments, at: &index)
            case seedArgument:
                fixtures.seed = try seed(try value(after: argument, in: arguments, at: &index))
                hasSeed = true
            case distributionArgument:
                guard let answer = DistributionAnswer(rawValue: try value(after: argument, in: arguments, at: &index)) else {
                    throw .unreadableDistribution
                }
                fixtures.distribution = answer
            case noSamplesArgument:
                fixtures.withoutSamples = true
            case failRenamesInPairsArgument:
                fixtures.failsRenamesInPairs = true
            case shareStandInArgument:
                fixtures.sharesWithStandIn = true
            case otherWindowArgument:
                guard let change = OtherWindow(rawValue: try value(after: argument, in: arguments, at: &index)) else {
                    throw .unreadableOtherWindow
                }
                fixtures.otherWindow = change
            case _ where argument.hasPrefix(prefix):
                fixtures.unknownArguments.append(argument)
            default:
                continue
            }
        }
        if empty && named != nil { throw .conflictingStorage }
        if let named {
            guard isFolderName(named) else { throw .invalidFolderName }
            fixtures.storage = .named(named)
        } else if empty {
            fixtures.storage = .empty
        }
        if hasSeed && fixtures.storage == .device { throw .seedWithoutFolder }
        if fixtures.withoutSamples && fixtures.storage == .device { throw .samplesWithoutFolder }
        if fixtures.failsRenamesInPairs && fixtures.storage == .device { throw .failuresWithoutFolder }
        if fixtures.otherWindow != nil && fixtures.storage == .device { throw .otherWindowWithoutFolder }
        return fixtures
    }

    /// The paths this launch uses: the device's, or a folder of the fixture under the temporary folder.
    /// - Parameter fresh: The name of the folder of an empty storage, new on each launch.
    func paths(device: AppPaths, fresh: UUID) -> AppPaths {
        let name: String
        switch storage {
        case .device: return device
        case .empty: name = fresh.uuidString
        case .named(let given): name = given
        }
        let root = device.temporary.appendingPathComponent("PrestoCVNextFixture-\(name)", isDirectory: true)
        return AppPaths(root: root, temporary: device.temporary)
    }

    /// The folder the examples are read from: the bundle's, or without examples a folder of the fixture that nothing makes.
    func samples(bundled: URL, paths: AppPaths) -> URL {
        withoutSamples ? paths.root.appendingPathComponent("Samples", isDirectory: true) : bundled
    }

    /// What the list edits through: the editing it is given, or with the fixture one that fails its renames two at a time.
    func listEditing(_ editing: any CVEditing) -> any CVEditing {
        failsRenamesInPairs ? PairedRenameFailures(inner: editing) : editing
    }

    /// What the app stores through: the store it is given, or with the fixture one that another window changes once.
    func store(_ repository: any CVRepository) -> any CVRepository {
        otherWindow.map { OtherWindowStore(inner: repository, change: $0) } ?? repository
    }

    /// Checks, without making or removing anything, that a fixture folder is a plain folder of the temporary folder: no
    /// link on the way to its store, design or trace folder, and nothing outside the temporary folder. The composition runs it
    /// before anything touches these paths, the purge of the trace included, so a link planted in the temporary folder
    /// never leads a launch into another folder, such as the real store, its designs or its traces.
    func check(_ paths: AppPaths) throws(Failure) {
        guard storage != .device else { return }
        try Self.requirePlainFolders(of: paths)
    }

    /// Makes the fixture ready before the app reads it: for a fixture folder, checks it again and then writes the seed.
    /// Nothing is made or written before the check passes.
    func prepare(_ paths: AppPaths) throws(Failure) {
        guard storage != .device else { return }
        try check(paths)
        try writeSeed(into: paths.store)
    }

    /// Puts the seed in the store folder, which it makes.
    func writeSeed(into directory: URL) throws(Failure) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (name, content) in seed {
                try Data(content.utf8).write(to: directory.appendingPathComponent(name), options: Self.writingOptions)
            }
        } catch {
            throw .seedUnwritable
        }
    }

    /// Atomic, and complete file protection where the platform applies it, as the trace store does: a host Mac does not
    /// apply it, and a locked keybag would refuse the write there.
    private static var writingOptions: Data.WritingOptions {
        #if os(iOS)
        [.atomic, .completeFileProtection]
        #else
        [.atomic]
        #endif
    }

    // MARK: Checking

    /// Refuses a root, a store, a design or a trace folder, or any folder between them and the temporary folder, that is a link, and
    /// a root that resolves to somewhere outside the temporary folder.
    private static func requirePlainFolders(of paths: AppPaths) throws(Failure) {
        let temporary = paths.temporary.standardizedFileURL.path
        for folder in [paths.store, paths.designs, paths.trace] {
            var url = folder.standardizedFileURL
            while url.path.hasPrefix(temporary + "/") {
                if isLink(url) { throw .unsafeFolder }
                url.deleteLastPathComponent()
            }
        }
        let resolvedTemporary = paths.temporary.resolvingSymlinksInPath().path
        guard paths.root.resolvingSymlinksInPath().path.hasPrefix(resolvedTemporary + "/") else { throw .unsafeFolder }
    }

    /// Whether the entry is a link. An entry that is not there is none; one that cannot be read counts as one (fail closed).
    private static func isLink(_ url: URL) -> Bool {
        do {
            return try FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType == .typeSymbolicLink
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return false
        } catch {
            return true
        }
    }

    // MARK: Reading

    private static func value(after argument: String, in arguments: [String], at index: inout Int) throws(Failure) -> String {
        guard index < arguments.endIndex else { throw .missingValue(argument: argument) }
        defer { index += 1 }
        return arguments[index]
    }

    private static func isFolderName(_ name: String) -> Bool {
        name.fullyMatches(#"[A-Za-z0-9_-]{1,64}"#)
    }

    private static func seed(_ encoded: String) throws(Failure) -> [String: String] {
        guard let data = Data(base64Encoded: encoded) else { throw .unreadableSeed }
        let files: [String: String]
        do { files = try JSONDecoder().decode([String: String].self, from: data) } catch { throw .unreadableSeed }
        guard files.keys.allSatisfy({ $0.fullyMatches(#"[A-Za-z0-9_-]{1,64}\.cv\.json"#) }) else { throw .unreadableSeed }
        return files
    }
}

/// A distribution that answers what the launch arguments say.
struct GivenDistribution: DistributionReading {
    let given: DistributionAnswer

    func answer() async throws -> DistributionAnswer {
        given
    }
}

private extension String {
    func fullyMatches(_ pattern: String) -> Bool {
        range(of: "^(?:\(pattern))\\z", options: .regularExpression) != nil
    }
}
#endif

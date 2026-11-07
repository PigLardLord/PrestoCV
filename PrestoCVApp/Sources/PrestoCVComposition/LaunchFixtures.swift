#if DEBUG
import DiagnosticTrace
import Foundation

/// What a UI test asks of a Debug build through its launch arguments, parsed once into a typed value (R13: codes, not
/// sentences). The type exists only in Debug, so a Release build has no code that reads these arguments
/// (`ReleaseHygieneTests`).
///
/// - `-PrestoCVNextStorage <name>`: a folder of that name, which the launches of one test share.
/// - `-PrestoCVNextEmptyStorage`: a new, empty folder for this launch.
/// - `-PrestoCVNextSeed <base 64>`: the CV files to put in that folder before the app reads it, as a JSON map from file name
///   to content. It needs one of the two storage arguments, so that it never writes into the device's own folder.
/// - `-PrestoCVNextDistribution <answer>`: the answer the store would give about how the app was installed (ADR 0032).
struct LaunchFixtures: Equatable, Sendable {
    enum Storage: Equatable, Sendable { case device, empty, named(String) }

    enum Failure: Error, Equatable, Sendable {
        case conflictingStorage
        case missingValue(argument: String)
        case invalidFolderName
        case unreadableSeed
        case unreadableDistribution
        case seedWithoutFolder
        case seedUnwritable
    }

    static let storageArgument = "-PrestoCVNextStorage"
    static let emptyStorageArgument = "-PrestoCVNextEmptyStorage"
    static let seedArgument = "-PrestoCVNextSeed"
    static let distributionArgument = "-PrestoCVNextDistribution"
    private static let prefix = "-PrestoCVNext"

    var storage: Storage = .device
    /// The CV files to write before the app starts, by file name
    var seed: [String: String] = [:]
    var distribution: DistributionAnswer?
    /// The arguments that start like a fixture and are none: ignored, and named so that a test's typo shows
    var unknownArguments: [String] = []

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

    /// Puts the seed in the store folder, which it makes.
    func writeSeed(into directory: URL) throws(Failure) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (name, content) in seed {
                try Data(content.utf8).write(to: directory.appendingPathComponent(name), options: .atomic)
            }
        } catch {
            throw .seedUnwritable
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

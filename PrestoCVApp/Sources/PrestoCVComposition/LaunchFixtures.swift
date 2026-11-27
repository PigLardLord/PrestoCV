#if DEBUG
import CVDesignCatalog
import DiagnosticTrace
import Foundation
import PrestoCVApplication
import PrestoCVLegacyLeftovers
import PrestoCVWorkflowPorts

/// What a UI test asks of a Debug build through its launch arguments, parsed once into a typed value (R13: codes, not
/// sentences). The type exists only in Debug, so a Release build has no code that reads these arguments
/// (`ReleaseHygieneTests`).
///
/// - `-PrestoCVNextStorage <name>`: a folder of that name, which the launches of one test share.
/// - `-PrestoCVNextEmptyStorage`: a new, empty folder for this launch.
/// - `-PrestoCVNextSeed <base 64>`: the CV files to put in that folder before the app reads it, as a JSON map from file name
///   to content. It needs one of the two storage arguments, so that it never writes into the device's own folder.
/// - `-PrestoCVNextLegacySeed <base 64>`: the released app's CV files to put in the fixture's legacy folder before the
///   import reads it, as a JSON map from file name (`cv_<id>.json`) to content. It needs one of the two storage arguments,
///   as the seed does. A test leaves it out of a relaunch, so the files the import removed stay removed.
/// - `-PrestoCVNextDistribution <answer>`: the answer the store would give about how the app was installed (ADR 0032).
/// - `-PrestoCVNextTips <offers|notAllowed|unreachable|noOffers|failed|cancelled|pending|purchaseFailed>`: what the store
///   answers about the tip jar, without StoreKit: its three offers, or the reason there are none. With `offers` a purchase
///   goes through; `cancelled`, `pending` and `purchaseFailed` show the three offers and answer a purchase so. It writes
///   nothing, so it needs no folder.
/// - `-PrestoCVNextNoSamples`: the examples come from a folder of the fixture that nothing makes, so the app cannot read
///   them. It needs one of the two storage arguments, as the seed does.
/// - `-PrestoCVNextFailRenamesInPairs`: the list's renames are held until a second one comes, and then both fail, so that two
///   failures of two rows are pending at once. It needs one of the two storage arguments, as the seed does.
/// - `-PrestoCVNextShareStandIn`: a share opens a stand-in of the system's share sheet, which a UI test can read and
///   answer (save, send, cancel), and never the system's own. It writes nothing, so it needs no folder.
/// - `-PrestoCVNextTraceRuns`: two invented runs of the diagnostics (an AI draft that finished, an import that failed) are
///   stored before the trace chain starts, so that a closed gate purges them and an open one lists them. The launch shows
///   its first screen only once the gate has done so. It needs one of the two storage arguments, as the seed does.
/// - `-PrestoCVNextOtherWindow <conflict|deleted>`: another window changes the stored CV written first, once, just before
///   that write: it saves the CV (a conflict) or deletes it. It needs one of the two storage arguments, as the seed does.
/// - `-PrestoCVNextFailWrites <count>`: the first `<count>` writes of a CV (a creation, a replacement, a deletion) fail with a
///   failed write, and the writes after them succeed; a count that never runs out never succeeds. It needs one of the two
///   storage arguments, as the seed does.
/// - `-PrestoCVNextAutosavePause <seconds>`: the editors' autosave waits this many whole seconds (at least one) after the last
///   change, instead of its own pause, so that a UI test leaves an editor before the pause is over, however long the typing
///   took. It writes nothing, so it needs no folder.
/// - `-PrestoCVNextHoldImport`: a read of the import never ends by itself, and ends as cancelled when the person cancels it.
///   It writes nothing, so it needs no folder.
/// - `-PrestoCVNextOpenedFile <linkedin>`: each time a window becomes active, it is handed the PDF of the corpus of that
///   name, which only a Debug build carries, as if another app opened it there. It writes nothing, so it needs no folder.
/// - `-PrestoCVNextReadyDesigns`: the bundled designs are accepted without the renders that check them (`AcceptedDesigns`),
///   so that a UI test that is not about the designs or the first launch does not wait for those renders on every launch of
///   an empty folder. The sync, its validator and the design store stay the real ones. It needs one of the two storage
///   arguments, as the seed does, so that the device's own design store never holds a design that no render checked. A
///   named folder keeps its designs for the next launch, which then finds them unchanged and does not check them either.
struct LaunchFixtures: Equatable, Sendable {
    enum Storage: Equatable, Sendable { case device, empty, named(String) }

    /// What another window does to the stored CV written first
    enum OtherWindow: String, CaseIterable, Equatable, Sendable {
        case conflict
        case deleted
    }

    /// What the store answers about the tips
    enum TipsAnswer: String, CaseIterable, Equatable, Sendable {
        case offers
        case notAllowed
        case unreachable
        case noOffers
        case failed
        case cancelled
        case pending
        case purchaseFailed
    }

    /// The PDF of the corpus a window is handed as if another app opened it, by its name in the bundle
    enum OpenedFile: String, CaseIterable, Equatable, Sendable {
        case linkedin
    }

    enum Failure: Error, Equatable, Sendable {
        case conflictingStorage
        case missingValue(argument: String)
        case invalidFolderName
        case unreadableSeed
        case unreadableDistribution
        case unreadableTips
        case seedWithoutFolder
        case unreadableLegacySeed
        case legacySeedWithoutFolder
        case samplesWithoutFolder
        case failuresWithoutFolder
        case unreadableOtherWindow
        case otherWindowWithoutFolder
        case unreadableFailWrites
        case failWritesWithoutFolder
        case unreadableAutosavePause
        case unreadableOpenedFile
        case traceRunsWithoutFolder
        case readyDesignsWithoutFolder
        case seedUnwritable
        /// The fixture folder, or a folder inside it, is a link, or leads out of the temporary folder
        case unsafeFolder
    }

    static let storageArgument = "-PrestoCVNextStorage"
    static let emptyStorageArgument = "-PrestoCVNextEmptyStorage"
    static let seedArgument = "-PrestoCVNextSeed"
    static let legacySeedArgument = "-PrestoCVNextLegacySeed"
    static let distributionArgument = "-PrestoCVNextDistribution"
    static let tipsArgument = "-PrestoCVNextTips"
    static let noSamplesArgument = "-PrestoCVNextNoSamples"
    static let failRenamesInPairsArgument = "-PrestoCVNextFailRenamesInPairs"
    static let shareStandInArgument = "-PrestoCVNextShareStandIn"
    static let otherWindowArgument = "-PrestoCVNextOtherWindow"
    static let failWritesArgument = "-PrestoCVNextFailWrites"
    static let autosavePauseArgument = "-PrestoCVNextAutosavePause"
    static let holdImportArgument = "-PrestoCVNextHoldImport"
    static let openedFileArgument = "-PrestoCVNextOpenedFile"
    static let traceRunsArgument = "-PrestoCVNextTraceRuns"
    static let readyDesignsArgument = "-PrestoCVNextReadyDesigns"
    private static let prefix = "-PrestoCVNext"

    var storage: Storage = .device
    /// The CV files to write before the app starts, by file name
    var seed: [String: String] = [:]
    /// The released app's CV files to write in the legacy folder before the import reads it, by file name
    var legacySeed: [String: String] = [:]
    var distribution: DistributionAnswer?
    /// What the store answers about the tips, nil when the real store does
    var tips: TipsAnswer?
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
    /// How many of the first writes of a CV fail, nil when none does
    var writesToFail: Int?
    /// How many whole seconds the editors' autosave waits after the last change, nil for its own pause
    var autosavePauseSeconds: Int?
    /// The import's reads wait until they are cancelled
    var holdsImport = false
    /// The PDF a window is handed each time it becomes active, nil when none is
    var openedFile: OpenedFile?
    /// Two invented runs of the diagnostics are stored before the app starts
    var storesTraceRuns = false
    /// The bundled designs are accepted without the renders that check them
    var acceptsBundledDesigns = false

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
            case legacySeedArgument:
                fixtures.legacySeed = try files(
                    try value(after: argument, in: arguments, at: &index), named: #"cv_[A-Za-z0-9-]{1,64}\.json"#,
                    else: .unreadableLegacySeed
                )
            case distributionArgument:
                guard let answer = DistributionAnswer(rawValue: try value(after: argument, in: arguments, at: &index)) else {
                    throw .unreadableDistribution
                }
                fixtures.distribution = answer
            case tipsArgument:
                guard let answer = TipsAnswer(rawValue: try value(after: argument, in: arguments, at: &index)) else {
                    throw .unreadableTips
                }
                fixtures.tips = answer
            case noSamplesArgument:
                fixtures.withoutSamples = true
            case failRenamesInPairsArgument:
                fixtures.failsRenamesInPairs = true
            case shareStandInArgument:
                fixtures.sharesWithStandIn = true
            case traceRunsArgument:
                fixtures.storesTraceRuns = true
            case otherWindowArgument:
                guard let change = OtherWindow(rawValue: try value(after: argument, in: arguments, at: &index)) else {
                    throw .unreadableOtherWindow
                }
                fixtures.otherWindow = change
            case failWritesArgument:
                guard let count = Int(try value(after: argument, in: arguments, at: &index)), count >= 0 else {
                    throw .unreadableFailWrites
                }
                fixtures.writesToFail = count
            case autosavePauseArgument:
                guard let seconds = Int(try value(after: argument, in: arguments, at: &index)), seconds >= 1 else {
                    throw .unreadableAutosavePause
                }
                fixtures.autosavePauseSeconds = seconds
            case holdImportArgument:
                fixtures.holdsImport = true
            case openedFileArgument:
                guard let file = OpenedFile(rawValue: try value(after: argument, in: arguments, at: &index)) else {
                    throw .unreadableOpenedFile
                }
                fixtures.openedFile = file
            case readyDesignsArgument:
                fixtures.acceptsBundledDesigns = true
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
        if !fixtures.legacySeed.isEmpty && fixtures.storage == .device { throw .legacySeedWithoutFolder }
        if fixtures.withoutSamples && fixtures.storage == .device { throw .samplesWithoutFolder }
        if fixtures.failsRenamesInPairs && fixtures.storage == .device { throw .failuresWithoutFolder }
        if fixtures.otherWindow != nil && fixtures.storage == .device { throw .otherWindowWithoutFolder }
        if fixtures.writesToFail != nil && fixtures.storage == .device { throw .failWritesWithoutFolder }
        if fixtures.storesTraceRuns && fixtures.storage == .device { throw .traceRunsWithoutFolder }
        if fixtures.acceptsBundledDesigns && fixtures.storage == .device { throw .readyDesignsWithoutFolder }
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

    /// The legacy store this launch imports from: the device's, or for a fixture folder a folder in it, so that a launch
    /// with a fixture never reads, or removes, the files of the released app.
    func legacyStore(device: URL, paths: AppPaths) -> URL {
        storage == .device ? device : Self.legacyFolder(of: paths)
    }

    /// What the launch removes of the released app's leftovers: the device's, or for a fixture folder a folder in it, so that
    /// a launch with a fixture never touches the files of the released app.
    func legacyLeftovers(device: LegacyLeftoverPaths, paths: AppPaths) -> LegacyLeftoverPaths {
        storage == .device ? device : LegacyLeftoverPaths(applicationSupport: Self.legacySupport(of: paths))
    }

    /// What the list edits through: the editing it is given, or with the fixture one that fails its renames two at a time.
    func listEditing(_ editing: any CVEditing) -> any CVEditing {
        failsRenamesInPairs ? PairedRenameFailures(inner: editing) : editing
    }

    /// The pause of the editors' autosave: the given one, or with the fixture the seconds it asks for.
    func autosavePause(_ normal: Duration) -> Duration {
        autosavePauseSeconds.map { Duration.seconds($0) } ?? normal
    }

    /// What the import reads through: the importer it is given, or with the fixture one whose reads wait until cancelled.
    func importing(_ importer: any CVImporting) -> any CVImporting {
        holdsImport ? HeldImport() : importer
    }

    /// What a window is handed as if another app opened it: the PDF of that name among `resources`, the bundle's.
    func openedFileFixture(in resources: URL) -> OpenedFileFixture? {
        openedFile.map { OpenedFileFixture(file: resources.appendingPathComponent("\($0.rawValue).pdf")) }
    }

    /// What checks a bundled design before the sync saves it: the gate it is given, or with the fixture one that accepts
    /// every design without rendering it.
    func designGate(_ gate: any DesignRenderingGate) -> any DesignRenderingGate {
        acceptsBundledDesigns ? AcceptedDesigns() : gate
    }

    /// What the app stores through: the store it is given, or with the fixture one that another window changes once, and
    /// one whose first writes fail.
    func store(_ repository: any CVRepository) -> any CVRepository {
        let changed = otherWindow.map { OtherWindowStore(inner: repository, change: $0) } ?? repository
        return writesToFail.map { FailingWritesStore(inner: changed, count: $0) } ?? changed
    }

    /// Checks, without making or removing anything, that a fixture folder is a plain folder of the temporary folder: no
    /// link on the way to its store, design, trace or legacy folder, and nothing outside the temporary folder. The
    /// composition runs it before anything touches these paths, the purge of the trace included, so a link planted in the
    /// temporary folder never leads a launch into another folder, such as the real store, its designs, its traces or the
    /// released app's store.
    func check(_ paths: AppPaths) throws(Failure) {
        guard storage != .device else { return }
        try Self.requirePlainFolders(of: paths)
    }

    /// Whether the fixture folder passes `check`: a failure is not reported here, since `make` runs the check and fails the
    /// launch with it.
    func passesCheck(_ paths: AppPaths) -> Bool {
        do throws(Failure) {
            try check(paths)
            return true
        } catch {
            return false
        }
    }

    /// Makes the fixture ready before the app reads it: for a fixture folder, checks it again and then writes the seed and
    /// the legacy seed. Nothing is made or written before the check passes.
    func prepare(_ paths: AppPaths) throws(Failure) {
        guard storage != .device else { return }
        try check(paths)
        try writeSeed(into: paths.store)
        if !legacySeed.isEmpty { try Self.write(legacySeed, into: Self.legacyFolder(of: paths)) }
    }

    /// Stores the invented runs, when the fixture asks for them, in the trace folder of a fixture folder. Called after the
    /// check and before the trace chain starts, so that the gate then decides what becomes of them.
    func seedTrace(into paths: AppPaths) async {
        guard storesTraceRuns, storage != .device else { return }
        await InventedTraceRuns.store(into: paths)
    }

    /// Puts the seed in the store folder, which it makes.
    func writeSeed(into directory: URL) throws(Failure) {
        try Self.write(seed, into: directory)
    }

    /// Puts the files in the folder, which it makes.
    private static func write(_ files: [String: String], into directory: URL) throws(Failure) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (name, content) in files {
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
        let legacyApp = LegacyLeftoverPaths(applicationSupport: legacySupport(of: paths)).appFolder
        for folder in [paths.store, paths.designs, paths.trace, legacyFolder(of: paths), legacyApp] {
            var url = folder.standardizedFileURL
            while url.path.hasPrefix(temporary + "/") {
                if isLink(url) { throw .unsafeFolder }
                url.deleteLastPathComponent()
            }
        }
        let resolvedTemporary = paths.temporary.resolvingSymlinksInPath().path
        guard paths.root.resolvingSymlinksInPath().path.hasPrefix(resolvedTemporary + "/") else { throw .unsafeFolder }
    }

    /// The fixture's stand-in for the released app's Application Support: the folders the cleanup removes lie in it.
    private static func legacySupport(of paths: AppPaths) -> URL {
        paths.root.appendingPathComponent("LegacySupport", isDirectory: true)
    }

    private static func legacyFolder(of paths: AppPaths) -> URL {
        paths.root.appendingPathComponent("Legacy", isDirectory: true)
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
        try files(encoded, named: #"[A-Za-z0-9_-]{1,64}\.cv\.json"#, else: .unreadableSeed)
    }

    /// A JSON map from file name to content, in base 64, whose names all match the pattern.
    private static func files(
        _ encoded: String, named pattern: String, else failure: Failure
    ) throws(Failure) -> [String: String] {
        guard let data = Data(base64Encoded: encoded) else { throw failure }
        let files: [String: String]
        do { files = try JSONDecoder().decode([String: String].self, from: data) } catch { throw failure }
        guard files.keys.allSatisfy({ $0.fullyMatches(pattern) }) else { throw failure }
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

/// The tips the store would answer, given by a launch argument: the listener has nothing to listen to.
struct GivenTips: TipsListening {
    let given: LaunchFixtures.TipsAnswer

    func start() {}

    var canPay: Bool { given != .notAllowed }

    func offers() async throws(TipFailure) -> [TipOffer] {
        switch given {
        case .offers, .notAllowed, .cancelled, .pending, .purchaseFailed:
            TipSize.allCases.map { TipOffer(size: $0, price: Self.price(of: $0)) }
        case .noOffers: []
        case .unreachable: throw .unreachable
        case .failed: throw .failed
        }
    }

    /// The offers' answer buys: a tip goes through. A device that may not pay, or a store that cannot be reached, refuses
    /// the purchase as it refused the offers.
    func purchase(_ size: TipSize) async throws(TipFailure) -> TipPurchase {
        switch given {
        case .offers: .completed
        case .cancelled: .cancelled
        case .pending: .pending
        case .notAllowed: throw .notAllowed
        case .unreachable: throw .unreachable
        case .noOffers, .failed, .purchaseFailed: throw .failed
        }
    }

    private static func price(of size: TipSize) -> String {
        switch size {
        case .small: "€1,99"
        case .medium: "€4,99"
        case .large: "€9,99"
        }
    }
}

private extension String {
    func fullyMatches(_ pattern: String) -> Bool {
        range(of: "^(?:\(pattern))\\z", options: .regularExpression) != nil
    }
}
#endif

#if DEBUG
import DiagnosticTrace
import Foundation
import PrestoCVApplication
import PrestoCVLegacyLeftovers
import PrestoCVWorkflowPorts
import Testing
@testable import PrestoCVComposition

/// The launch arguments of a Debug build, parsed once into a typed value (R13: codes, not sentences).
@Suite("The launch fixtures of a Debug build")
struct LaunchFixturesTests {
    private static let program = "/path/to/PrestoCVNext"

    private static func seed(_ files: [String: String]) throws -> String {
        try JSONEncoder().encode(files).base64EncodedString()
    }

    @Test("A launch with no fixture argument keeps the device storage and the gate of the build")
    func plainLaunch() throws {
        let fixtures = try LaunchFixtures.parse([Self.program])
        #expect(fixtures == LaunchFixtures(storage: .device, seed: [:], distribution: nil, unknownArguments: []))
        #expect(!fixtures.withoutSamples)
    }

    @Test("A named storage is read as the name")
    func namedStorage() throws {
        let fixtures = try LaunchFixtures.parse([Self.program, "-PrestoCVNextStorage", "relaunch-1"])
        #expect(fixtures.storage == .named("relaunch-1"))
    }

    @Test("The empty storage argument asks for a new folder")
    func emptyStorage() throws {
        #expect(try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage"]).storage == .empty)
    }

    @Test("The seed is a map from file name to content, read from its base 64 form")
    func seedFiles() throws {
        let files = ["one.cv.json": "{}", "two.cv.json": "[]"]
        let fixtures = try LaunchFixtures.parse([
            Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", Self.seed(files),
        ])
        #expect(fixtures.seed == files)
    }

    @Test("Every answer of the distribution is read, and one that is not an answer fails")
    func distribution() throws {
        for answer in DistributionAnswer.allCases {
            let fixtures = try LaunchFixtures.parse([Self.program, "-PrestoCVNextDistribution", answer.rawValue])
            #expect(fixtures.distribution == answer)
        }
        #expect(throws: LaunchFixtures.Failure.unreadableDistribution) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextDistribution", "beta"])
        }
    }

    @Test("Every answer of the tips is read, and one that is not an answer fails")
    func tips() throws {
        for answer in LaunchFixtures.TipsAnswer.allCases {
            let fixtures = try LaunchFixtures.parse([Self.program, "-PrestoCVNextTips", answer.rawValue])
            #expect(fixtures.tips == answer)
        }
        #expect(throws: LaunchFixtures.Failure.unreadableTips) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextTips", "free"])
        }
    }

    @Test("The given tips answer as the store would")
    func givenTips() async throws {
        let offers = try await GivenTips(given: .offers).offers()
        #expect(offers.map(\.size) == TipSize.allCases)
        #expect(GivenTips(given: .offers).canPay)
        #expect(!GivenTips(given: .notAllowed).canPay)
        #expect(try await GivenTips(given: .noOffers).offers().isEmpty)
        await #expect(throws: TipFailure.unreachable) { try await GivenTips(given: .unreachable).offers() }
        await #expect(throws: TipFailure.failed) { try await GivenTips(given: .failed).offers() }
    }

    @Test("The given tips buy as the store would, and the answers about a purchase show the three offers")
    func givenPurchases() async throws {
        #expect(try await GivenTips(given: .offers).purchase(.small) == .completed)
        #expect(try await GivenTips(given: .cancelled).purchase(.medium) == .cancelled)
        #expect(try await GivenTips(given: .pending).purchase(.large) == .pending)
        await #expect(throws: TipFailure.failed) { try await GivenTips(given: .purchaseFailed).purchase(.small) }
        await #expect(throws: TipFailure.notAllowed) { try await GivenTips(given: .notAllowed).purchase(.small) }
        await #expect(throws: TipFailure.unreachable) { try await GivenTips(given: .unreachable).purchase(.small) }
        for answer in [LaunchFixtures.TipsAnswer.cancelled, .pending, .purchaseFailed] {
            #expect(try await GivenTips(given: answer).offers().map(\.size) == TipSize.allCases)
            #expect(GivenTips(given: answer).canPay)
        }
    }

    @Test("An unknown fixture argument is ignored and named in the unknown list")
    func unknownArgument() throws {
        let fixtures = try LaunchFixtures.parse([
            Self.program, "-PrestoCVNextTeleport", "-PrestoCVNextStorage", "a", "-AppleLanguages", "(en)",
        ])
        #expect(fixtures.unknownArguments == ["-PrestoCVNextTeleport"])
        #expect(fixtures.storage == .named("a"))
    }

    @Test("Two ways to choose the storage conflict")
    func conflictingStorage() {
        #expect(throws: LaunchFixtures.Failure.conflictingStorage) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextStorage", "a"])
        }
    }

    @Test("An argument that needs a value and ends the list fails with its name")
    func missingValue() {
        #expect(throws: LaunchFixtures.Failure.missingValue(argument: "-PrestoCVNextStorage")) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextStorage"])
        }
    }

    @Test("A folder name that could leave the folder is refused", arguments: ["", "..", "a/b", "a b", "../x"])
    func invalidName(_ name: String) {
        #expect(throws: LaunchFixtures.Failure.invalidFolderName) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextStorage", name])
        }
    }

    @Test("A seed that is not base 64 JSON, or names a file outside the CV files, is refused")
    func unreadableSeed() throws {
        #expect(throws: LaunchFixtures.Failure.unreadableSeed) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", "not base 64"])
        }
        #expect(throws: LaunchFixtures.Failure.unreadableSeed) {
            try LaunchFixtures.parse([
                Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", Self.seed(["../escape.cv.json": "{}"]),
            ])
        }
        #expect(throws: LaunchFixtures.Failure.unreadableSeed) {
            try LaunchFixtures.parse([
                Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", Self.seed(["notes.txt": "x"]),
            ])
        }
    }

    @Test("A seed needs a folder of its own: it never goes into the device storage")
    func seedWithoutFolder() throws {
        #expect(throws: LaunchFixtures.Failure.seedWithoutFolder) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextSeed", Self.seed(["a.cv.json": "{}"])])
        }
    }

    @Test("The legacy seed maps the released app's file names to content, and needs a folder of the fixture")
    func legacySeed() throws {
        let files = ["cv_0F6E2B7A-3C59-4D8E-A1B2-7C4D5E6F8091.json": "{}"]
        let fixtures = try LaunchFixtures.parse([
            Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextLegacySeed", Self.seed(files),
        ])
        #expect(fixtures.legacySeed == files)
        #expect(throws: LaunchFixtures.Failure.legacySeedWithoutFolder) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextLegacySeed", Self.seed(files)])
        }
        for refused in [try Self.seed(["a.cv.json": "{}"]), try Self.seed(["cv_../x.json": "{}"]), "not base 64"] {
            #expect(throws: LaunchFixtures.Failure.unreadableLegacySeed) {
                try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextLegacySeed", refused])
            }
        }
    }

    @Test("The argument without examples is read, with a folder of its own")
    func withoutSamples() throws {
        let fixtures = try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextNoSamples"])
        #expect(fixtures.withoutSamples)
    }

    @Test("The examples are taken away only with a folder of the fixture: never on the device storage")
    func samplesWithoutFolder() {
        #expect(throws: LaunchFixtures.Failure.samplesWithoutFolder) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextNoSamples"])
        }
    }

    @Test("The argument that fails the renames two at a time is read, with a folder of its own")
    func failsRenamesInPairs() throws {
        let fixtures = try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextFailRenamesInPairs"])
        #expect(fixtures.failsRenamesInPairs)
        #expect(!(try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage"])).failsRenamesInPairs)
    }

    @Test("The failing renames need a folder of the fixture: never on the device storage")
    func failuresWithoutFolder() {
        #expect(throws: LaunchFixtures.Failure.failuresWithoutFolder) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextFailRenamesInPairs"])
        }
    }

    @Test("The argument that opens a stand-in of the share sheet is read, and needs no folder: it writes nothing")
    func sharesWithStandIn() throws {
        let fixtures = try LaunchFixtures.parse([Self.program, "-PrestoCVNextShareStandIn"])
        #expect(fixtures.sharesWithStandIn)
        #expect(fixtures.storage == .device)
        #expect(fixtures.unknownArguments.isEmpty)
        #expect(!(try LaunchFixtures.parse([Self.program])).sharesWithStandIn)
    }

    @Test("What the other window does to the open CV is read, with a folder of its own", arguments: LaunchFixtures.OtherWindow.allCases)
    func otherWindow(_ change: LaunchFixtures.OtherWindow) throws {
        let fixtures = try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextOtherWindow", change.rawValue])
        #expect(fixtures.otherWindow == change)
        #expect(try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage"]).otherWindow == nil)
    }

    @Test("A change of the other window that is none, or is missing, is a failure of the launch")
    func unreadableOtherWindow() {
        #expect(throws: LaunchFixtures.Failure.unreadableOtherWindow) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextOtherWindow", "elsewhere"])
        }
        #expect(throws: LaunchFixtures.Failure.missingValue(argument: "-PrestoCVNextOtherWindow")) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextOtherWindow"])
        }
    }

    @Test("The other window changes a CV only in a folder of the fixture: never on the device storage")
    func otherWindowWithoutFolder() {
        #expect(throws: LaunchFixtures.Failure.otherWindowWithoutFolder) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextOtherWindow", "conflict"])
        }
    }

    @Test("The PDF a window is handed as if another app opened it is read, and needs no folder: it writes nothing", arguments: LaunchFixtures.OpenedFile.allCases)
    func openedFile(_ file: LaunchFixtures.OpenedFile) throws {
        let fixtures = try LaunchFixtures.parse([Self.program, "-PrestoCVNextOpenedFile", file.rawValue])
        let resources = URL(filePath: "/bundle/Resources", directoryHint: .isDirectory)

        #expect(fixtures.openedFile == file)
        #expect(fixtures.storage == .device)
        #expect(fixtures.unknownArguments.isEmpty)
        #expect(fixtures.openedFileFixture(in: resources)?.file == resources.appendingPathComponent("\(file.rawValue).pdf"))
        let plain = try LaunchFixtures.parse([Self.program])
        #expect(plain.openedFile == nil)
        #expect(plain.openedFileFixture(in: resources) == nil)
    }

    @Test("A PDF to open that is not in the corpus, or is missing, is a failure of the launch")
    func unreadableOpenedFile() {
        #expect(throws: LaunchFixtures.Failure.unreadableOpenedFile) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextOpenedFile", "../secret"])
        }
        #expect(throws: LaunchFixtures.Failure.missingValue(argument: "-PrestoCVNextOpenedFile")) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextOpenedFile"])
        }
    }

    @Test("The trace runs argument is read, and it needs a folder of the fixture: never the device's own")
    func traceRuns() throws {
        #expect(try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextTraceRuns"]).storesTraceRuns)
        #expect(!(try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage"]).storesTraceRuns))
        #expect(throws: LaunchFixtures.Failure.traceRunsWithoutFolder) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextTraceRuns"])
        }
    }

    @Test("The invented runs are stored in the trace folder of the fixture, one file or more for each of the two")
    func inventedRuns() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("TraceRuns-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        var fixtures = LaunchFixtures()
        fixtures.storage = .named("unused")
        fixtures.storesTraceRuns = true
        let paths = AppPaths(root: base.appendingPathComponent("Root", isDirectory: true), temporary: base.appendingPathComponent("Temp", isDirectory: true))

        await fixtures.seedTrace(into: paths)

        let files = try FileManager.default.contentsOfDirectory(atPath: paths.trace.path)
        #expect(files.count >= 2, "The files of two runs: \(files)")
    }

    @Test("Without the argument, or on the device storage, nothing is stored")
    func noInventedRuns() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("TraceRuns-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let paths = AppPaths(root: base.appendingPathComponent("Root", isDirectory: true), temporary: base.appendingPathComponent("Temp", isDirectory: true))
        var withoutArgument = LaunchFixtures()
        withoutArgument.storage = .named("unused")
        var onDevice = LaunchFixtures()
        onDevice.storesTraceRuns = true

        await withoutArgument.seedTrace(into: paths)
        await onDevice.seedTrace(into: paths)

        #expect(!FileManager.default.fileExists(atPath: paths.trace.path))
    }

    // MARK: Where the fixtures put the files

    private static let device = AppPaths(
        root: URL(filePath: "/support/PrestoCVNext", directoryHint: .isDirectory),
        temporary: URL(filePath: "/tmp/t", directoryHint: .isDirectory)
    )
    private static let fresh = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()

    @Test("The device storage keeps the paths of the device")
    func deviceStorage() {
        #expect(LaunchFixtures().paths(device: Self.device, fresh: Self.fresh) == Self.device)
    }

    @Test("A named storage is a folder of that name under the temporary folder, the same on every launch")
    func namedPaths() {
        var fixtures = LaunchFixtures()
        fixtures.storage = .named("relaunch-1")
        let paths = fixtures.paths(device: Self.device, fresh: UUID())
        #expect(paths.root.path == "/tmp/t/PrestoCVNextFixture-relaunch-1")
        #expect(paths.temporary == Self.device.temporary)
    }

    @Test("The empty storage is a new folder of its own on each launch")
    func emptyPaths() {
        var fixtures = LaunchFixtures()
        fixtures.storage = .empty
        #expect(fixtures.paths(device: Self.device, fresh: Self.fresh).root.path
            == "/tmp/t/PrestoCVNextFixture-00000000-0000-0000-0000-000000000001")
    }

    @Test("The examples come from the bundle, or without examples from a folder of the fixture that nothing makes")
    func samplesFolder() throws {
        let bundled = URL(filePath: "/app/Samples", directoryHint: .isDirectory)
        var fixtures = LaunchFixtures()
        fixtures.storage = .named("no-samples")
        let paths = fixtures.paths(device: Self.device, fresh: Self.fresh)
        #expect(fixtures.samples(bundled: bundled, paths: paths) == bundled)

        fixtures.withoutSamples = true

        #expect(fixtures.samples(bundled: bundled, paths: paths).path == "/tmp/t/PrestoCVNextFixture-no-samples/Samples")
    }

    @Test("The legacy store is the device's, or for a fixture folder one in it, so a fixture never reads the released app's")
    func legacyStoreFolder() {
        let device = URL(filePath: "/support/PrestoCV/CVs", directoryHint: .isDirectory)
        var fixtures = LaunchFixtures()
        #expect(fixtures.legacyStore(device: device, paths: Self.device) == device)

        fixtures.storage = .named("legacy")
        let paths = fixtures.paths(device: Self.device, fresh: Self.fresh)

        #expect(fixtures.legacyStore(device: device, paths: paths).path == "/tmp/t/PrestoCVNextFixture-legacy/Legacy")
    }

    @Test("The leftovers to remove are the device's, or for a fixture folder ones in it, so a fixture never removes the released app's")
    func legacyLeftoversFolder() {
        let device = LegacyLeftoverPaths(applicationSupport: URL(filePath: "/support", directoryHint: .isDirectory))
        var fixtures = LaunchFixtures()
        #expect(fixtures.legacyLeftovers(device: device, paths: Self.device) == device)

        fixtures.storage = .named("legacy")
        let paths = fixtures.paths(device: Self.device, fresh: Self.fresh)
        let leftovers = fixtures.legacyLeftovers(device: device, paths: paths)

        let base = "/tmp/t/PrestoCVNextFixture-legacy/LegacySupport"
        #expect(leftovers.templates.path == base + "/PrestoCV/Templates")
        #expect(leftovers.templateCache.path == base + "/TemplateCache")
        #expect(leftovers.exportPreferences.path == base + "/PrestoCV/export-preferences.json")
    }

    @Test("The seed is written as files in the store folder, which it makes")
    func writesTheSeed() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("Seed-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        var fixtures = LaunchFixtures()
        fixtures.seed = ["a.cv.json": "first", "b.cv.json": "second"]

        try fixtures.writeSeed(into: base.appendingPathComponent("Store", isDirectory: true))

        #expect(try String(contentsOf: base.appendingPathComponent("Store/a.cv.json"), encoding: .utf8) == "first")
        #expect(try String(contentsOf: base.appendingPathComponent("Store/b.cv.json"), encoding: .utf8) == "second")
    }

    @Test("A seed that cannot be written fails with a typed error")
    func seedUnwritable() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("Seed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("file")
        try Data("x".utf8).write(to: file)
        var fixtures = LaunchFixtures()
        fixtures.seed = ["a.cv.json": "x"]

        #expect(throws: LaunchFixtures.Failure.seedUnwritable) {
            try fixtures.writeSeed(into: file.appendingPathComponent("Store", isDirectory: true))
        }
    }

    // MARK: A fixture folder that is a link

    private static func unique() -> String { "Linked-\(UUID().uuidString)" }

    private static func target() throws -> URL {
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("LinkTarget-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        return target
    }

    private static func entries(_ folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path)
    }

    private static func arguments(storage name: String) throws -> [String] {
        [program, "-PrestoCVNextStorage", name, "-PrestoCVNextSeed", try seed(["planted.cv.json": "{}"])]
    }

    @MainActor
    @Test("A fixture folder that is a link to another folder fails the launch, and nothing is written there", .printsForReal)
    func linkedRoot() async throws {
        let target = try Self.target()
        let name = Self.unique()
        let link = FileManager.default.temporaryDirectory.appendingPathComponent("PrestoCVNextFixture-\(name)")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        defer {
            try? FileManager.default.removeItem(at: link)
            try? FileManager.default.removeItem(at: target)
        }

        let state = await Composition.launch(
            arguments: try Self.arguments(storage: name), settlement: TraceSettlement(), backgroundTime: NoBackgroundTime()
        )

        guard case .failed(.launchFixturesRejected) = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(try Self.entries(target).isEmpty, "Nothing was made or written through the link")
    }

    @MainActor
    @Test("A store folder inside the fixture folder that is a link fails the launch, and nothing is written there", .printsForReal)
    func linkedStore() async throws {
        let target = try Self.target()
        let name = Self.unique()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PrestoCVNextFixture-\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Store"), withDestinationURL: target)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: target)
        }

        let state = await Composition.launch(
            arguments: try Self.arguments(storage: name), settlement: TraceSettlement(), backgroundTime: NoBackgroundTime()
        )

        guard case .failed(.launchFixturesRejected) = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(try Self.entries(target).isEmpty, "Nothing was written through the link")
    }

    @MainActor
    @Test("A design or legacy folder inside the fixture folder that is a link fails the launch, and nothing is written there", .printsForReal, arguments: ["Designs", "Legacy"])
    func linkedFolder(_ folder: String) async throws {
        let target = try Self.target()
        let name = Self.unique()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PrestoCVNextFixture-\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent(folder), withDestinationURL: target)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: target)
        }

        let state = await Composition.launch(
            arguments: try Self.arguments(storage: name), settlement: TraceSettlement(), backgroundTime: NoBackgroundTime()
        )

        guard case .failed(.launchFixturesRejected) = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(try Self.entries(target).isEmpty, "Nothing was written through the link")
    }

    /// Apple only, like the other composition tests: the launch fixtures are compiled in Debug builds of the app.
    @MainActor
    @Test("The released app's folder inside the fixture's Application Support that is a link fails the launch, and nothing is removed there", .printsForReal)
    func linkedLegacyAppFolder() async throws {
        let target = try Self.target()
        try Data("mine".utf8).write(to: target.appendingPathComponent("export-preferences.json"))
        let name = Self.unique()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PrestoCVNextFixture-\(name)", isDirectory: true)
        let support = root.appendingPathComponent("LegacySupport", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: support.appendingPathComponent("PrestoCV"), withDestinationURL: target)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: target)
        }

        let state = await Composition.launch(
            arguments: try Self.arguments(storage: name), settlement: TraceSettlement(), backgroundTime: NoBackgroundTime()
        )

        guard case .failed(.launchFixturesRejected) = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(try Self.entries(target) == ["export-preferences.json"], "Nothing was removed through the link")
    }

    @MainActor
    @Test("A fixture folder that is a link, on a launch that may not record, leaves the traces of the folder it leads to alone", .printsForReal)
    func linkedRootOnAClosedLaunch() async throws {
        let target = try Self.target()
        let traces = target.appendingPathComponent("Diagnostics", isDirectory: true)
        try FileManager.default.createDirectory(at: traces, withIntermediateDirectories: true)
        let marker = traces.appendingPathComponent("marker")
        try Data("kept".utf8).write(to: marker)
        let name = Self.unique()
        let link = FileManager.default.temporaryDirectory.appendingPathComponent("PrestoCVNextFixture-\(name)")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        defer {
            try? FileManager.default.removeItem(at: link)
            try? FileManager.default.removeItem(at: target)
        }

        let state = await Composition.launch(
            arguments: [Self.program, "-PrestoCVNextStorage", name, "-PrestoCVNextDistribution", "production"],
            settlement: TraceSettlement(), backgroundTime: NoBackgroundTime()
        )

        guard case .failed(.launchFixturesRejected) = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: marker.path), "No trace is purged through a folder the check refused")
    }

    @MainActor
    @Test("The invented runs of a launch with an open gate are listed, and a closed gate has purged them once the launch is ready", .printsForReal, arguments: [("sandbox", 2), ("production", 0)])
    func inventedRunsAndTheGate(answer: String, listed: Int) async throws {
        let name = Self.unique()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PrestoCVNextFixture-\(name)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let state = await Composition.launch(
            arguments: [Self.program, "-PrestoCVNextStorage", name, "-PrestoCVNextTraceRuns", "-PrestoCVNextDistribution", answer],
            settlement: TraceSettlement(), backgroundTime: NoBackgroundTime()
        )

        guard case .ready(let composition) = state else {
            Issue.record("expected ready, got \(state)")
            return
        }
        #expect(await composition.traceAccess.reader.runs().count == listed, "Read before anything waits for the trace")
    }

    @MainActor
    @Test("A fixture folder that is a plain folder still launches with its seed", .printsForReal)
    func plainFolderLaunches() async throws {
        let name = Self.unique()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PrestoCVNextFixture-\(name)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let state = await Composition.launch(
            arguments: try Self.arguments(storage: name), settlement: TraceSettlement(), backgroundTime: NoBackgroundTime()
        )

        guard case .ready(let composition) = state else {
            Issue.record("expected ready, got \(state)")
            return
        }
        let store = try Self.entries(root.appendingPathComponent("Store")).filter { $0 != ".lock" }
        #expect(store == ["planted.cv.json"], "The seed, beside the lock the import of the legacy store takes")
        #expect(composition.legacyImport == .ran(LegacyImportReport()), "The fixture folder has no legacy store: a run with nothing")
        #expect(!composition.sharesWithStandIn, "Only the argument opens the stand-in of the share sheet")
        #expect(composition.openedFile == nil, "Only the argument hands a window a PDF")
    }

    @MainActor
    @Test(
        "A launch with a legacy seed imports it from the fixture's legacy folder, and a launch without it writes none",
        .printsForReal
    )
    func legacySeedLaunches() async throws {
        let name = Self.unique()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PrestoCVNextFixture-\(name)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let id = "0F6E2B7A-3C59-4D8E-A1B2-7C4D5E6F8091"
        let file = #"{"id":"\#(id)","updatedAt":"2026-10-02T00:00:00Z","look":{"palette":"ocean"}}"#
        let seeded = [Self.program, "-PrestoCVNextStorage", name]

        let first = await Composition.launch(
            arguments: seeded + ["-PrestoCVNextLegacySeed", try Self.seed(["cv_\(id).json": file])],
            settlement: TraceSettlement(), backgroundTime: NoBackgroundTime()
        )
        try FileManager.default.removeItem(at: root.appendingPathComponent("Legacy/cv_\(id).json"))
        let again = await Composition.launch(arguments: seeded, settlement: TraceSettlement(), backgroundTime: NoBackgroundTime())

        guard case .ready(let composition) = first, case .ran(let report) = composition.legacyImport else {
            Issue.record("expected an import that ran, got \(first)")
            return
        }
        #expect(Array(report.drops.values) == [[.look]], "The released app's file was read, with its loss")
        #expect(try Self.entries(root.appendingPathComponent("Legacy")).isEmpty, "A launch without the seed writes it no more")
        guard case .ready = again else {
            Issue.record("expected ready, got \(again)")
            return
        }
    }

    @MainActor
    @Test("A launch with the argument of the stand-in gives a composition whose shares open the stand-in", .printsForReal)
    func launchSharesWithStandIn() async throws {
        let name = Self.unique()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PrestoCVNextFixture-\(name)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let state = await Composition.launch(
            arguments: try Self.arguments(storage: name) + ["-PrestoCVNextShareStandIn"], settlement: TraceSettlement(),
            backgroundTime: NoBackgroundTime()
        )

        guard case .ready(let composition) = state else {
            Issue.record("expected ready, got \(state)")
            return
        }
        #expect(composition.sharesWithStandIn)
    }

    @MainActor
    @Test("A launch with the argument of the PDF to open gives a composition that hands a window that PDF of the bundle", .printsForReal)
    func launchHandsAnOpenedFile() async throws {
        let name = Self.unique()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PrestoCVNextFixture-\(name)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let state = await Composition.launch(
            arguments: try Self.arguments(storage: name) + ["-PrestoCVNextOpenedFile", "linkedin"], settlement: TraceSettlement(),
            backgroundTime: NoBackgroundTime()
        )

        guard case .ready(let composition) = state else {
            Issue.record("expected ready, got \(state)")
            return
        }
        let resources = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        #expect(composition.openedFile?.file == resources.appendingPathComponent("linkedin.pdf"))
    }
}
#endif

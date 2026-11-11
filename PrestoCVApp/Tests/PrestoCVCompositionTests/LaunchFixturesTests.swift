#if DEBUG
import DiagnosticTrace
import Foundation
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
    @Test("A design folder inside the fixture folder that is a link fails the launch, and nothing is written there", .printsForReal)
    func linkedDesigns() async throws {
        let target = try Self.target()
        let name = Self.unique()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PrestoCVNextFixture-\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Designs"), withDestinationURL: target)
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
        #expect(try Self.entries(root.appendingPathComponent("Store")) == ["planted.cv.json"])
        #expect(!composition.sharesWithStandIn, "Only the argument opens the stand-in of the share sheet")
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
}
#endif

import Foundation
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVIntegration
import PrestoCVPersistence
import PrestoCVPresentation
import PrestoCVWorkflowPorts
import Testing
@testable import PrestoCVComposition

/// A legacy store that holds nothing, as on a device the released app never wrote to.
struct EmptyLegacyStore: LegacyStore {
    func records() async throws(RepositoryError) -> [LegacyRecord] { [] }
    func remove(_ key: LegacyRecord.Key, ifUnchanged version: LegacyRecord.Version) async throws(RepositoryError) -> LegacyRemoval {
        .alreadyGone
    }
}

/// A legacy store that cannot be listed, as when its folder cannot be read.
struct UnlistableLegacyStore: LegacyStore {
    func records() async throws(RepositoryError) -> [LegacyRecord] { throw .storeUnavailable(.cannotList) }
    func remove(_ key: LegacyRecord.Key, ifUnchanged version: LegacyRecord.Version) async throws(RepositoryError) -> LegacyRemoval {
        .alreadyGone
    }
}

extension LegacyImportAtLaunch {
    /// A launch with no released app's store: nothing imported, nothing to report.
    static let nothing = LegacyImportAtLaunch(
        outcome: .ran(LegacyImportReport()),
        review: LegacyImportReview(
            outcome: .ran(LegacyImportReport()), importer: ImportLegacyStore(source: EmptyLegacyStore(), target: InMemoryCVRepository())
        ),
        reminder: LegacyReportMarker(file: FileManager.default.temporaryDirectory.appendingPathComponent("NoLegacyReportOff-\(UUID())"))
    )
}

/// The import of the released app's store through the composition: real legacy files in a temporary folder, read by the
/// real legacy store, into the composition's own repository.
@MainActor
@Suite("The legacy store at launch")
struct LegacyImportAtLaunchTests {
    static let good = "AAAAAAAA-0000-4000-8000-000000000001"
    static let dropped = "BBBBBBBB-0000-4000-8000-000000000002"
    static let broken = "CCCCCCCC-0000-4000-8000-000000000003"

    /// A legacy file of 1.0.1: the required members, then `fields`.
    static func legacyFile(_ id: String, _ fields: String = "") -> String {
        #"{"id":"\#(id)","updatedAt":"2026-10-02T00:00:00Z","createdAt":"2026-10-01T00:00:00Z"\#(fields.isEmpty ? "" : "," + fields)}"#
    }

    /// Writes the files, by id, into a legacy folder beside the app's root.
    static func legacyFolder(_ paths: AppPaths, _ files: [String: String]) throws -> URL {
        let folder = paths.temporary.appendingPathComponent("Legacy", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (id, text) in files { try Data(text.utf8).write(to: folder.appendingPathComponent("cv_\(id).json")) }
        return folder
    }

    static func files(_ folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
    }

    static func launch(_ paths: AppPaths, from legacy: any LegacyStore) async throws -> Composition {
        let rules = CompositionTests.counting(CompositionTests.CompileCounter())
        return try CompositionTests.ready(await Composition.make(CompositionTests.inputs(paths, compileRules: rules, legacyStore: legacy)))
    }

    static func report(_ composition: Composition) -> LegacyImportReportViewModel {
        composition.screens.makeLegacyImportReport(untitled: "Untitled", numbered: { title, number in "\(title) (\(number))" })
    }

    static func stored(_ composition: Composition) async throws -> [String] {
        try await composition.repository.list().cvs.map(\.id.raw.uuidString).sorted()
    }

    @Test("The legacy CVs are stored before the first-run decision, which then skips the welcome")
    func importsBeforeTheFirstRunDecision() async throws {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let folder = try Self.legacyFolder(paths, [
            Self.good: Self.legacyFile(Self.good), Self.dropped: Self.legacyFile(Self.dropped, #""look":{"palette":"ocean"}"#),
        ])

        let composition = try await Self.launch(paths, from: DirectoryLegacyStore(directory: folder, clock: SteppingClock()))
        let screens = composition.screens
        let firstRun = screens.makeFirstRun()
        await firstRun.load()
        let shell = screens.makeShell(
            list: screens.makeCVList(untitled: "Untitled", numbered: { title, number in "\(title) (\(number))" }),
            firstRun: firstRun, copyTitle: { "Copy of \($0)" }, fileNamePattern: { _ in "CV %@" }
        )

        #expect(try await Self.stored(composition) == [Self.good, Self.dropped])
        #expect(firstRun.state == .returning)
        #expect(shell.screen(for: firstRun.state) == .split)
        #expect(try Self.files(folder) == ["cv_\(Self.dropped).json"], "the CV with a loss keeps its file until it is acknowledged")
    }

    @Test("A launch that cannot list the legacy store opens with the failure, keeps the files, and the next launch imports")
    func aFailedImportIsShownAndRetried() async throws {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let folder = try Self.legacyFolder(paths, [Self.good: Self.legacyFile(Self.good)])

        let failed = try await Self.launch(paths, from: UnlistableLegacyStore())
        let firstRun = failed.screens.makeFirstRun()
        await firstRun.load()
        let report = Self.report(failed)
        await report.load()
        #expect(firstRun.state == .returning, "never the welcome of an empty app, as if the old CVs were gone")
        #expect(report.notice == .didNotRun)
        #expect(failed.legacyImport == .failed(.storeUnavailable(.cannotList)))
        #expect(failed.legacyImport.imported == 0)
        #expect(failed.legacyImport.failed == nil, "how many failed is not known, so never zero, as if there were nothing")
        #expect(try Self.files(folder) == ["cv_\(Self.good).json"])

        let next = try await Self.launch(paths, from: DirectoryLegacyStore(directory: folder, clock: SteppingClock()))
        #expect(next.legacyImport.imported == 1)
        #expect(next.legacyImport.failed == 0)
        #expect(try await Self.stored(next) == [Self.good])
    }

    @Test("A partial import counts the CVs stored and the CVs left out, whose files stay, and skips the welcome")
    func aPartialImportCountsBoth() async throws {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let folder = try Self.legacyFolder(paths, [Self.good: Self.legacyFile(Self.good), Self.broken: "{"])

        let composition = try await Self.launch(paths, from: DirectoryLegacyStore(directory: folder, clock: SteppingClock()))
        let firstRun = composition.screens.makeFirstRun()
        await firstRun.load()

        #expect(composition.legacyImport.imported == 1)
        #expect(composition.legacyImport.failed == 1)
        #expect(try Self.files(folder) == ["cv_\(Self.broken).json"])
        #expect(firstRun.state == .returning)
    }

    @Test("The report lists the CV that lost a detail, and Confirm removes its old copy")
    func theReportConfirms() async throws {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let folder = try Self.legacyFolder(paths, [
            Self.good: Self.legacyFile(Self.good), Self.dropped: Self.legacyFile(Self.dropped, #""look":{"palette":"ocean"}"#),
        ])
        let composition = try await Self.launch(paths, from: DirectoryLegacyStore(directory: folder, clock: SteppingClock()))
        let report = Self.report(composition)

        await report.load()
        #expect(report.leftOut.map(\.details) == [[.look]] && report.toCheck.isEmpty)
        #expect(report.state == .review && report.notice == nil)
        await report.confirm()

        #expect(report.state == .removed)
        #expect(try Self.files(folder).isEmpty)
    }

    @Test("After the choice not to be reminded, kept in the app's folder, the report keeps its rows but shows no sheet")
    func theChoiceIsKept() async throws {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let folder = try Self.legacyFolder(paths, [Self.dropped: Self.legacyFile(Self.dropped, #""look":{"palette":"ocean"}"#)])
        let composition = try await Self.launch(paths, from: DirectoryLegacyStore(directory: folder, clock: SteppingClock()))
        let marker = LegacyReportMarker(file: paths.legacyReportOff)
        #expect(await marker.remindsAgain())

        try await marker.stopReminding()
        let report = Self.report(composition)
        await report.load()

        #expect(await !marker.remindsAgain())
        #expect(report.leftOut.count == 1 && report.state == .hidden)
        #expect(try Self.files(folder) == ["cv_\(Self.dropped).json"])
        await #expect(throws: LegacyReminderFailure.notKept) {
            try await LegacyReportMarker(file: folder.appendingPathComponent("missing/LegacyReportOff")).stopReminding()
        }
    }
}

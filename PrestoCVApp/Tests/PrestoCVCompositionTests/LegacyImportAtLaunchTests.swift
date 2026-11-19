import Foundation
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVPersistence
import PrestoCVPresentation
import Testing
@testable import PrestoCVComposition

/// A legacy store that holds nothing, as on a device the released app never wrote to.
struct EmptyLegacyStore: LegacyStore {
    func records() async throws(RepositoryError) -> [LegacyRecord] { [] }
    func remove(_ key: LegacyRecord.Key, ifUnchanged version: LegacyRecord.Version) async throws(RepositoryError) -> LegacyRemoval {
        .alreadyGone
    }
}

/// The import of the released app's store through the composition: real legacy files in a temporary folder, read by the
/// real legacy store, into the composition's own repository.
@MainActor
@Suite("The legacy store at launch")
struct LegacyImportAtLaunchTests {
    static let good = "AAAAAAAA-0000-4000-8000-000000000001"
    static let dropped = "BBBBBBBB-0000-4000-8000-000000000002"

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
}

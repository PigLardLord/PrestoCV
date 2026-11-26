import DiagnosticLogging
import Foundation
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVLegacyLeftovers
import PrestoCVPersistence
import PrestoCVWorkflowPorts
import Synchronization
import Testing
@testable import PrestoCVComposition

/// A launch that removes nothing, for the tests that do not look at the leftovers.
struct NoLeftovers: LegacyLeftoversCleaning {
    func clean() async {}
}

/// A cleaner that counts its runs.
final class CountingLeftovers: LegacyLeftoversCleaning {
    private let runs = Mutex(0)
    var count: Int { runs.withLock { $0 } }
    func clean() async { runs.withLock { $0 += 1 } }
}

/// The removal of what the released app left, at the launch: it follows an import that ran with nothing left out.
@MainActor
@Suite("The released app's leftovers at launch")
struct LegacyLeftoversAtLaunchTests {
    static let good = LegacyImportAtLaunchTests.good
    static let broken = LegacyImportAtLaunchTests.broken

    private static func launch(_ paths: AppPaths, from legacy: any LegacyStore, cleaner: CountingLeftovers) async throws -> Composition {
        let rules = CompositionTests.counting(CompositionTests.CompileCounter())
        return try CompositionTests.ready(await Composition.make(
            CompositionTests.inputs(paths, compileRules: rules, legacyStore: legacy, legacyLeftovers: { _ in cleaner })
        ))
    }

    @Test("It runs after an import that ran with nothing left out, with the store empty or not")
    func runsAfterACleanImport() async throws {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let folder = try LegacyImportAtLaunchTests.legacyFolder(paths, [Self.good: LegacyImportAtLaunchTests.legacyFile(Self.good)])
        let cleaner = CountingLeftovers()

        _ = try await Self.launch(paths, from: DirectoryLegacyStore(directory: folder, clock: SteppingClock()), cleaner: cleaner)
        #expect(cleaner.count == 1)

        _ = try await Self.launch(paths, from: EmptyLegacyStore(), cleaner: cleaner)
        #expect(cleaner.count == 2, "with nothing to import, as on a device the released app never wrote to")
    }

    @Test("It does not run after an import that could not list the legacy store")
    func notAfterAFailedImport() async throws {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let cleaner = CountingLeftovers()

        let composition = try await Self.launch(paths, from: UnlistableLegacyStore(), cleaner: cleaner)

        #expect(composition.legacyImport == .failed(.storeUnavailable(.cannotList)))
        #expect(cleaner.count == 0)
    }

    @Test("It does not run after an import with a damaged file left out, and runs once the launch has none")
    func notWithAFailure() async throws {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let folder = try LegacyImportAtLaunchTests.legacyFolder(paths, [
            Self.good: LegacyImportAtLaunchTests.legacyFile(Self.good), Self.broken: "{ not json",
        ])
        let cleaner = CountingLeftovers()

        let composition = try await Self.launch(
            paths, from: DirectoryLegacyStore(directory: folder, clock: SteppingClock()), cleaner: cleaner
        )

        #expect(composition.legacyImport.failed == 1)
        #expect(cleaner.count == 0)
    }

    @Test("It does not run after an import that found the store erased")
    func notAfterAnErasedStore() async {
        var erased = LegacyImportReport()
        erased.storeErased = true
        let cleaner = CountingLeftovers()

        await Composition.cleanLeftovers(after: .ran(erased), with: cleaner)
        #expect(cleaner.count == 0)

        await Composition.cleanLeftovers(after: .ran(LegacyImportReport()), with: cleaner)
        #expect(cleaner.count == 1)
    }

    @Test("The real cleanup removes the three leftovers under the paths it is given, and leaves the legacy CVs and edits")
    func removesOnlyTheLeftovers() async throws {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let support = paths.temporary.appendingPathComponent("LegacySupport", isDirectory: true)
        let leftovers = LegacyLeftoverPaths(applicationSupport: support)
        for folder in [leftovers.templates, leftovers.templateCache] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data("x".utf8).write(to: folder.appendingPathComponent("file"))
        }
        try Data("{}".utf8).write(to: leftovers.exportPreferences)
        let edits = support.appendingPathComponent("PrestoCV/UnsavedEdits", isDirectory: true)
        try FileManager.default.createDirectory(at: edits, withIntermediateDirectories: true)
        try Data("edit".utf8).write(to: edits.appendingPathComponent("edit.json"))
        let rules = CompositionTests.counting(CompositionTests.CompileCounter())

        _ = try CompositionTests.ready(await Composition.make(CompositionTests.inputs(
            paths, compileRules: rules, legacyLeftovers: { LegacyLeftoversAdapter(paths: leftovers, logger: $0) }
        )))

        for url in [leftovers.templates, leftovers.templateCache, leftovers.exportPreferences] {
            #expect(!FileManager.default.fileExists(atPath: url.path), "\(url.lastPathComponent) goes")
        }
        #expect(FileManager.default.fileExists(atPath: edits.appendingPathComponent("edit.json").path))
    }
}

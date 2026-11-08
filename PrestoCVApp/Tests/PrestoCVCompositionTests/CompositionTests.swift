import CVRenderingWebKitSupport
import DiagnosticLogging
import DiagnosticLoggingTestSupport
import DiagnosticTrace
import DiagnosticTraceTestSupport
import Foundation
import PrestoCVApplication
import PrestoCVCoreTestSupport
import Testing
import WebKit
@testable import PrestoCVComposition

/// The composition over a temporary folder: fake clock, ids and logger, the real repository and the real rule compiler
/// behind a counting seam.
@MainActor
@Suite("The composition")
struct CompositionTests {
    /// Counts the compiles the composition asks for
    @MainActor
    final class CompileCounter {
        private(set) var calls = 0

        func compile() async throws(SecureWebViewConfiguration.Failure) -> WKContentRuleList {
            calls += 1
            return try await SecureWebViewConfiguration.compileRules()
        }
    }

    private static func counting(_ counter: CompileCounter) -> Composition.CompileRules {
        { @MainActor () async throws(SecureWebViewConfiguration.Failure) -> WKContentRuleList in try await counter.compile() }
    }

    private static let failing: Composition.CompileRules = {
        @MainActor () async throws(SecureWebViewConfiguration.Failure) -> WKContentRuleList in throw .contentRulesUnavailable
    }

    /// A deadline that never fires: nothing waits for it to end.
    private static let neverFires: @Sendable () async -> Void = {
        for await _ in AsyncStream<Void> { _ in } {}
    }

    private static func paths() -> AppPaths {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("CompositionTests-\(UUID().uuidString)", isDirectory: true)
        return AppPaths(root: base.appendingPathComponent("Root", isDirectory: true), temporary: base)
    }

    private static func inputs(
        _ paths: AppPaths,
        log: any DiagnosticLogger = RecordingLogger(),
        clock: any TimeSource = SteppingClock(),
        ids: any IDGenerator = SequentialIDGenerator(),
        compileRules: @escaping Composition.CompileRules
    ) -> Composition.Inputs {
        Composition.Inputs(
            paths: paths,
            clock: clock,
            ids: ids,
            log: log,
            gate: .asking(FixedDistribution(.production)),
            device: TraceDevice(appVersion: "1.0", build: "1", osVersion: "iOS 26.5", model: "iPhone17,1"),
            settlement: TraceSettlement(),
            samples: paths.root.appendingPathComponent("Samples", isDirectory: true),
            compileRules: compileRules,
            settleDeadline: Self.neverFires,
            check: {},
            prepare: {}
        )
    }

    private static func ready(_ state: CompositionState) throws -> Composition {
        guard case .ready(let composition) = state else {
            throw Failed(state: "\(state)")
        }
        return composition
    }

    struct Failed: Error { let state: String }

    @Test("It builds ready over an empty folder, and the repository it holds reads and writes there")
    func readyOverAnEmptyFolder() async throws {
        let paths = Self.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let counter = CompileCounter()

        let composition = try Self.ready(await Composition.make(Self.inputs(paths, compileRules: Self.counting(counter))))

        #expect(composition.paths == paths)
        #expect(try await composition.repository.list().cvs.isEmpty)
        try await CVRepositoryContract.verify(composition.repository)
        let files = try FileManager.default.contentsOfDirectory(atPath: paths.store.path)
        #expect(files.isEmpty == false, "The CV was written under the store folder")
    }

    @Test("The clock and the ids are the very instances the inputs gave, with the state they had")
    func holdsTheGivenSources() async throws {
        let paths = Self.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let counter = CompileCounter()
        // Sources that already moved, and a reference moved the same way: fresh doubles would start again
        let clock = SteppingClock()
        let ids = SequentialIDGenerator()
        let referenceClock = SteppingClock()
        let referenceIDs = SequentialIDGenerator()
        for _ in 0..<5 {
            _ = clock.now(); _ = referenceClock.now()
            _ = ids.next(); _ = referenceIDs.next()
        }

        let composition = try Self.ready(await Composition.make(
            Self.inputs(paths, clock: clock, ids: ids, compileRules: Self.counting(counter))
        ))

        #expect(composition.ids.next() == referenceIDs.next())
        #expect(composition.clock.now() == referenceClock.now())
        // Both calls moved the supplied instances, not copies of them
        #expect(ids.next() == referenceIDs.next())
        #expect(clock.now() == referenceClock.now())
    }

    @Test("The rules are compiled once per composition, also when the renderer is asked for twice")
    func compilesOnce() async throws {
        let paths = Self.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let counter = CompileCounter()

        let composition = try Self.ready(await Composition.make(Self.inputs(paths, compileRules: Self.counting(counter))))
        _ = composition.makeRenderer()
        _ = composition.makeRenderer()

        #expect(counter.calls == 1)
    }

    @Test("Rules that cannot be compiled give a failed state with a code, and no store folder is left half made")
    func compileFailure() async {
        let paths = Self.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }

        let state = await Composition.make(Self.inputs(paths, compileRules: Self.failing))

        guard case .failed(let failure) = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(failure == .contentRulesUnavailable)
    }

    @Test("A store folder that cannot be made gives a failed state with a code, and the rules are not compiled")
    func storeFailure() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("CompositionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("file")
        try Data("x".utf8).write(to: file)
        let paths = AppPaths(root: file.appendingPathComponent("Root"), temporary: base)
        let counter = CompileCounter()

        let state = await Composition.make(Self.inputs(paths, compileRules: Self.counting(counter)))

        guard case .failed(let failure) = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(failure == .storeUnavailable)
        #expect(counter.calls == 0)
    }

    @Test("The logger the composition holds keeps writing to the log it was given")
    func loggerReachesTheLog() async throws {
        let paths = Self.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let log = RecordingLogger()
        let counter = CompileCounter()

        let composition = try Self.ready(await Composition.make(Self.inputs(paths, log: log, compileRules: Self.counting(counter))))
        composition.logger.info(LogCategory("app"), "composition.probe")

        #expect(log.events.contains("composition.probe"))
    }

    @Test("A closed gate leaves the trace closed and its folder unmade")
    func closedTrace() async throws {
        let paths = Self.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let counter = CompileCounter()

        let composition = try Self.ready(await Composition.make(Self.inputs(paths, compileRules: Self.counting(counter))))

        #expect(await !composition.traceAccess.isOn())
        #expect(!FileManager.default.fileExists(atPath: paths.trace.path))
    }
}

/// The two sources that read the system.
@Suite("The system sources")
struct SystemSourcesTests {
    @Test("Each id is new")
    func ids() {
        let ids = UUIDGenerator()
        #expect(ids.next() != ids.next())
    }
}

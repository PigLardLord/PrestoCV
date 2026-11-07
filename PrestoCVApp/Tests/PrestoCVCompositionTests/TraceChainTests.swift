import DiagnosticLogging
import DiagnosticLoggingTestSupport
import DiagnosticTrace
import DiagnosticTraceTestSupport
import Foundation
import Testing
@testable import PrestoCVComposition

/// The trace of a test build as the composition builds it (ADR 0032): a gate that stays closed writes nothing, a gate that
/// opens keeps each run in the store, and a launch that may not record removes what an earlier install stored.
@Suite("The trace chain of the composition")
struct TraceChainTests {
    private static let device = TraceDevice(appVersion: "1.0", build: "1", osVersion: "iOS 26.5", model: "iPhone17,1")
    private static let marker = "Zwiebelmarker"

    private static func paths() -> AppPaths {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("TraceChainTests-\(UUID().uuidString)", isDirectory: true)
        return AppPaths(root: base.appendingPathComponent("Root", isDirectory: true), temporary: base)
    }

    private static func remove(_ paths: AppPaths) {
        try? FileManager.default.removeItem(at: paths.temporary)
    }

    private static func chain(_ paths: AppPaths, gate: TraceLaunchGate, log: any DiagnosticLogger) -> TraceChain {
        TraceChain(
            directory: paths.trace, shareDirectory: paths.traceShare, gate: gate, device: device, log: log
        )
    }

    private static func closed() -> TraceLaunchGate {
        .asking(FixedDistribution(.production))
    }

    private static func sandbox() -> TraceLaunchGate {
        .asking(FixedDistribution(.sandbox))
    }

    private static func runOneImport(through chain: TraceChain) {
        let run = chain.tracer.begin(.textImport)
        run.record(.input, .text("text", marker))
        run.finish(.finished)
    }

    @Test("With the gate open, a run reaches the store and holds what was recorded")
    func openGateRecords() async throws {
        let paths = Self.paths()
        defer { Self.remove(paths) }
        let chain = Self.chain(paths, gate: Self.sandbox(), log: RecordingLogger())

        #expect(await chain.access.isOn())
        Self.runOneImport(through: chain)

        let runs = await chain.access.reader.runs()
        #expect(runs.map(\.kind) == [.textImport])
        let run = try #require(runs.first)
        #expect(run.outcome == .finished)
        let files = try await chain.access.reader.shareCopies(of: run.id)
        let document = try #require(files.first { $0.pathExtension == "json" })
        #expect(try String(contentsOf: document, encoding: .utf8).contains(Self.marker))
        await chain.access.reader.discardCopies()
    }

    @Test("A log entry of the import goes to the log and to the open run")
    func logEntriesReachTheRun() async throws {
        let paths = Self.paths()
        defer { Self.remove(paths) }
        let log = RecordingLogger()
        let chain = Self.chain(paths, gate: Self.sandbox(), log: log)
        #expect(await chain.access.isOn())

        let run = chain.tracer.begin(.textImport)
        await run.within { chain.logger.info(LogCategory("import"), "import.finished") }
        run.finish(.finished)

        #expect(log.events.contains("import.finished"))
        let stored = try #require(await chain.access.reader.runs().first)
        let files = try await chain.access.reader.shareCopies(of: stored.id)
        let document = try #require(files.first { $0.pathExtension == "json" })
        #expect(try String(contentsOf: document, encoding: .utf8).contains("import.finished"))
        await chain.access.reader.discardCopies()
    }

    @Test("With the gate closed, nothing is recorded and the folder is never made")
    func closedGateWritesNothing() async {
        let paths = Self.paths()
        defer { Self.remove(paths) }
        let chain = Self.chain(paths, gate: Self.closed(), log: RecordingLogger())

        #expect(await !chain.access.isOn())
        Self.runOneImport(through: chain)

        #expect(await chain.access.reader.runs().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: paths.trace.path))
    }

    @Test("Every answer but the TestFlight one keeps the trace closed")
    func onlySandboxOpens() async {
        for answer in DistributionAnswer.allCases {
            let paths = Self.paths()
            defer { Self.remove(paths) }
            let chain = Self.chain(paths, gate: .asking(FixedDistribution(answer)), log: RecordingLogger())
            #expect(await chain.access.isOn() == (answer == .sandbox), "\(answer)")
        }
    }

    @Test("A launch that may not record removes what an earlier install stored")
    func closedLaunchPurges() async throws {
        let paths = Self.paths()
        defer { Self.remove(paths) }
        let earlier = Self.chain(paths, gate: Self.sandbox(), log: RecordingLogger())
        #expect(await earlier.access.isOn())
        Self.runOneImport(through: earlier)
        #expect(await earlier.access.reader.runs().count == 1)
        #expect(FileManager.default.fileExists(atPath: paths.trace.path))

        let later = Self.chain(paths, gate: Self.closed(), log: RecordingLogger())
        #expect(await !later.access.isOn())

        #expect(!FileManager.default.fileExists(atPath: paths.trace.path))
        #expect(await later.access.reader.runs().isEmpty)
    }

    @Test("A run begun before the distribution answers is not recorded (fail closed); one begun after an open answer is")
    func runBeforeTheAnswerIsDropped() async throws {
        let paths = Self.paths()
        defer { Self.remove(paths) }
        let distribution = HeldDistribution()
        let chain = Self.chain(paths, gate: .asking(distribution), log: RecordingLogger())

        let early = chain.tracer.begin(.textImport)
        early.record(.input, .text("text", "early-" + Self.marker))
        early.finish(.finished)
        await distribution.answer(with: .sandbox)
        #expect(await chain.access.isOn())
        let late = chain.tracer.begin(.textImport)
        late.record(.input, .text("text", "late-" + Self.marker))
        late.finish(.finished)

        let runs = await chain.access.reader.runs()
        #expect(runs.count == 1, "Only the run begun after the answer is stored")
        let run = try #require(runs.first)
        let files = try await chain.access.reader.shareCopies(of: run.id)
        let document = try #require(files.first { $0.pathExtension == "json" })
        let text = try String(contentsOf: document, encoding: .utf8)
        #expect(text.contains("late-" + Self.marker))
        #expect(!text.contains("early-" + Self.marker))
        await chain.access.reader.discardCopies()
    }

    @Test("A launch that records keeps the runs of the earlier launch")
    func openLaunchKeeps() async {
        let paths = Self.paths()
        defer { Self.remove(paths) }
        let earlier = Self.chain(paths, gate: Self.sandbox(), log: RecordingLogger())
        #expect(await earlier.access.isOn())
        Self.runOneImport(through: earlier)
        #expect(await earlier.access.reader.runs().count == 1)

        let later = Self.chain(paths, gate: Self.sandbox(), log: RecordingLogger())
        #expect(await later.access.isOn())

        #expect(await later.access.reader.runs().count == 1)
    }

    #if DEBUG
    @Test("A Debug build records without asking the store")
    func debugRecords() async {
        let paths = Self.paths()
        defer { Self.remove(paths) }
        let chain = Self.chain(paths, gate: .debug, log: RecordingLogger())

        #expect(await chain.access.isOn())
        Self.runOneImport(through: chain)
        #expect(await chain.access.reader.runs().count == 1)
    }
    #endif
}

/// A distribution that answers when the test says so.
actor HeldDistribution: DistributionReading {
    private var held: CheckedContinuation<DistributionAnswer, Never>?
    private var given: DistributionAnswer?

    func answer() async throws -> DistributionAnswer {
        if let given { return given }
        return await withCheckedContinuation { held = $0 }
    }

    /// Gives the answer: to the call that waits for it, or to the one that comes later.
    func answer(with value: DistributionAnswer) {
        given = value
        held?.resume(returning: value)
        held = nil
    }
}

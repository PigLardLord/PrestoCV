import DiagnosticLogging
import DiagnosticTrace
import Foundation
import PrestoCVImporting
import Testing
@testable import PrestoCV

/// The trace of a test build as the app composes it (ADR 0032): the import records into it through the log, its text stays
/// in the trace and out of the log, and a closed gate writes nothing at all.
@Suite("The trace of a test build, as the app composes it")
struct TraceChainTests {

    private static let device = TraceDevice(appVersion: "1.0", build: "121", osVersion: "iOS 26.5", model: "iPhone17,1")
    /// A word that no CV and no log entry holds by chance
    private static let marker = "Zwiebelmarker"
    private static let pastedCV = """
        Laura Bianchi \(marker)
        Insegnante

        Esperienza
        Scuola Don Milani, Bologna
        2016 - oggi
        """

    /// A folder of its own, under the temporary folder
    private static func folder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("TraceChainTests-\(UUID().uuidString)", isDirectory: true)
    }

    private static func chain(in folder: URL, isOpen: Bool, log: any DiagnosticLogger) -> TraceChain {
        chain(in: folder, gate: TraceLaunchGate(gate: ConstantGate(isOpen: isOpen), answered: {}, distribution: { "debug" }), log: log)
    }

    private static func chain(in folder: URL, gate: TraceLaunchGate, log: any DiagnosticLogger) -> TraceChain {
        TraceChain(
            directory: folder.appendingPathComponent("Diagnostics", isDirectory: true),
            shareDirectory: folder.appendingPathComponent("Share", isDirectory: true),
            gate: gate,
            device: device,
            log: log
        )
    }

    private static func importText(through chain: TraceChain) throws {
        _ = try ImportCV(
            pdfReader: ScriptedPDFReader(), limits: .standard, logger: chain.logger, clock: ContinuousClock(), tracer: chain.tracer
        ).importText(pastedCV)
    }

    // MARK: Open

    @Test("With the gate open, the import is one run that holds the text, and no log entry holds it")
    func recordsTheImport() async throws {
        let folder = Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = LogSpy()
        let chain = Self.chain(in: folder, isOpen: true, log: log)

        try Self.importText(through: chain)

        let runs = await chain.access.reader.runs()
        #expect(runs.map(\.kind) == [.textImport])
        let run = try #require(runs.first)
        #expect(run.outcome == .finished)
        let files = try await chain.access.reader.shareCopies(of: run.id)
        let document = try #require(files.first { $0.pathExtension == "json" })
        #expect(try String(contentsOf: document, encoding: .utf8).contains(Self.marker))
        await chain.access.reader.discardCopies()

        #expect(log.events.contains("import.finished"), "The log still gets the import's entries")
        #expect(!String(describing: log.entries).contains(Self.marker), "No log entry holds the text")
        #expect(await chain.access.isOn())
    }

    // MARK: Closed

    @Test("With the gate closed, the import is logged and nothing is recorded: the folder is never made")
    func closedGateWritesNothing() async throws {
        let folder = Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = LogSpy()
        let chain = Self.chain(in: folder, isOpen: false, log: log)

        try Self.importText(through: chain)

        #expect(await chain.access.reader.runs().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("Diagnostics").path))
        #expect(log.events.contains("import.finished"))
        #expect(await !chain.access.isOn())
    }

    @Test("A launch whose gate stays closed removes what an earlier install stored, and a launch that records keeps it")
    func closedLaunchPurgesWhatAnEarlierInstallStored() async throws {
        let folder = Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let testFlight = Self.chain(in: folder, gate: .given("sandbox"), log: LogSpy())
        #expect(await testFlight.access.isOn(), "The gate has its answer before the first run begins")
        try Self.importText(through: testFlight)
        let stored = await testFlight.access.reader.runs()
        _ = try await testFlight.access.reader.shareCopies(of: #require(stored.first).id)
        #expect(stored.count == 1)

        let again = Self.chain(in: folder, gate: .given("sandbox"), log: LogSpy())
        #expect(await again.access.isOn())
        #expect(await again.access.reader.runs().count == 1, "A TestFlight launch keeps the runs of the earlier launch")

        for answer in ["production", "unknown", "unverified"] {
            let store = Self.chain(in: folder, gate: .given("sandbox"), log: LogSpy())
            #expect(await store.access.isOn())
            try Self.importText(through: store)
            _ = await store.access.reader.runs()

            let appStore = Self.chain(in: folder, gate: .given(answer), log: LogSpy())
            #expect(await !appStore.access.isOn())

            #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("Diagnostics").path), "\(answer)")
            #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("Share").path), "\(answer)")
            #expect(await appStore.access.reader.runs().isEmpty)
        }
    }

    // MARK: The gate of a Debug build

    @Test("A Debug build records unless a UI test gives the store's answer")
    func debugBuildRecords() async {
        let gate = TraceLaunchGate.current(arguments: ["PrestoCV"])
        await gate.answered()
        #expect(gate.gate.isOpen)
        #expect(gate.distribution() == "debug")
    }

    @Test("A UI test gives a Debug build the store's answer, and only a TestFlight install records", arguments: [
        ("sandbox", true), ("production", false), ("unknown", false), ("xcode", false), ("unverified", false),
    ])
    func givenAnswer(answer: String, records: Bool) async {
        let gate = TraceLaunchGate.current(arguments: ["PrestoCV", "-diagnosticsDistribution", answer])
        await gate.answered()
        #expect(gate.gate.isOpen == records)
        #expect(gate.distribution() == answer)
    }
}

private extension TraceLaunchGate {
    /// The gate of a Debug build that a UI test gives the store's answer
    static func given(_ answer: String) -> TraceLaunchGate {
        current(arguments: ["PrestoCV", "-diagnosticsDistribution", answer])
    }
}

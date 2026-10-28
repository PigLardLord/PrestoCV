import DiagnosticLogging
import DiagnosticLoggingTestSupport
import DiagnosticTrace
import DiagnosticTraceFiles
import Foundation
import Testing

@Suite("The file store keeps each run as a JSON document and a text summary, on the device only")
struct TraceFileStoreTests {
    // MARK: Writing

    @Test("A run is one JSON document and one text summary, whose bytes are the run's own")
    func oneDocumentAndOneSummary() async throws {
        let place = try ScratchFolder()
        let store = place.store()
        let run = TraceRun.stored(day: 1, outcome: .finished)

        store.save(run)
        await store.flush()

        #expect(place.names() == [run.fileStem + ".json", run.fileStem + ".txt"])
        #expect(try Data(contentsOf: place.diagnostics.appendingPathComponent(run.fileStem + ".json")) == run.document())
        #expect(try String(contentsOf: place.diagnostics.appendingPathComponent(run.fileStem + ".txt"), encoding: .utf8) == TraceSummary.text(of: run))
    }

    @Test("Only the latest state of a run is kept, and no temporary file is left")
    func latestStateOnly() async throws {
        let place = try ScratchFolder()
        let store = place.store()

        store.save(TraceRun.stored(day: 1, outcome: nil))
        store.save(TraceRun.stored(day: 1, outcome: .cancelled))
        await store.flush()

        #expect(place.names().count == 2)
        let json = place.diagnostics.appendingPathComponent(TraceRun.stored(day: 1, outcome: nil).fileStem + ".json")
        #expect(try TraceRun(document: Data(contentsOf: json)).outcome == .cancelled)
    }

    @Test("No folder is made until the first write")
    func noFolderBeforeTheFirstWrite() async throws {
        let place = try ScratchFolder()
        let store = place.store()

        await store.flush()
        _ = await store.runs()

        #expect(!FileManager.default.fileExists(atPath: place.diagnostics.path))
    }

    @Test("When a run ends, the ten newest runs stay, each with its summary")
    func retention() async throws {
        let place = try ScratchFolder()
        let store = place.store()

        for day in 1...12 {
            store.save(TraceRun.stored(day: day, outcome: .finished))
            await store.flush()
        }

        let names = place.names()
        #expect(names.count == 20)
        #expect(!names.contains(TraceRun.stored(day: 1, outcome: nil).fileStem + ".json"))
        #expect(!names.contains(TraceRun.stored(day: 2, outcome: nil).fileStem + ".txt"))
        #expect(names.contains(TraceRun.stored(day: 3, outcome: nil).fileStem + ".txt"))
    }

    @Test("The session events are one file with the last 200, kept across launches")
    func sessionEvents() async throws {
        let place = try ScratchFolder()
        let first = place.store()
        for index in 0..<150 { first.save(sessionEvent: .stored(line: "first \(index)")) }
        await first.flush()

        let second = place.store()
        for index in 0..<100 { second.save(sessionEvent: .stored(line: "second \(index)")) }
        await second.flush()

        let data = try Data(contentsOf: place.diagnostics.appendingPathComponent("session-events.json"))
        let events = try TraceSessionLog.events(document: data)
        #expect(events.count == 200)
        #expect(events.first?.line == "first 50")
        #expect(events.last?.line == "second 99")
    }

    @Test("A write that fails is logged as a typed error, and never reaches the caller")
    func failedWriteIsLogged() async throws {
        let place = try ScratchFolder()
        try Data("a file".utf8).write(to: place.root.appendingPathComponent("blocked"))
        let logger = RecordingLogger()
        let store = TraceFileStore(
            directory: place.root.appendingPathComponent("blocked").appendingPathComponent("Diagnostics"),
            shareDirectory: place.share,
            logger: logger
        )

        store.save(TraceRun.stored(day: 1, outcome: .finished))
        await store.flush()

        let entry = try #require(logger.entry("trace.writeFailed"))
        #expect(entry.value("error") == .error(type: "TraceStoreError", code: "write"))
    }

    // MARK: Reading

    @Test("The runs are listed newest first, with their kind, start, outcome and stored summary")
    func listing() async throws {
        let place = try ScratchFolder()
        let store = place.store()
        store.save(TraceRun.stored(day: 1, outcome: .finished))
        store.save(TraceRun.stored(day: 2, outcome: .failed(code: "model")))
        await store.flush()

        let runs = await store.runs()

        #expect(runs.map(\.id) == [TraceRun.stored(day: 2, outcome: nil).id, TraceRun.stored(day: 1, outcome: nil).id])
        #expect(runs.map(\.outcome) == [.failed(code: "model"), .finished])
        #expect(runs.first?.kind == .aiDraft)
        #expect(runs.first?.summary == TraceSummary.text(of: TraceRun.stored(day: 2, outcome: .failed(code: "model"))))
    }

    @Test("A corrupt run is left out of the list, and logged as a typed outcome")
    func corruptRunIsSkipped() async throws {
        let place = try ScratchFolder()
        let logger = RecordingLogger()
        let store = place.store(logger: logger)
        store.save(TraceRun.stored(day: 1, outcome: .finished))
        await store.flush()
        try Data("not json".utf8).write(to: place.diagnostics.appendingPathComponent("run-20261001T000000.000Z-aiDraft-deadbeef.json"))

        let runs = await store.runs()

        #expect(runs.count == 1)
        let entry = try #require(logger.entry("trace.readFailed"))
        #expect(entry.value("error") == .error(type: "TraceStoreError", code: "corruptRun"))
    }

    @Test("The share copies hold the stored bytes, in a temporary folder that is removed on close")
    func shareCopies() async throws {
        let place = try ScratchFolder()
        let store = place.store()
        let run = TraceRun.stored(day: 1, outcome: .finished)
        store.save(run)
        await store.flush()

        let copies = try await store.shareCopies(of: run.id)

        #expect(copies.map(\.lastPathComponent) == [run.fileStem + ".json", run.fileStem + ".txt"])
        #expect(try Data(contentsOf: copies[0]) == run.document())
        #expect(copies.allSatisfy { $0.path.hasPrefix(place.share.path) })

        await store.discardCopies()

        #expect(!copies.contains { FileManager.default.fileExists(atPath: $0.path) })
        #expect(place.names().count == 2)
    }

    @Test("Sharing a run that is not stored throws a typed error")
    func shareMissingRun() async throws {
        let place = try ScratchFolder()
        let store = place.store()

        await #expect(throws: TraceStoreError.missingRun) { try await store.shareCopies(of: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9))) }
    }

    #if canImport(Darwin)
    @Test("The folder is excluded from backup")
    func excludedFromBackup() async throws {
        let place = try ScratchFolder()
        let store = place.store()
        store.save(TraceRun.stored(day: 1, outcome: .finished))
        await store.flush()

        let values = try place.diagnostics.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }
    #endif
}

// MARK: - Support

/// A temporary folder for one test, removed when the test ends.
private final class ScratchFolder {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("trace-store-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    var diagnostics: URL { root.appendingPathComponent("Diagnostics") }
    var share: URL { root.appendingPathComponent("Share") }

    func store(logger: any DiagnosticLogger = SilentLogger()) -> TraceFileStore {
        TraceFileStore(directory: diagnostics, shareDirectory: share, logger: logger)
    }

    /// The names of the files in the store's folder, sorted.
    func names() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: diagnostics.path)) ?? []).sorted()
    }
}

extension TraceRun {
    static func stored(day: Int, outcome: TraceOutcome?) -> TraceRun {
        TraceRun(
            id: UUID(uuid: (0x0A, 0x0B, 0x0C, UInt8(day), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(day))),
            kind: .aiDraft,
            started: Date(timeIntervalSince1970: 1_790_812_800 + Double(day) * 86_400),
            build: TraceBuild(appVersion: "1.0", build: "121", distribution: "sandbox", osVersion: "iOS 26.5", deviceModel: "iPhone17,1"),
            steps: [TraceStep(sequence: 1, elapsed: .milliseconds(10), name: .input, fields: [.text("description", "Ten years of nursing.")])],
            outcome: outcome
        )
    }
}

extension TraceSessionEvent {
    static func stored(line: String) -> TraceSessionEvent {
        TraceSessionEvent(time: Date(timeIntervalSince1970: 1_793_188_800), category: "draft", level: "info", line: line)
    }
}

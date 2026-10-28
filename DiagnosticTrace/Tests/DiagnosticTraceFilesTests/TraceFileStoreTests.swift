import DiagnosticLogging
import DiagnosticLoggingTestSupport
import DiagnosticTrace
import DiagnosticTraceFiles
import Foundation
import Synchronization
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

    // MARK: Protection, sharing and removal

    @Test("A folder that exists already is protected before the first file goes into it, and a failure to protect writes nothing")
    func existingFolderIsProtectedFirst() async throws {
        let place = try ScratchFolder()
        try FileManager.default.createDirectory(at: place.diagnostics, withIntermediateDirectories: true)
        let spy = ProtectionSpy()
        let store = place.store(protection: spy)
        store.save(TraceRun.stored(day: 1, outcome: .finished))
        await store.flush()

        #expect(spy.calls.first?.folder.path == place.diagnostics.path)
        #expect(spy.calls.first?.contents == [], "The folder was empty when it was protected")
        #expect(place.names().count == 2)

        let failing = try ScratchFolder()
        try FileManager.default.createDirectory(at: failing.diagnostics, withIntermediateDirectories: true)
        let logger = RecordingLogger()
        let refused = failing.store(logger: logger, protection: ProtectionSpy(failing: true))
        refused.save(TraceRun.stored(day: 1, outcome: .finished))
        await refused.flush()

        #expect(failing.names().isEmpty, "A folder that cannot be protected gets no CV content")
        #expect(logger.entry("trace.writeFailed") != nil)
    }

    @Test("The folder of the copies to share is protected too")
    func shareFolderIsProtected() async throws {
        let place = try ScratchFolder()
        let spy = ProtectionSpy()
        let store = place.store(protection: spy)
        let run = TraceRun.stored(day: 1, outcome: .finished)
        store.save(run)
        await store.flush()

        _ = try await store.shareCopies(of: run.id)

        #expect(spy.calls.map(\.folder.path).contains(place.share.path))
    }

    @Test("A share that cannot be protected leaves no copy behind")
    func failedShareLeavesNothing() async throws {
        let place = try ScratchFolder()
        let run = TraceRun.stored(day: 1, outcome: .finished)
        let store = place.store(protection: ProtectionSpy(failingFor: place.share))
        store.save(run)
        await store.flush()

        await #expect(throws: TraceStoreError.share) { try await store.shareCopies(of: run.id) }

        #expect(!FileManager.default.fileExists(atPath: place.share.path))
    }

    @Test("Copies left by an earlier launch are removed when the store starts, and a gate that stays closed still has it")
    func staleCopiesAreRemovedAtLaunch() async throws {
        let place = try ScratchFolder()
        try FileManager.default.createDirectory(at: place.share, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: place.share.appendingPathComponent("run-old.json"))

        let store = place.store()
        await store.flush()

        #expect(!FileManager.default.fileExists(atPath: place.share.path))
    }

    @Test("The shared files hold the session events too, such as the language data prepared between two runs")
    func sharedFilesHoldTheSessionEvents() async throws {
        let place = try ScratchFolder()
        let store = place.store()
        let first = TraceRun.stored(day: 1, outcome: .finished)
        store.save(first)
        store.save(sessionEvent: .stored(line: "between the two runs"))
        store.save(TraceRun.stored(day: 2, outcome: .finished))
        await store.flush()

        let copies = try await store.shareCopies(of: first.id)

        #expect(copies.map(\.lastPathComponent) == [first.fileStem + ".json", first.fileStem + ".txt", "session-events.json"])
        let events = try TraceSessionLog.events(document: Data(contentsOf: copies[2]))
        #expect(events.map(\.line) == ["between the two runs"])
    }

    @Test("Purging removes the stored runs, the session events and the copies, and drops what was saved and not written")
    func purge() async throws {
        let place = try ScratchFolder()
        let store = place.store()
        let run = TraceRun.stored(day: 1, outcome: .finished)
        store.save(run)
        store.save(sessionEvent: .stored(line: "event"))
        await store.flush()
        _ = try await store.shareCopies(of: run.id)
        store.save(TraceRun.stored(day: 2, outcome: .finished))

        await store.purge()

        #expect(!FileManager.default.fileExists(atPath: place.diagnostics.path))
        #expect(!FileManager.default.fileExists(atPath: place.share.path))
        #expect(await store.runs().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: place.diagnostics.path), "The run saved before the purge is not written after it")
    }

    #if canImport(Darwin)
    @Test("A folder that exists without the exclusion from backup gets it before the next write")
    func existingFolderGetsTheExclusion() async throws {
        let place = try ScratchFolder()
        try FileManager.default.createDirectory(at: place.diagnostics, withIntermediateDirectories: true)
        #expect(try place.diagnostics.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup != true)
        let store = place.store()
        store.save(TraceRun.stored(day: 1, outcome: .finished))
        await store.flush()

        #expect(try place.diagnostics.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

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

    func store(logger: any DiagnosticLogger = SilentLogger(), protection: any TraceFolderProtecting) -> TraceFileStore {
        TraceFileStore(directory: diagnostics, shareDirectory: share, logger: logger, protection: protection)
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

/// A protection that records the folders it was asked for, with what each held then, and refuses on request.
private final class ProtectionSpy: TraceFolderProtecting {
    struct Call: Equatable {
        let folder: URL
        let contents: [String]
    }

    private let recorded = Mutex<[Call]>([])
    private let failing: Bool
    private let failingFor: URL?

    init(failing: Bool = false, failingFor: URL? = nil) {
        self.failing = failing
        self.failingFor = failingFor
    }

    var calls: [Call] { recorded.withLock { $0 } }

    func protect(_ folder: URL) throws {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        recorded.withLock { $0.append(Call(folder: folder, contents: contents)) }
        if failing || folder.path == failingFor?.path { throw TraceStoreError.write }
    }
}

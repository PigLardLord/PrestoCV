import DiagnosticLogging
import DiagnosticTrace
import Foundation
import Synchronization

/// Why the store could not do what it was asked.
public enum TraceStoreError: Error, Equatable, LoggableError {
    /// A file or the folder could not be written.
    case write
    /// A stored run does not read as a run.
    case corruptRun
    /// No stored run has this id.
    case missingRun
    /// The copies to share could not be made.
    case share

    public var logCode: StaticString {
        switch self {
        case .write: "write"
        case .corruptRun: "corruptRun"
        case .missingRun: "missingRun"
        case .share: "share"
        }
    }
}

extension LogCategory {
    static let trace = LogCategory("trace")
}

/// Keeps the runs of a test build on the device, in one folder (ADR 0032): per run a JSON document and a text summary,
/// the ten newest runs, and the session's events. The folder is made on the first write, so a build whose gate stays
/// closed has none. It is excluded from backup, and its files are protected while the device is locked.
///
/// `save` returns at once: the files are written by one task, which writes only the latest state of each run and replaces
/// each file whole. A failure is logged and never reaches the caller.
public final class TraceFileStore: TraceStoring, TraceReading {
    private let queue = PendingWrites()
    private let writer: TraceFileWriter
    private let wake: AsyncStream<Void>.Continuation

    /// - Parameters:
    ///   - directory: the store's folder, such as `Library/Application Support/Diagnostics`.
    ///   - shareDirectory: a temporary folder for the copies to share.
    ///   - logger: where write failures go. It must not trace, or a failure would feed itself.
    public init(directory: URL, shareDirectory: URL, logger: any DiagnosticLogger) {
        let writer = TraceFileWriter(directory: directory, shareDirectory: shareDirectory, queue: queue, logger: logger)
        let (wakes, wake) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        self.writer = writer
        self.wake = wake
        Task {
            for await _ in wakes { await writer.drain() }
        }
    }

    deinit {
        wake.finish()
    }

    public func save(_ run: TraceRun) {
        queue.put(run)
        wake.yield()
    }

    public func save(sessionEvent: TraceSessionEvent) {
        queue.put(sessionEvent)
        wake.yield()
    }

    /// Waits until everything saved so far is written.
    public func flush() async {
        await writer.drain()
    }

    public func runs() async -> [TraceRunListing] {
        await writer.drain()
        return await writer.listing()
    }

    public func shareCopies(of id: UUID) async throws -> [URL] {
        await writer.drain()
        return try await writer.shareCopies(of: id)
    }

    public func discardCopies() async {
        await writer.discardCopies()
    }
}

/// What was saved and not written yet: the latest state of each run, and the new session events.
private final class PendingWrites: Sendable {
    struct Batch {
        var runs: [TraceRun] = []
        var events: [TraceSessionEvent] = []
    }

    private let pending = Mutex(Batch())

    func put(_ run: TraceRun) {
        pending.withLock { batch in
            if let index = batch.runs.firstIndex(where: { $0.id == run.id }) {
                batch.runs[index] = run
            } else {
                batch.runs.append(run)
            }
        }
    }

    func put(_ event: TraceSessionEvent) {
        pending.withLock { $0.events.append(event) }
    }

    func take() -> Batch {
        pending.withLock { batch in
            defer { batch = Batch() }
            return batch
        }
    }
}

/// Writes and reads the store's files, one call at a time, off the main actor.
private actor TraceFileWriter {
    private let directory: URL
    private let shareDirectory: URL
    private let queue: PendingWrites
    private let logger: any DiagnosticLogger
    private let files = FileManager.default
    /// The session's events as written, read from the file once.
    private var sessionEvents: [TraceSessionEvent]?

    init(directory: URL, shareDirectory: URL, queue: PendingWrites, logger: any DiagnosticLogger) {
        self.directory = directory
        self.shareDirectory = shareDirectory
        self.queue = queue
        self.logger = logger
    }

    // MARK: Writing

    func drain() {
        let batch = queue.take()
        guard !batch.runs.isEmpty || !batch.events.isEmpty else { return }
        do {
            try prepareDirectory()
            for run in batch.runs { try write(run) }
            if batch.runs.contains(where: { $0.outcome != nil }) { try removeExpiredRuns() }
            if !batch.events.isEmpty { try write(batch.events) }
        } catch {
            logger.error(.trace, "trace.writeFailed", .error(TraceStoreError.write))
        }
    }

    private func prepareDirectory() throws {
        guard !files.fileExists(atPath: directory.path) else { return }
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        #if canImport(Darwin)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var folder = directory
        try folder.setResourceValues(values)
        #endif
    }

    private func write(_ run: TraceRun) throws {
        try write(run.document(), to: run.fileStem + ".json")
        try write(Data(TraceSummary.text(of: run).utf8), to: run.fileStem + ".txt")
    }

    private func write(_ events: [TraceSessionEvent]) throws {
        let kept = TraceSessionLog.appending(events, to: sessionEvents ?? storedSessionEvents())
        try write(TraceSessionLog.document(kept), to: TraceSessionLog.fileName)
        sessionEvents = kept
    }

    private func storedSessionEvents() -> [TraceSessionEvent] {
        let file = directory.appendingPathComponent(TraceSessionLog.fileName)
        guard files.fileExists(atPath: file.path) else { return [] }
        do {
            return try TraceSessionLog.events(document: Data(contentsOf: file))
        } catch {
            logger.error(.trace, "trace.readFailed", .error(TraceStoreError.corruptRun))
            return []
        }
    }

    private func write(_ data: Data, to name: String) throws {
        #if os(iOS)
        let options: Data.WritingOptions = [.atomic, .completeFileProtection]
        #else
        let options: Data.WritingOptions = [.atomic]
        #endif
        try data.write(to: directory.appendingPathComponent(name), options: options)
    }

    private func removeExpiredRuns() throws {
        for stem in TraceRetention.expired(try runStems()) {
            for name in [stem + ".json", stem + ".txt"] where files.fileExists(atPath: directory.appendingPathComponent(name).path) {
                try files.removeItem(at: directory.appendingPathComponent(name))
            }
        }
    }

    /// The stems of the stored runs, from their documents.
    private func runStems() throws -> [String] {
        guard files.fileExists(atPath: directory.path) else { return [] }
        return try files.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("run-") && $0.hasSuffix(".json") }
            .map { String($0.dropLast(".json".count)) }
    }

    // MARK: Reading

    func listing() -> [TraceRunListing] {
        storedRuns().map { run, summary in
            TraceRunListing(id: run.id, kind: run.kind, started: run.started, outcome: run.outcome, summary: summary)
        }
    }

    /// The stored runs that read, newest first, with their stored summaries. A run that does not read is logged and left out.
    private func storedRuns() -> [(TraceRun, String)] {
        let stems: [String]
        do {
            stems = try runStems().sorted(by: >)
        } catch {
            logger.error(.trace, "trace.readFailed", .error(TraceStoreError.write))
            return []
        }
        return stems.compactMap { stem in
            do {
                let run = try TraceRun(document: Data(contentsOf: directory.appendingPathComponent(stem + ".json")))
                let summaryFile = directory.appendingPathComponent(stem + ".txt")
                let summary = files.fileExists(atPath: summaryFile.path)
                    ? try String(contentsOf: summaryFile, encoding: .utf8) : TraceSummary.text(of: run)
                return (run, summary)
            } catch {
                logger.error(.trace, "trace.readFailed", .error(TraceStoreError.corruptRun))
                return nil
            }
        }
    }

    func shareCopies(of id: UUID) throws -> [URL] {
        guard let (run, summary) = storedRuns().first(where: { $0.0.id == id }) else { throw TraceStoreError.missingRun }
        do {
            discardCopies()
            try files.createDirectory(at: shareDirectory, withIntermediateDirectories: true)
            let document = shareDirectory.appendingPathComponent(run.fileStem + ".json")
            let text = shareDirectory.appendingPathComponent(run.fileStem + ".txt")
            try files.copyItem(at: directory.appendingPathComponent(run.fileStem + ".json"), to: document)
            try Data(summary.utf8).write(to: text, options: .atomic)
            return [document, text]
        } catch {
            logger.error(.trace, "trace.shareFailed", .error(TraceStoreError.share))
            throw TraceStoreError.share
        }
    }

    func discardCopies() {
        guard files.fileExists(atPath: shareDirectory.path) else { return }
        do {
            try files.removeItem(at: shareDirectory)
        } catch {
            logger.error(.trace, "trace.shareFailed", .error(TraceStoreError.share))
        }
    }
}

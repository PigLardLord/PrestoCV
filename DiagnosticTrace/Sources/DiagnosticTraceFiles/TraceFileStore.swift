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

/// Keeps a folder out of the backup and its files protected while the device is locked.
public protocol TraceFolderProtecting: Sendable {
    /// Applies the protection to a folder that exists, and checks it took. Throws when it cannot be sure.
    func protect(_ folder: URL) throws
}

/// The protection the system gives: exclusion from backup and complete file protection on Apple platforms, and nothing on
/// a platform that has neither.
public struct SystemFolderProtection: TraceFolderProtecting {
    public init() {}

    public func protect(_ folder: URL) throws {
        #if canImport(Darwin)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var excluded = folder
        try excluded.setResourceValues(values)
        guard try excluded.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true else {
            throw TraceStoreError.write
        }
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: folder.path)
        #endif
        #endif
    }
}

extension LogCategory {
    static let trace = LogCategory("trace")
}

/// Keeps the runs of a test build on the device, in one folder (ADR 0032): per run a JSON document and a text summary,
/// the ten newest runs, and the session's events. The folder is made on the first write, so a build whose gate stays
/// closed has none. It is excluded from backup, and its files are protected while the device is locked: before every launch's
/// first write the store applies that to the folder, also to one that exists already, and writes nothing if it cannot.
/// The copies made to share are removed when the store starts, so a launch that was killed leaves none behind.
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
    public convenience init(directory: URL, shareDirectory: URL, logger: any DiagnosticLogger) {
        self.init(directory: directory, shareDirectory: shareDirectory, logger: logger, protection: SystemFolderProtection())
    }

    /// - Parameter protection: what keeps the folders out of the backup and their files protected.
    public init(directory: URL, shareDirectory: URL, logger: any DiagnosticLogger, protection: any TraceFolderProtecting) {
        let writer = TraceFileWriter(
            directory: directory, shareDirectory: shareDirectory, queue: queue, logger: logger, protection: protection
        )
        let (wakes, wake) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        self.writer = writer
        self.wake = wake
        Task {
            await writer.startUp()
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

    /// Removes every stored run, the session events and the copies, and drops what was saved and not written yet. The app
    /// calls it when the trace may not record on this install, so that CV content left by an earlier install does not stay.
    public func purge() async {
        await writer.purge()
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
    private let protection: any TraceFolderProtecting
    private let files = FileManager.default
    /// The session's events as written, read from the file once.
    private var sessionEvents: [TraceSessionEvent]?
    /// Whether the copies of an earlier launch were removed.
    private var started = false
    /// Whether the folder was protected and the protection checked, since the store started.
    private var folderIsProtected = false

    init(directory: URL, shareDirectory: URL, queue: PendingWrites, logger: any DiagnosticLogger, protection: any TraceFolderProtecting) {
        self.directory = directory
        self.shareDirectory = shareDirectory
        self.queue = queue
        self.logger = logger
        self.protection = protection
    }

    // MARK: Starting and purging

    /// Removes the copies an earlier launch left, once, before anything else is done. Every entry point calls it first, so
    /// that it can never remove the copies of this launch.
    func startUp() {
        guard !started else { return }
        started = true
        removeCopies()
    }

    func purge() {
        started = true
        _ = queue.take()
        sessionEvents = nil
        folderIsProtected = false
        removeCopies()
        remove(directory)
    }

    private func remove(_ folder: URL) {
        guard files.fileExists(atPath: folder.path) else { return }
        do {
            try files.removeItem(at: folder)
        } catch {
            logger.error(.trace, "trace.writeFailed", .error(TraceStoreError.write))
        }
    }

    // MARK: Writing

    func drain() {
        startUp()
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

    /// Makes the folder if it is missing, and protects it before the first write of this launch even if it exists: a launch
    /// that died between making it and protecting it must not leave a folder that is backed up.
    private func prepareDirectory() throws {
        if !files.fileExists(atPath: directory.path) {
            try files.createDirectory(at: directory, withIntermediateDirectories: true)
            folderIsProtected = false
        }
        guard !folderIsProtected else { return }
        try protection.protect(directory)
        folderIsProtected = true
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
        try data.write(to: directory.appendingPathComponent(name), options: Self.writingOptions)
    }

    private static var writingOptions: Data.WritingOptions {
        #if os(iOS)
        [.atomic, .completeFileProtection]
        #else
        [.atomic]
        #endif
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
        startUp()
        return storedRuns().map { run, summary in
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

    /// Copies of the run's document and summary, and of the session's events when there are any, in a protected folder. A
    /// failure removes the copies already made.
    func shareCopies(of id: UUID) throws -> [URL] {
        started = true
        guard let (run, summary) = storedRuns().first(where: { $0.0.id == id }) else { throw TraceStoreError.missingRun }
        do {
            removeCopies()
            try files.createDirectory(at: shareDirectory, withIntermediateDirectories: true)
            try protection.protect(shareDirectory)
            var copies = [
                try copy(Data(contentsOf: directory.appendingPathComponent(run.fileStem + ".json")), as: run.fileStem + ".json"),
                try copy(Data(summary.utf8), as: run.fileStem + ".txt"),
            ]
            let events = directory.appendingPathComponent(TraceSessionLog.fileName)
            if files.fileExists(atPath: events.path) {
                copies.append(try copy(Data(contentsOf: events), as: TraceSessionLog.fileName))
            }
            return copies
        } catch {
            logger.error(.trace, "trace.shareFailed", .error(TraceStoreError.share))
            removeCopies()
            throw TraceStoreError.share
        }
    }

    private func copy(_ data: Data, as name: String) throws -> URL {
        let file = shareDirectory.appendingPathComponent(name)
        try data.write(to: file, options: Self.writingOptions)
        return file
    }

    func discardCopies() {
        started = true
        removeCopies()
    }

    private func removeCopies() {
        guard files.fileExists(atPath: shareDirectory.path) else { return }
        do {
            try files.removeItem(at: shareDirectory)
        } catch {
            logger.error(.trace, "trace.shareFailed", .error(TraceStoreError.share))
        }
    }
}

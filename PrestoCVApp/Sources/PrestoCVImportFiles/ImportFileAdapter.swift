import DiagnosticLogging
import Foundation
import PrestoCVImporting
import PrestoCVWorkflowPorts
import Synchronization

/// The adapter of `ImportFileReading` (step 5-8d).
///
/// - `receive` starts security-scoped access for that received file, then resolves the path and takes the file's
///   identity (device and file number), once. Its `release` stops the access. Each start has its own stop, as the system
///   counts them, so two received files of one file never share an access that one of them could end for the other.
/// - The received files are counted per identity. When the last one of an identity is let go, each path it was received
///   by that lies directly in a copy folder (the folders where the system puts the copy of a file opened in the app) is
///   deleted, if it still names that file. A file anywhere else is the person's and is never touched.
/// - The count and the delete happen under one lock, which `receive` takes too: a `receive` of the same file waits for
///   the delete and then finds no file, never half of one.
/// - `readPDF(of:)` reads within the size bound, from the path `receive` captured, and only the file of the identity it
///   captured: a path that names another file by then is not read.
/// - A copy an earlier run left (the app ended while a file waited, or before the system handed it the URL) is deleted
///   when the adapter is made, whether or not any import follows, by a rule that reads no clock: a regular file directly
///   in a copy folder goes at the second launch that finds it, under the same name and file. A copy the system made
///   for this run is new to it, so no sweep takes a file on its way, whichever window it is for, however the clock
///   moves. The sweep never runs again, so it never takes a file this run has received.
/// - `logging(to:)` gives an adapter over the same received files and copies left over, writing to another log: the
///   process makes one, and each part that holds files uses its own log.
public final class ImportFileAdapter: ImportFileReading {
    private struct Received {
        /// Nil when the path named no regular file at `receive`: such a file is never read and never deleted.
        let identity: FileIdentity?
        let resolved: URL
        /// The URL access started on, which is the one it stops on; nil when the system started none.
        let scoped: URL?
    }

    private struct Open {
        var count: Int
        /// Every path the file was received by; each one directly in a copy folder is deleted at the last release.
        var paths: Set<URL>
    }

    private struct State {
        var nextID = 1
        var received: [Int: Received] = [:]
        var open: [FileIdentity: Open] = [:]
    }

    private struct Released {
        let scoped: URL?
        let failures: [ImportFileError]
    }

    /// What the adapters made by `logging(to:)` share.
    private final class Holdings: Sendable {
        let state: Mutex<State>

        init() {
            state = Mutex(State())
        }
    }

    private let files: any ImportFileSystem
    private let copyFolders: [URL]
    private let maximumBytes: Int
    private let logger: any DiagnosticLogger
    private let holdings: Holdings

    /// Deletes the copies an earlier run left, once: those directly in the copy folders that the last launch found too,
    /// as its record at `record` says. A launch that finds no record, or cannot read it, deletes nothing; it is logged,
    /// and the copies found now go at the next launch.
    ///
    /// - Parameters:
    ///   - copyFolders: the folders the system puts the copy of an opened file in; only a file directly inside one of
    ///     them is ever deleted. With none, nothing is read, written or logged.
    ///   - record: where the sweep keeps the copies a launch found, in a folder of the app's own that is no copy folder;
    ///     the folder is made when it is missing.
    public init(
        files: any ImportFileSystem, copyFolders: [URL], maximumBytes: Int, record: URL, logger: any DiagnosticLogger
    ) {
        self.files = files
        self.copyFolders = copyFolders
        self.maximumBytes = maximumBytes
        self.logger = logger
        holdings = Holdings()
        Self.deleteLeftovers(in: copyFolders, of: files, record: record, logger: logger)
    }

    private init(
        files: any ImportFileSystem, copyFolders: [URL], maximumBytes: Int, logger: any DiagnosticLogger,
        holdings: Holdings
    ) {
        self.files = files
        self.copyFolders = copyFolders
        self.maximumBytes = maximumBytes
        self.logger = logger
        self.holdings = holdings
    }

    /// An adapter over the same received files, writing to `logger`.
    public func logging(to logger: any DiagnosticLogger) -> ImportFileAdapter {
        ImportFileAdapter(
            files: files, copyFolders: copyFolders, maximumBytes: maximumBytes, logger: logger, holdings: holdings
        )
    }

    public func receive(_ url: URL) -> ReceivedFile {
        // Access first: without it the system may not even let the path be resolved or looked at
        let scoped = files.startAccess(url) ? url : nil
        return holdings.state.withLock { state -> ReceivedFile in
            let resolved = files.resolve(url)
            let identity = files.identity(ofResolved: resolved)
            let id = state.nextID
            state.nextID += 1
            state.received[id] = Received(identity: identity, resolved: resolved, scoped: scoped)
            if let identity {
                state.open[identity, default: Open(count: 0, paths: [])].count += 1
                state.open[identity]?.paths.insert(resolved)
            }
            return ReceivedFile(id: id, url: url)
        }
    }

    public func readPDF(of file: ReceivedFile) async throws -> Data {
        let began = holdings.state.withLock { state -> Received? in
            state.received[file.id]
        }
        guard let received = began else {
            logger.error(.importing, "import.file.notRead", .token("reason", "notReceived"))
            throw ImportFailure.fileNotRead
        }
        guard let identity = received.identity else {
            logger.error(.importing, "import.file.notRead", .token("reason", "noIdentity"))
            throw ImportFailure.fileNotRead
        }
        try Task.checkCancellation()
        let read: FileRead
        do {
            read = try files.read(received.resolved, identity: identity, atMost: maximumBytes)
        } catch {
            logger.error(.importing, "import.file.notRead", .error(error))
            throw ImportFailure.fileNotRead
        }
        try Task.checkCancellation()
        guard holdings.state.withLock({ $0.received[file.id] != nil }) else {
            logger.error(.importing, "import.file.notRead", .token("reason", "releasedDuringRead"))
            throw ImportFailure.fileNotRead
        }
        switch read {
        case .aboveTheLimit: throw ImportFailure.tooLarge
        case .bytes(let data): return data
        }
    }

    public func release(_ file: ReceivedFile) {
        guard let released = letGo(file) else {
            logger.notice(.importing, "import.file.releasedAgain")
            return
        }
        for failure in released.failures {
            logger.error(.importing, "import.file.copyNotDeleted", .error(failure))
        }
        // The copy went while this file's access still held; the access ends last, outside the lock
        if let scoped = released.scoped { files.stopAccess(scoped) }
    }

    /// Takes the file out of the count, and deletes its copies when it was the last one of its identity, under the lock.
    /// Gives nil for a file not received or already released.
    private func letGo(_ file: ReceivedFile) -> Released? {
        holdings.state.withLock { state -> Released? in
            guard let received = state.received.removeValue(forKey: file.id) else { return nil }
            var failures: [ImportFileError] = []
            if let identity = received.identity, var open = state.open[identity] {
                open.count -= 1
                if open.count == 0 {
                    state.open.removeValue(forKey: identity)
                    failures += deleteCopies(of: identity, at: open.paths)
                } else {
                    state.open[identity] = open
                }
            }
            return Released(scoped: received.scoped, failures: failures)
        }
    }

    /// Deletes each path that lies directly in a copy folder, when it still names the file; a folder's own path and a
    /// file in a subfolder of it are never deleted.
    private func deleteCopies(of identity: FileIdentity, at paths: Set<URL>) -> [ImportFileError] {
        let folders = copyFolders.map { files.resolve($0).pathComponents }
        var failures: [ImportFileError] = []
        for path in paths.sorted(by: { $0.path < $1.path })
        where folders.contains(Array(path.pathComponents.dropLast())) {
            do {
                try files.remove(path, identity: identity)
            } catch {
                failures.append(error)
            }
        }
        return failures
    }

    /// Lists the folders, writes the record of the copies found now that the last launch's record does not name, and
    /// only then deletes those it names, by the same rule as a received file's copies (still the file, never a link, a
    /// folder or what lies in one). A launch that cannot write the record deletes nothing, so a record never names a
    /// file number that a delete freed; and a copy deleted now is left out of it, so a new file that takes that number
    /// under the same name is new to the next launch. A folder that is not there holds none; one that cannot be
    /// listed, and a copy that cannot be deleted, is logged.
    private static func deleteLeftovers(
        in folders: [URL], of files: any ImportFileSystem, record: URL, logger: any DiagnosticLogger
    ) {
        guard !folders.isEmpty else { return }
        let lastFound = recalled(from: record, of: files, logger: logger)
        var newlyFound: [CopiesRecord.Copy] = []
        var leftovers: [(url: URL, identity: FileIdentity)] = []
        for folder in folders {
            let entries: [URL]
            do {
                entries = try files.entries(in: files.resolve(folder))
            } catch {
                logger.error(.importing, "import.file.copiesNotListed", .error(error))
                continue
            }
            for entry in entries.sorted(by: { $0.path < $1.path }) {
                guard let identity = files.identity(ofResolved: entry) else { continue }
                let copy = CopiesRecord.Copy(name: entry.lastPathComponent, device: identity.device, file: identity.file)
                if lastFound.contains(copy) {
                    leftovers.append((entry, identity))
                } else {
                    newlyFound.append(copy)
                }
            }
        }
        guard remember(newlyFound, at: record, of: files, logger: logger) else { return }
        for leftover in leftovers {
            do {
                try files.remove(leftover.url, identity: leftover.identity)
            } catch {
                logger.error(.importing, "import.file.copyNotDeleted", .error(error))
            }
        }
    }

    /// The copies the last launch found, as its record says; none, logged, when there is no record or it cannot be read.
    private static func recalled(
        from record: URL, of files: any ImportFileSystem, logger: any DiagnosticLogger
    ) -> Set<CopiesRecord.Copy> {
        let read: FileRead?
        do {
            read = try files.contents(of: record, atMost: CopiesRecord.maximumBytes)
        } catch {
            logger.error(.importing, "import.file.copiesRecordNotRead", .error(error))
            return []
        }
        switch read {
        case nil:
            logger.notice(.importing, "import.file.copiesRecordMissing")
            return []
        case .aboveTheLimit?:
            logger.error(.importing, "import.file.copiesRecordNotRead", .token("reason", "tooLarge"))
            return []
        case .bytes(let data)?:
            do throws(CopiesRecord.Problem) {
                return Set(try CopiesRecord.decoded(from: data).copies)
            } catch {
                logger.error(.importing, "import.file.copiesRecordNotRead", .token("reason", error.reason))
                return []
            }
        }
    }

    /// Writes the first copies found as the record for the next launch; false, logged, when it is not written.
    private static func remember(
        _ copies: [CopiesRecord.Copy], at record: URL, of files: any ImportFileSystem, logger: any DiagnosticLogger
    ) -> Bool {
        let data: Data
        do throws(CopiesRecord.Problem) {
            data = try CopiesRecord(copies: Array(copies.prefix(CopiesRecord.maximumCopies))).encoded()
        } catch {
            logger.error(.importing, "import.file.copiesRecordNotWritten", .token("reason", error.reason))
            return false
        }
        do {
            try files.store(data, at: record)
        } catch {
            logger.error(.importing, "import.file.copiesRecordNotWritten", .error(error))
            return false
        }
        return true
    }
}

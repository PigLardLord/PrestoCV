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

    private let files: any ImportFileSystem
    private let copyFolders: [URL]
    private let maximumBytes: Int
    private let logger: any DiagnosticLogger
    private let state = Mutex(State())

    /// - Parameter copyFolders: the folders the system puts the copy of an opened file in; only a file directly inside
    ///   one of them is ever deleted.
    public init(files: any ImportFileSystem, copyFolders: [URL], maximumBytes: Int, logger: any DiagnosticLogger) {
        self.files = files
        self.copyFolders = copyFolders
        self.maximumBytes = maximumBytes
        self.logger = logger
    }

    public func receive(_ url: URL) -> ReceivedFile {
        // Access first: without it the system may not even let the path be resolved or looked at
        let scoped = files.startAccess(url) ? url : nil
        return state.withLock { state -> ReceivedFile in
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
        guard let received = state.withLock({ $0.received[file.id] }) else {
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
        guard state.withLock({ $0.received[file.id] != nil }) else {
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

    /// Takes the file out of the count, and deletes its copies when it was the last one of its identity, all under the
    /// lock. Gives nil for a file not received or already released.
    private func letGo(_ file: ReceivedFile) -> Released? {
        state.withLock { state -> Released? in
            guard let received = state.received.removeValue(forKey: file.id) else { return nil }
            guard let identity = received.identity, var open = state.open[identity] else {
                return Released(scoped: received.scoped, failures: [])
            }
            open.count -= 1
            guard open.count == 0 else {
                state.open[identity] = open
                return Released(scoped: received.scoped, failures: [])
            }
            state.open.removeValue(forKey: identity)
            return Released(scoped: received.scoped, failures: deleteCopies(of: identity, at: open.paths))
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
}

import DiagnosticLogging
import Foundation
import PrestoCVImporting
import PrestoCVWorkflowPorts
import Synchronization

/// What the import's file adapter asks of the file system and of the platform's access to a chosen file. The device's is
/// `DeviceImportFiles` in the composition (R4); the tests use a real one over a temporary folder.
public protocol ImportFileSystem: Sendable {
    /// The file a URL names, however the path to it is written: symbolic links resolved, `.` and `..` removed.
    func resolve(_ url: URL) -> URL
    /// The identity of a resolved file: two received files are one file when their identities are equal.
    func identity(ofResolved url: URL) -> String
    /// Starts security-scoped access to a chosen file. True when access started, and then it is stopped once.
    func startAccess(_ url: URL) -> Bool
    func stopAccess(_ url: URL)
    func size(of url: URL) throws -> Int
    /// The bytes of the file, read into memory and not mapped: a file changed or cut while mapped can crash the app.
    func read(_ url: URL) throws -> Data
    func remove(_ url: URL) throws
}

/// The adapter of `ImportFileReading` (step 5-8d).
///
/// - `receive` resolves the file and captures its identity, once, and starts security-scoped access for that received
///   file; its `release` stops it. Each start has its own stop, as the system counts them, so two received files of one
///   file never share an access that one of them could end for the other.
/// - It counts the received files per identity. When the last one of an identity is let go, each path of it that lies in
///   the app's container is deleted: the copy the system made for "Open in", wherever it put it. A file outside the
///   container is the person's and is never touched.
/// - `readPDF(of:)` reads within the size bound, from the path `receive` captured, never from the URL read again.
///
/// The identity is captured before the lock that counts: a `receive` of a file that runs while the last `release` of the
/// same file deletes its copy would find the copy gone, and its read would fail as `fileNotRead`, never read another
/// file. The import screen calls both on the main actor, one after the other, so the two never overlap.
public final class ImportFileAdapter: ImportFileReading {
    private struct Received {
        let identity: String
        let resolved: URL
        /// The URL access started on, which is the one it stops on; nil when the system started none.
        let scoped: URL?
    }

    private struct Open {
        var count: Int
        /// Every path the file was received by, each deleted at the last release when it lies in the container.
        var paths: Set<URL>
    }

    private struct State {
        var nextID = 1
        var received: [Int: Received] = [:]
        var open: [String: Open] = [:]
    }

    private let files: any ImportFileSystem
    private let container: [String]
    private let maximumBytes: Int
    private let logger: any DiagnosticLogger
    private let state = Mutex(State())

    public init(files: any ImportFileSystem, container: URL, maximumBytes: Int, logger: any DiagnosticLogger) {
        self.files = files
        self.container = files.resolve(container).pathComponents
        self.maximumBytes = maximumBytes
        self.logger = logger
    }

    public func receive(_ url: URL) -> ReceivedFile {
        let resolved = files.resolve(url)
        let identity = files.identity(ofResolved: resolved)
        let scoped = files.startAccess(url) ? url : nil
        return state.withLock { state -> ReceivedFile in
            let id = state.nextID
            state.nextID += 1
            state.received[id] = Received(identity: identity, resolved: resolved, scoped: scoped)
            state.open[identity, default: Open(count: 0, paths: [])].count += 1
            state.open[identity]?.paths.insert(resolved)
            return ReceivedFile(id: id, url: url)
        }
    }

    public func readPDF(of file: ReceivedFile) async throws -> Data {
        guard let received = state.withLock({ $0.received[file.id] }) else {
            logger.error(.importing, "import.file.notRead", .token("reason", "notReceived"))
            throw ImportFailure.fileNotRead
        }
        try Task.checkCancellation()
        let data: Data
        do {
            guard try files.size(of: received.resolved) <= maximumBytes else { throw ImportFailure.tooLarge }
            data = try files.read(received.resolved)
        } catch let failure as ImportFailure {
            throw failure
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            logger.error(.importing, "import.file.notRead", .error(error))
            throw ImportFailure.fileNotRead
        }
        try Task.checkCancellation()
        guard data.count <= maximumBytes else { throw ImportFailure.tooLarge }
        return data
    }

    public func release(_ file: ReceivedFile) {
        guard let (received, lastOf) = letGo(file) else {
            logger.notice(.importing, "import.file.releasedAgain")
            return
        }
        // The copy goes while this file's access still holds, then the access ends
        for path in lastOf.sorted(by: { $0.path < $1.path }) {
            deleteCopy(path)
        }
        if let scoped = received.scoped { files.stopAccess(scoped) }
    }

    /// Takes the file out of the count. Gives nil for a file not received or already released, and the paths of the file
    /// when it was the last one of its identity, or none.
    private func letGo(_ file: ReceivedFile) -> (Received, lastOf: Set<URL>)? {
        state.withLock { state in
            guard let received = state.received.removeValue(forKey: file.id), var open = state.open[received.identity] else {
                return nil
            }
            open.count -= 1
            guard open.count == 0 else {
                state.open[received.identity] = open
                return (received, [])
            }
            state.open.removeValue(forKey: received.identity)
            return (received, open.paths)
        }
    }

    /// Deletes the file when it lies inside the app's container, wherever the system put it; a delete that fails is logged.
    private func deleteCopy(_ resolved: URL) {
        let path = resolved.pathComponents
        guard path.count > container.count, path.starts(with: container) else { return }
        do {
            try files.remove(resolved)
        } catch {
            logger.error(.importing, "import.file.copyNotDeleted", .error(error))
        }
    }
}

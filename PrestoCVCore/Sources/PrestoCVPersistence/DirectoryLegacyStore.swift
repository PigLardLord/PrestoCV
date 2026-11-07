import Foundation
import PrestoCVDomain
import PrestoCVApplication

/// The released app's store: `cv_<UUID>.json` files in one directory (ADR 0022). Only regular files up to a size cap are
/// read, never through a link; anything else is reported as unreadable and left where it is.
public struct DirectoryLegacyStore: LegacyStore {
    let directory: URL
    let clock: any TimeSource
    let maxFileBytes: Int

    public init(directory: URL, clock: any TimeSource, maxFileBytes: Int = 5 * 1024 * 1024) {
        self.directory = directory; self.clock = clock; self.maxFileBytes = maxFileBytes
    }

    public func records() async throws(RepositoryError) -> [LegacyRecord] {
        let names = try candidateNames()
        let fallback = Date(timeIntervalSince1970: clock.now().timeIntervalSince1970.rounded(.down))
        return names.map { LegacyRecord(key: .init(name: $0), content: content(of: $0, fallback: fallback)) }
    }

    public func remove(_ key: LegacyRecord.Key) async throws(RepositoryError) {
        let fileName = key.name
        guard Self.isCandidate(fileName) else { throw .invalidName(fileName) }
        let url = directory.appendingPathComponent(fileName)
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { return }   // already gone: nothing to remove
        catch { throw .writeFailed(file: fileName, cause: FailureCause(error)) }
    }

    // MARK: Listing

    private static func isCandidate(_ name: String) -> Bool {
        name.hasPrefix("cv_") && name.hasSuffix(".json") && !name.contains("/")
    }

    /// A directory that is not there is an empty store: the person never had the released app.
    private func candidateNames() throws(RepositoryError) -> [String] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) else { return [] }
        guard isDirectory.boolValue else { throw .storeUnavailable(.cannotList) }
        do { return try FileManager.default.contentsOfDirectory(atPath: directory.path).filter(Self.isCandidate).sorted() }
        catch { throw .storeUnavailable(.cannotList) }
    }

    // MARK: Reading

    private func content(of name: String, fallback: Date) -> LegacyContent {
        guard let data = readBounded(directory.appendingPathComponent(name)) else { return .unreadable }
        return LegacyCVFile.read(data, fileName: name, fallback: fallback)
    }

    /// The bytes of a regular file within the cap, opened without following a link; nil for anything else.
    private func readBounded(_ url: URL) -> Data? {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { return nil }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var status = stat()
        guard fstat(fd, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG, status.st_size <= maxFileBytes else { return nil }
        do { return try handle.read(upToCount: maxFileBytes + 1) } catch { return nil }
    }
}

extension FileCVRepository: LegacyImportTarget {
    /// Stores a legacy CV as revision 1 with the times it carried, once: under the store lock, a CV the ledger knows, or
    /// that the store already holds, is left as it is (`.existing`), so a CV the person deleted never comes back. The
    /// copy is made durable and read back before the ledger takes its id; a failure throws, and the importer keeps the source.
    public func adopt(_ cv: CV) async throws(RepositoryError) -> Adoption {
        try withStoreLock { () throws(RepositoryError) -> Adoption in
            var ledger = try readLedger()
            if ledger.contains(cv.id.raw) { return .existing }
            if try current(cv.id) != nil { try record(cv.id, in: &ledger); return .existing }
            let adopted = cv.adoptedAsRevisionOne
            try write(adopted)
            try makeDurable(url(cv.id))
            let readBack = try Self.verified(try current(cv.id), file: url(cv.id).lastPathComponent)
            try record(cv.id, in: &ledger)
            return .stored(readBack)
        }
    }

    /// The copy that reads back; a file that is not there after the write is a write that did not hold.
    static func verified(_ read: CV?, file: String) throws(RepositoryError) -> CV {
        guard let read else { throw .wouldNotReadBack(file: file) }
        return read
    }

    // MARK: Ledger of the adopted ids

    private var ledgerURL: URL { directory.appendingPathComponent(Self.legacyLedgerName) }

    /// The ids adopted so far; a ledger that is not there is empty, one that cannot be read throws, so no source goes.
    private func readLedger() throws(RepositoryError) -> Set<UUID> {
        let name = Self.legacyLedgerName
        let fd = open(ledgerURL.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else {
            if errno == ENOENT { return [] }
            throw .unreadable(file: name)
        }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var status = stat()
        guard fstat(fd, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG, status.st_size <= maxFileBytes else { throw .unreadable(file: name) }
        let data: Data
        do { data = try handle.read(upToCount: maxFileBytes + 1) ?? Data() } catch { throw .unreadable(file: name) }
        let texts: [String]
        do { texts = try JSONDecoder().decode([String].self, from: data) } catch { throw .corrupt(file: name) }
        var ids = Set<UUID>()
        for text in texts {
            guard let id = UUID(uuidString: text) else { throw .corrupt(file: name) }
            ids.insert(id)
        }
        return ids
    }

    /// Adds an id to the ledger: sorted, written whole and atomically, then made durable.
    private func record(_ id: CVID, in ledger: inout Set<UUID>) throws(RepositoryError) {
        ledger.insert(id.raw)
        let name = Self.legacyLedgerName
        let data: Data
        do { data = try JSONEncoder().encode(ledger.map(\.uuidString).sorted()) } catch { throw .writeFailed(file: name, cause: FailureCause(error)) }
        do { try data.write(to: ledgerURL, options: writeOptions) } catch { throw .writeFailed(file: name, cause: FailureCause(error)) }
        try makeDurable(ledgerURL)
    }

    // MARK: Durability

    /// Flushes a file and then the store directory to the disk, so a stored copy survives a power loss before its source goes.
    private func makeDurable(_ file: URL) throws(RepositoryError) {
        try Self.sync(file, isDirectory: false)
        try Self.sync(directory, isDirectory: true)
    }

    private static func sync(_ url: URL, isDirectory: Bool) throws(RepositoryError) {
        let name = isDirectory ? "store" : url.lastPathComponent
        let fd = open(url.path, O_RDONLY | O_CLOEXEC | (isDirectory ? 0 : O_NOFOLLOW))
        guard fd >= 0 else { throw .writeFailed(file: name, cause: FailureCause(domain: .posix, code: Int(errno))) }
        defer { close(fd) }
        #if canImport(Darwin)
        // F_FULLFSYNC reaches the platter; some file systems cannot, and then fsync is what there is.
        if fcntl(fd, F_FULLFSYNC) == 0 { return }
        guard errno == ENOTSUP || errno == EINVAL else { throw .writeFailed(file: name, cause: FailureCause(domain: .posix, code: Int(errno))) }
        #endif
        guard fsync(fd) == 0 else { throw .writeFailed(file: name, cause: FailureCause(domain: .posix, code: Int(errno))) }
    }
}

extension FileCVRepository {
    static let legacyLedgerName = ".legacy-imported.json"
}

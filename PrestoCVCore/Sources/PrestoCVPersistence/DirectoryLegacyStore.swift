import Foundation
#if canImport(Glibc)   // outbound adapter: platform code is allowed here (R11)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif
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
        return names.map { record(named: $0, fallback: fallback) }
    }

    /// Removes the file only while it holds exactly the bytes of `version`, read the way `records()` reads (no link, a regular
    /// file, within the cap). A file that is not there is already gone; any other file at that name is left as `.changed`.
    public func remove(_ key: LegacyRecord.Key, ifUnchanged version: LegacyRecord.Version) async throws(RepositoryError) -> LegacyRemoval {
        let fileName = key.name
        guard Self.isCandidate(fileName) else { throw .invalidName(fileName) }
        let url = directory.appendingPathComponent(fileName)
        var status = stat()
        if lstat(url.path, &status) != 0, errno == ENOENT { return .alreadyGone }
        guard let current = readBounded(url), current == version.bytes else { return .changed }
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { return .alreadyGone }
        catch { throw .writeFailed(file: fileName, cause: FailureCause(error)) }
        return .removed
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

    private func record(named name: String, fallback: Date) -> LegacyRecord {
        let key = LegacyRecord.Key(name: name)
        guard let data = readBounded(directory.appendingPathComponent(name)) else { return LegacyRecord(key: key, content: .unreadable) }
        return LegacyRecord(key: key, content: LegacyCVFile.read(data, fileName: name, fallback: fallback), version: .init(bytes: data))
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
    /// The store's erase generation, read under the lock. A store that does not exist yet is at generation 0: its first
    /// erase creates it and moves it to 1.
    public func beginImport() async throws(RepositoryError) -> ImportTicket {
        switch storeState() {
        case .absent: return ImportTicket(generation: 0)
        case .unavailable(let failure): throw .storeUnavailable(failure)
        case .present: break
        }
        return try await withStoreLock { () throws(RepositoryError) -> ImportTicket in ImportTicket(generation: try readEraseGeneration()) }
    }

    /// Stores a legacy CV as revision 1 with the times it carried, once, under the store lock, unless the store was erased
    /// since `ticket` was taken: then nothing is written and the answer is `.storeErased`. A CV becomes visible only
    /// after the ledger holds its id: the copy is staged (made durable, ignored by listing and every sweep), the id is
    /// recorded (durable), the copy is renamed into place (durable) and read back. A run a kill stopped is finished by the
    /// next one. A CV the ledger knows is `.existing` after the files that hold it are made durable again, so a person's
    /// deletion stands and a failed barrier is retried. Every step that fails throws, and the importer keeps the source.
    public func adopt(_ cv: CV, under ticket: ImportTicket) async throws(RepositoryError) -> Adoption {
        try await withStoreLock { () throws(RepositoryError) -> Adoption in
            guard try readEraseGeneration() == ticket.generation else { return .storeErased }
            var ledger = try readLedger()
            let staged = directory.appendingPathComponent(Self.stagedName(for: cv.id))
            let stored = try current(cv.id) != nil
            if ledger.contains(cv.id.raw) {
                if !stored, try Self.exists(staged) {   // a kill stopped the rename, or the ledger's barrier failed
                    try makeDurable(ledgerURL)
                    return .stored(try publish(staged, as: cv.id))
                }
                if stored { try makeDurable(url(cv.id)) }
                try makeDurable(ledgerURL)
                return .existing
            }
            if stored { try makeDurable(url(cv.id)); try record(cv.id, in: &ledger); return .existing }   // no released code makes this state
            try write(cv.adoptedAsRevisionOne, to: staged)
            try makeDurable(staged)
            try record(cv.id, in: &ledger)
            return .stored(try publish(staged, as: cv.id))
        }
    }

    /// Moves the staged copy into place, makes it durable and reads it back.
    private func publish(_ staged: URL, as id: CVID) throws(RepositoryError) -> CV {
        let name = url(id).lastPathComponent
        guard rename(staged.path, url(id).path) == 0 else { throw .writeFailed(file: name, cause: FailureCause(domain: .posix, code: Int(errno))) }
        try makeDurable(url(id))
        return try Self.verified(try current(id), file: name)
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

    // MARK: Erase generation

    /// How many times the store was erased: the size of its generation file, one byte per erase. A file that is not there is
    /// generation 0; one that cannot be read, or is not a regular file, throws, so no import goes on blind.
    func readEraseGeneration() throws(RepositoryError) -> Int {
        let name = Self.eraseGenerationName
        let fd = open(directory.appendingPathComponent(name).path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else {
            if errno == ENOENT { return 0 }
            throw .unreadable(file: name)
        }
        defer { close(fd) }
        var status = stat()
        guard fstat(fd, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG else { throw .unreadable(file: name) }
        return Int(status.st_size)
    }

    /// Moves the store to the next erase generation (one byte appended), under the lock the caller holds. An import that
    /// began before it stores nothing after it.
    func bumpEraseGeneration() throws(RepositoryError) {
        let name = Self.eraseGenerationName
        let fd = open(directory.appendingPathComponent(name).path, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw .writeFailed(file: name, cause: FailureCause(domain: .posix, code: Int(errno))) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var status = stat()
        guard fstat(fd, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG else { throw .unreadable(file: name) }
        do { try handle.write(contentsOf: Data([0x2E])) } catch { throw .writeFailed(file: name, cause: FailureCause(error)) }
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
    /// One byte per erase of the store: an import compares it before each write, so nothing it read before an erase is stored after.
    static let eraseGenerationName = ".erase-generation"
    /// The staged copy of a CV being adopted: a name that listing, quarantine and every sweep ignore (it does not end in `.cv.json`).
    static func stagedName(for id: CVID) -> String { "." + id.raw.uuidString + stagedSuffix }
    static let stagedSuffix = ".legacy-staged"
}

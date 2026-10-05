import Foundation
#if canImport(Glibc)   // outbound adapter: platform code is allowed here (PlatformAdapters)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVDomain
import PrestoCVApplication

/// The CV store on disk (ADR 0009, PersistedSchema). One file per CV, named from its identifier, in schema 1. Every mutating
/// operation holds an exclusive `flock` on the store, so revision checks hold across repository instances and
/// processes; the composition root still keeps one instance per process (ADR 0008). Waiting for the lock blocks a
/// thread of the cooperative pool: #111.
public actor FileCVRepository: CVRepository, CVStoreMaintenance {
    let directory: URL
    let clock: any TimeSource
    let maxFileBytes: Int
    var quarantine: URL { directory.appendingPathComponent("Quarantine", isDirectory: true) }

    public init(directory: URL, clock: any TimeSource, maxFileBytes: Int = 5 * 1024 * 1024) {
        self.directory = directory; self.clock = clock; self.maxFileBytes = maxFileBytes
    }

    static let uuidPattern = "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"
    /// Atomic, and on Apple platforms unreadable while the device is locked. The simulator does not apply protection.
    static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtection]
    private func url(_ id: CVID) -> URL { directory.appendingPathComponent(StoredFileName.of(id)) }

    // MARK: Locking

    private func withStoreLock<T>(_ body: () throws(RepositoryError) -> T) throws(RepositoryError) -> T {
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { throw .storeUnavailable(.cannotLock) }
        // Never through a link, and never on anything but a regular file: opening does not block.
        let fd = open(directory.appendingPathComponent(".lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw .storeUnavailable(.cannotLock) }
        defer { close(fd) }
        var status = stat()
        guard fstat(fd, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG else { throw .storeUnavailable(.cannotLock) }
        while flock(fd, LOCK_EX) != 0 {
            guard errno == EINTR else { throw .storeUnavailable(.cannotLock) }
        }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    /// Whether anything is at `url`, a link included, without following it. Only ENOENT means nothing is there.
    private static func exists(_ url: URL) throws(RepositoryError) -> Bool {
        var status = stat()
        if lstat(url.path, &status) == 0 { return true }
        guard errno == ENOENT else { throw .unreadable(file: url.lastPathComponent) }
        return false
    }

    private enum StoreState { case present, absent, unavailable(StoreFailure) }

    /// The store itself: absent before the first save; unavailable when it cannot be reached, sits behind a link whose
    /// target is gone, or is not a directory. The store may be reached through a link.
    private func storeState() -> StoreState {
        var status = stat()
        guard stat(directory.path, &status) == 0 else {
            return errno == ENOENT && !Self.passesThroughDanglingLink(directory.path) ? .absent : .unavailable(.cannotList)
        }
        return (status.st_mode & S_IFMT) == S_IFDIR ? .present : .unavailable(.notADirectory)
    }

    /// Whether `url` is a real directory, not a link to one; nil when nothing is there.
    private static func isRealDirectory(_ url: URL) -> Bool? {
        var status = stat()
        guard lstat(url.path, &status) == 0 else { return errno == ENOENT ? nil : false }
        return (status.st_mode & S_IFMT) == S_IFDIR
    }

    /// The quarantine's entries. An absent quarantine is empty; one that is not a real directory is never used.
    private func quarantineNames() throws(RepositoryError) -> [String] {
        switch Self.isRealDirectory(quarantine) {
        case nil: return []
        case false?: throw .storeUnavailable(.notADirectory)
        case true?:
            do { return try FileManager.default.contentsOfDirectory(atPath: quarantine.path) } catch { throw .storeUnavailable(.cannotList) }
        }
    }

    /// Whether the path, or one of its ancestors, is a symbolic link whose target is missing: a store that was moved
    /// away, not one that was never created.
    private static func passesThroughDanglingLink(_ path: String) -> Bool {
        var current = path
        while !current.isEmpty, current != "/" {
            var link = stat(), target = stat()
            if lstat(current, &link) == 0, (link.st_mode & S_IFMT) == S_IFLNK, stat(current, &target) != 0 { return true }
            current = (current as NSString).deletingLastPathComponent
        }
        return false
    }

    // MARK: Reading one file

    /// A stored CV, which must also carry the identifier its file is named after.
    private func read(_ u: URL, asName name: String? = nil) -> StoredCVFile {
        let file = StoredCVFile.read(u, maxBytes: maxFileBytes)
        guard case .cv(let cv) = file else { return file }
        guard (name ?? u.lastPathComponent) == StoredFileName.of(cv.id) else { return .corrupt("id does not match file name") }
        return file
    }

    private func current(_ id: CVID) throws(RepositoryError) -> CV? {
        let name = StoredFileName.of(id)
        let file = read(url(id))
        if case .absent = file {
            // Not found only in a store that can be reached; otherwise a missing store would read as a deleted CV.
            if case .unavailable(let failure) = storeState() { throw .storeUnavailable(failure) }
            return nil
        }
        return try file.requireCV(named: name)
    }

    /// Writes only what this repository will be able to read back: the encoded file must be within the size
    /// cap and must decode, through the same strict path as a read, to the same CV. Otherwise nothing is
    /// written and the previous version stays (review round 2: the writer accepted what the reader rejects).
    private func write(_ cv: CV) throws(RepositoryError) {
        let name = url(cv.id).lastPathComponent
        guard let created = cv.createdAt, let updated = cv.updatedAt else { throw .writeFailed(file: name) }
        let data: Data
        do { data = try CVFileV1(cv, createdAt: created, updatedAt: updated).encoded() } catch { throw .writeFailed(file: name) }
        guard data.count <= maxFileBytes else { throw .wouldNotReadBack(file: name) }
        do {
            guard try CVFileV1.decode(data).toDomain() == cv else { throw RepositoryError.wouldNotReadBack(file: name) }
        } catch { throw .wouldNotReadBack(file: name) }
        do { try data.write(to: url(cv.id), options: Self.writeOptions) } catch { throw .writeFailed(file: name) }
    }

    /// Timestamps are stored with whole-second precision (ISO 8601), so they are normalised before use;
    /// otherwise a fractional clock would make every write fail its read-back check.
    private func now() -> Date { Date(timeIntervalSince1970: clock.now().timeIntervalSince1970.rounded(.down)) }

    // MARK: CVRepository

    public func create(_ cv: CV) async throws(RepositoryError) -> CV {
        try withStoreLock { () throws(RepositoryError) -> CV in
            guard try current(cv.id) == nil else { throw .alreadyExists(cv.id) }
            let stored = cv.stored(revision: 1, at: now()); try write(stored); return stored
        }
    }

    public func update(_ cv: CV) async throws(RepositoryError) -> CV {
        try withStoreLock { () throws(RepositoryError) -> CV in
            guard let existing = try current(cv.id) else { throw .notFound(cv.id) }
            guard existing.revision == cv.revision else { throw .conflict(cv.id, storedRevision: existing.revision) }
            var written = cv.stored(revision: cv.revision + 1, at: now())
            written.createdAt = existing.createdAt
            try write(written)
            return try current(cv.id) ?? written
        }
    }

    /// A CV is loaded by an identifier from a listing, so a store that is not there at all is unavailable: its CVs
    /// were not deleted one by one. Only a listing reads a missing store as a first run.
    public func load(_ id: CVID) async throws(RepositoryError) -> CV {
        guard let cv = try current(id) else {
            switch storeState() {
            case .present: throw .notFound(id)
            case .absent: throw .storeUnavailable(.cannotList)
            case .unavailable(let failure): throw .storeUnavailable(failure)
            }
        }
        return cv
    }

    public func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {
        try withStoreLock { () throws(RepositoryError) in
            guard let existing = try current(id) else { throw .notFound(id) }
            guard existing.revision == revision else { throw .conflict(id, storedRevision: existing.revision) }
            do { try FileManager.default.removeItem(at: url(id)) } catch { throw .writeFailed(file: url(id).lastPathComponent) }
        }
    }

    public func list() async throws(RepositoryError) -> CVListing {
        // Only a store that does not exist yet means "empty" (first run). Anything else is an error: a store that
        // cannot be reached, or one behind a link whose target is gone. The store itself may be reached through a link.
        switch storeState() {
        case .absent: return CVListing(cvs: [], issues: [])
        case .unavailable(let failure): throw .storeUnavailable(failure)
        case .present: break
        }
        return try withStoreLock { () throws(RepositoryError) -> CVListing in
            let files: [URL]
            do { files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) }
            catch { throw .storeUnavailable(.cannotList) }
            var cvs: [CV] = [], issues: [StoreIssue] = []
            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.lastPathComponent.hasSuffix(StoredFileName.suffix) {
                let name = file.lastPathComponent
                switch read(file) {
                case .absent: continue                                   // removed since the directory was listed
                case .cv(let cv): cvs.append(cv)
                case .newer(let v): issues.append(.upgradeRequired(file: name, version: v))
                case .unreadable: issues.append(.unreadable(file: name))
                case .tooLarge(let n): issues.append(.tooLarge(file: name, bytes: n))
                case .corrupt(let reason):
                    issues.append(moveToQuarantine(file) ? .corrupt(file: name, reason: reason) : .quarantineFailed(file: name))
                }
            }
            return CVListing(cvs: cvs.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }, issues: issues)
        }
    }

    /// Moves a corrupt file into the quarantine, which must be a real directory of the store, never a link.
    private func moveToQuarantine(_ file: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: quarantine, withIntermediateDirectories: true)
            guard Self.isRealDirectory(quarantine) == true else { return false }
            // The retention period starts now: the file's own modification time says nothing about when it was isolated.
            try FileManager.default.setAttributes([.modificationDate: now()], ofItemAtPath: file.path)
            var target = quarantine.appendingPathComponent(file.lastPathComponent)
            var n = 1
            while FileManager.default.fileExists(atPath: target.path) {
                target = quarantine.appendingPathComponent("\(n)~" + file.lastPathComponent); n += 1   // "~" never occurs in a UUID
            }
            try FileManager.default.moveItem(at: file, to: target)
            return true
        } catch { return false }
    }

    // MARK: CVStoreMaintenance

    public func restore(quarantined name: String) async throws(RepositoryError) -> CV {
        // The name is validated in full, so it cannot leave the quarantine folder.
        guard name.range(of: "^(\\d+~)?" + Self.uuidPattern + "\\.cv\\.json\\z", options: .regularExpression) != nil else {
            throw .invalidName(name)
        }
        return try withStoreLock { () throws(RepositoryError) -> CV in
            if Self.isRealDirectory(quarantine) == false { throw .storeUnavailable(.notADirectory) }
            let source = quarantine.appendingPathComponent(name)
            let original = name.replacingOccurrences(of: #"^\d+~"#, with: "", options: .regularExpression)
            let target = directory.appendingPathComponent(original)
            guard source.deletingLastPathComponent().standardizedFileURL == quarantine.standardizedFileURL else { throw .invalidName(name) }
            guard let uuid = UUID(uuidString: String(original.prefix(36))) else { throw .invalidName(name) }
            guard !FileManager.default.fileExists(atPath: target.path) else { throw .alreadyExists(CVID(uuid)) }
            let cv = try read(source, asName: original).requireCV(named: name)
            do { try FileManager.default.moveItem(at: source, to: target) } catch { throw .writeFailed(file: original) }
            return cv
        }
    }

    public func erase(_ id: CVID) async throws(RepositoryError) {
        try withStoreLock { () throws(RepositoryError) in
            let name = StoredFileName.of(id)
            var victims = [directory.appendingPathComponent(name)]
            let quarantined = try quarantineNames()
            victims += quarantined.filter { $0 == name || $0.hasSuffix("~" + name) }.map { quarantine.appendingPathComponent($0) }
            for v in victims {
                guard try Self.exists(v) else { continue }
                do { try FileManager.default.removeItem(at: v) } catch { throw .writeFailed(file: v.lastPathComponent) }
            }
        }
    }

    /// A file's age in the quarantine counts from when it entered it: quarantining stamps it with the clock.
    public func purgeQuarantine(olderThan date: Date) async throws(RepositoryError) -> Int {
        try withStoreLock { () throws(RepositoryError) -> Int in
            var removed = 0
            for n in try quarantineNames() {
                let u = quarantine.appendingPathComponent(n)
                let modified: Date?
                do { modified = try FileManager.default.attributesOfItem(atPath: u.path)[.modificationDate] as? Date } catch { throw .unreadable(file: n) }
                guard let modified, modified < date else { continue }
                do { try FileManager.default.removeItem(at: u); removed += 1 } catch { throw .writeFailed(file: n) }
            }
            return removed
        }
    }
}

import Foundation
import PrestoCVApplication
import PrestoCVDomain

/// The CV store on disk (ADR 0009, PersistedSchema). One file per CV, named from its identifier, in schema 1. Every mutating
/// operation holds an exclusive lock on the store, so revision checks hold across repository instances and processes;
/// the composition root still keeps one instance per process (ADR 0008).
public actor FileCVRepository: CVRepository, CVStoreMaintenance {
    /// Atomic, and on Apple platforms unreadable while the device is locked. The simulator does not apply protection.
    static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtection]

    private let directory: URL
    private let clock: any TimeSource
    private let maxFileBytes: Int
    private let lock: StoreLock
    private let quarantine: Quarantine

    /// - Parameters:
    ///   - directory: The store. It is created on the first write.
    ///   - clock: Where the timestamps of created and updated CVs come from.
    ///   - maxFileBytes: The largest file the store writes or reads. A larger one is reported, never read.
    public init(directory: URL, clock: any TimeSource, maxFileBytes: Int = 5 * 1024 * 1024) {
        self.directory = directory; self.clock = clock; self.maxFileBytes = maxFileBytes
        lock = StoreLock(directory: directory); quarantine = Quarantine(storeDirectory: directory)
    }

    // MARK: CVRepository

    public func create(_ cv: CV) async throws(RepositoryError) -> CV {
        try lock.withExclusiveAccess { () throws(RepositoryError) -> CV in
            guard try storedCV(cv.id) == nil else { throw .alreadyExists(cv.id) }
            let stored = cv.stored(revision: 1, at: now())
            try write(stored)
            return stored
        }
    }

    public func update(_ cv: CV) async throws(RepositoryError) -> CV {
        try lock.withExclusiveAccess { () throws(RepositoryError) -> CV in
            guard let existing = try storedCV(cv.id) else { throw .notFound(cv.id) }
            guard existing.revision == cv.revision else { throw .conflict(cv.id, storedRevision: existing.revision) }
            var written = cv.stored(revision: cv.revision + 1, at: now())
            written.createdAt = existing.createdAt
            try write(written)
            return try storedCV(cv.id) ?? written
        }
    }

    public func load(_ id: CVID) async throws(RepositoryError) -> CV {
        guard let cv = try storedCV(id) else { throw StoreState(of: directory).failureToLoad(id) }
        return cv
    }

    public func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {
        try lock.withExclusiveAccess { () throws(RepositoryError) in
            guard let existing = try storedCV(id) else { throw .notFound(id) }
            guard existing.revision == revision else { throw .conflict(id, storedRevision: existing.revision) }
            try StoreFiles.remove(url(of: id))
        }
    }

    public func list() async throws(RepositoryError) -> CVListing {
        // Only a store that does not exist yet means "empty" (first run). Anything else is an error: a store that cannot be
        // reached, or one behind a link whose target is gone.
        switch StoreState(of: directory) {
        case .absent: return CVListing(cvs: [], issues: [])
        case .unavailable(let failure): throw .storeUnavailable(failure)
        case .present: return try lock.withExclusiveAccess { () throws(RepositoryError) -> CVListing in try listQuarantiningCorruptFiles() }
        }
    }

    // MARK: CVStoreMaintenance

    public func restore(quarantined name: String) async throws(RepositoryError) -> CV {
        guard let quarantined = QuarantinedName(name) else { throw .invalidName(name) }
        return try lock.withExclusiveAccess { () throws(RepositoryError) -> CV in try restoreFile(quarantined) }
    }

    public func erase(_ id: CVID) async throws(RepositoryError) {
        try lock.withExclusiveAccess { () throws(RepositoryError) in
            let copies = try [url(of: id)] + quarantine.copies(of: StoredFileName.of(id))
            for copy in copies { try StoreFiles.removeIfPresent(copy) }
        }
    }

    public func purgeQuarantine(olderThan date: Date) async throws(RepositoryError) -> Int {
        try lock.withExclusiveAccess { () throws(RepositoryError) -> Int in try quarantine.purge(olderThan: date) }
    }

    // MARK: Reading

    private func url(of id: CVID) -> URL { directory.appendingPathComponent(StoredFileName.of(id)) }

    /// A stored CV, which must also carry the identifier its file is named after.
    private func read(_ url: URL, named name: String) -> StoredCVFile {
        let file = StoredCVFile.read(url, maxBytes: maxFileBytes)
        if case .cv(let cv) = file, name != StoredFileName.of(cv.id) { return .corrupt("id does not match file name") }
        return file
    }

    private func storedCV(_ id: CVID) throws(RepositoryError) -> CV? {
        let name = StoredFileName.of(id)
        let file = read(url(of: id), named: name)
        if case .absent = file {
            // Not found only in a store that can be reached; otherwise a missing store would read as a deleted CV.
            if case .unavailable(let failure) = StoreState(of: directory) { throw .storeUnavailable(failure) }
            return nil
        }
        return try file.requireCV(named: name)
    }

    private func listQuarantiningCorruptFiles() throws(RepositoryError) -> CVListing {
        var cvs: [CV] = [], issues: [StoreIssue] = []
        for url in try storedFileURLs() {
            let file = read(url, named: url.lastPathComponent)
            if case .cv(let cv) = file { cvs.append(cv) }
            else if let issue = file.issue(named: url.lastPathComponent) { issues.append(quarantineIfCorrupt(issue, at: url)) }
        }
        return CVListing(cvs: cvs.mostRecentlyChangedFirst(), issues: issues)
    }

    private func storedFileURLs() throws(RepositoryError) -> [URL] {
        let files: [URL]
        do { files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) } catch { throw .storeUnavailable(.cannotList) }
        return files.filter { $0.lastPathComponent.hasSuffix(StoredFileName.suffix) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// A corrupt file is moved aside so it is not read again. When that fails it stays, and the listing says so.
    private func quarantineIfCorrupt(_ issue: StoreIssue, at url: URL) -> StoreIssue {
        guard case .corrupt = issue else { return issue }
        do throws(Quarantine.Failed) {
            try quarantine.admit(url, at: now())
            return issue
        } catch {
            return .quarantineFailed(file: url.lastPathComponent)
        }
    }

    private func restoreFile(_ name: QuarantinedName) throws(RepositoryError) -> CV {
        try quarantine.requireUsable()
        let source = try quarantine.file(name)
        let target = directory.appendingPathComponent(name.storedName)
        guard !FileManager.default.fileExists(atPath: target.path) else { throw .alreadyExists(name.id) }
        let cv = try read(source, named: name.storedName).requireCV(named: name.value)
        do { try FileManager.default.moveItem(at: source, to: target) } catch { throw .writeFailed(file: name.storedName) }
        return cv
    }

    // MARK: Writing

    /// Writes only what this repository will be able to read back, so the previous version stays when it would not.
    private func write(_ cv: CV) throws(RepositoryError) {
        let name = StoredFileName.of(cv.id)
        let data = try encodedFile(of: cv, named: name)
        try requireReadsBack(data, as: cv, named: name)
        do { try data.write(to: url(of: cv.id), options: Self.writeOptions) } catch { throw .writeFailed(file: name) }
    }

    private func encodedFile(of cv: CV, named name: String) throws(RepositoryError) -> Data {
        guard let created = cv.createdAt, let updated = cv.updatedAt else { throw .writeFailed(file: name) }
        do { return try CVFileV1(cv, createdAt: created, updatedAt: updated).encoded() } catch { throw .writeFailed(file: name) }
    }

    /// The encoded file must be within the size cap and must decode, through the same strict path as a read, to the same CV.
    private func requireReadsBack(_ data: Data, as cv: CV, named name: String) throws(RepositoryError) {
        guard data.count <= maxFileBytes else { throw .wouldNotReadBack(file: name) }
        do {
            guard try CVFileV1.decode(data).toDomain() == cv else { throw RepositoryError.wouldNotReadBack(file: name) }
        } catch {
            throw .wouldNotReadBack(file: name)
        }
    }

    /// Timestamps are stored with whole-second precision (ISO 8601), so they are normalised before use; otherwise a
    /// fractional clock would make every write fail its read-back check.
    private func now() -> Date { Date(timeIntervalSince1970: clock.now().timeIntervalSince1970.rounded(.down)) }
}

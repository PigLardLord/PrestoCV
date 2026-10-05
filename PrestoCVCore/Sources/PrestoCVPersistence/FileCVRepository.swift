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

    /// Stores a never-saved CV as revision 1, stamped with the clock's time.
    ///
    /// - Throws: `RepositoryError.alreadyExists` when a file of that identity is stored, `.wouldNotReadBack` when the file
    ///   would exceed the size cap or would not read back, `.writeFailed` or `.storeUnavailable` when the store cannot be
    ///   written, and the read errors of an existing file that cannot be read.
    public func create(_ cv: CV) async throws(RepositoryError) -> CV {
        try lock.withExclusiveAccess { () throws(RepositoryError) -> CV in
            guard try storedCV(cv.id) == nil else { throw .alreadyExists(cv.id) }
            let stored = cv.stored(revision: 1, at: now())
            try write(stored)
            return stored
        }
    }

    /// Replaces the stored CV, which must be at `cv.revision`, and returns it one revision later with a new update time.
    ///
    /// - Throws: `RepositoryError.notFound` when the CV is not stored, `.conflict` when it is stored at another revision,
    ///   and the errors of `create(_:)` for the write.
    public func update(_ cv: CV) async throws(RepositoryError) -> CV {
        try lock.withExclusiveAccess { () throws(RepositoryError) -> CV in
            guard let existing = try storedCV(cv.id) else { throw .notFound(cv.id) }
            guard existing.revision == cv.revision else { throw .conflict(cv.id, storedRevision: existing.revision) }
            let written = cv.stored(revision: cv.revision + 1, createdAt: existing.createdAt, updatedAt: now())
            try write(written)
            return try storedCV(cv.id) ?? written
        }
    }

    /// Loads the stored CV.
    ///
    /// - Throws: `RepositoryError.notFound` when the store is there and holds no such CV, `.storeUnavailable` when the store
    ///   is not there or cannot be reached, and `.corrupt`, `.unreadable`, `.upgradeRequired` or `.tooLarge` for the file.
    public func load(_ id: CVID) async throws(RepositoryError) -> CV {
        guard let cv = try storedCV(id) else { throw StoreState(of: directory).failureToLoad(id) }
        return cv
    }

    /// Deletes the stored CV if it is at `revision`.
    ///
    /// - Throws: `RepositoryError.notFound` when the CV is not stored, `.conflict` when it is stored at another revision,
    ///   `.writeFailed` when the file cannot be removed, and the read errors of `load(_:)`.
    public func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {
        try lock.withExclusiveAccess { () throws(RepositoryError) in
            guard let existing = try storedCV(id) else { throw .notFound(id) }
            guard existing.revision == revision else { throw .conflict(id, storedRevision: existing.revision) }
            try StoreFiles.remove(url(of: id))
        }
    }

    /// Lists the healthy CVs, most recently changed first, and an issue for every other file. A corrupt file is moved to the
    /// quarantine as it is found. A store that does not exist yet lists as empty.
    ///
    /// - Throws: `RepositoryError.storeUnavailable` when the store exists but cannot be reached or listed. A file that cannot
    ///   be read is an issue of the listing, never a failure.
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

    /// Moves a quarantined file back into the store, once it passes the checks of a read.
    ///
    /// - Parameter name: The file's name in the quarantine.
    /// - Throws: `RepositoryError.invalidName` when `name` is not a quarantined file's, `.alreadyExists` when a CV of that
    ///   name is stored, `.storeUnavailable` when the quarantine is not a directory, `.writeFailed` when the move fails, and
    ///   the read errors of `load(_:)` for the file, `.unreadable` among them when it is not there.
    public func restore(quarantined name: String) async throws(RepositoryError) -> CV {
        guard let quarantined = QuarantinedName(name) else { throw .invalidName(name) }
        return try lock.withExclusiveAccess { () throws(RepositoryError) -> CV in try restoreFile(quarantined) }
    }

    /// Removes every copy of the CV: the stored file, whatever its schema, and its quarantined copies.
    ///
    /// - Throws: `RepositoryError.storeUnavailable` when the quarantine is not a directory, `.unreadable` when a copy cannot
    ///   be inspected, and `.writeFailed` when one cannot be removed.
    public func erase(_ id: CVID) async throws(RepositoryError) {
        try lock.withExclusiveAccess { () throws(RepositoryError) in
            let copies = try [url(of: id)] + quarantine.copies(of: StoredFileName.of(id))
            for copy in copies { try StoreFiles.removeIfPresent(copy) }
        }
    }

    /// Removes the quarantined files that entered the quarantine before `date`, and returns how many.
    ///
    /// - Throws: `RepositoryError.storeUnavailable` when the quarantine is not a directory, `.unreadable` when a file cannot
    ///   be inspected, and `.writeFailed` when one cannot be removed.
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
            let name = url.lastPathComponent
            switch read(url, named: name) {
            case .absent: continue   // removed since the directory was listed
            case .cv(let cv): cvs.append(cv)
            case .corrupt(let reason): issues.append(isolateCorruptFile(url, because: reason))
            case .newer(let version): issues.append(.upgradeRequired(file: name, version: version))
            case .unreadable: issues.append(.unreadable(file: name))
            case .tooLarge(let bytes): issues.append(.tooLarge(file: name, bytes: bytes))
            }
        }
        return CVListing(cvs: cvs.mostRecentlyChangedFirst(), issues: issues)
    }

    private func storedFileURLs() throws(RepositoryError) -> [URL] {
        let files: [URL]
        do { files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) } catch { throw .storeUnavailable(.cannotList) }
        return files.filter { $0.lastPathComponent.hasSuffix(StoredFileName.suffix) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Moves a corrupt file aside so it is not read again, and says what became of it: corrupt and restorable, or corrupt and
    /// still where it was because the quarantine could not take it.
    private func isolateCorruptFile(_ url: URL, because reason: String) -> StoreIssue {
        let name = url.lastPathComponent
        do throws(RepositoryError) {
            try quarantine.admit(url, stampedWith: now)
            return .corrupt(file: name, reason: reason)
        } catch {
            return .quarantineFailed(file: name)
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

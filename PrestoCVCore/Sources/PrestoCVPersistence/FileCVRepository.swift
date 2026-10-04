import Foundation
import PrestoCVDomain
import PrestoCVApplication

/// The CV store on disk (ADR 0009, R12). One file per CV, named from its identifier, in schema 1. Every mutating
/// operation holds an exclusive `flock` on the store, so revision checks hold across repository instances and
/// processes; the composition root still keeps one instance per process (ADR 0008). Waiting for the lock blocks a
/// thread of the cooperative pool: #111.
public actor FileCVRepository: CVRepository, CVStoreMaintenance {
    private let store: StoreDirectory<RepositoryError>

    public init(directory: URL, clock: any TimeSource, maxFileBytes: Int = 5 * 1024 * 1024) {
        store = StoreDirectory(directory: directory, clock: clock, maxFileBytes: maxFileBytes)
    }

    static let suffix = ".cv.json"
    private func url(_ id: CVID) -> URL { store.directory.appendingPathComponent(id.raw.uuidString + Self.suffix) }

    // MARK: Reading one file

    /// A stored CV, which must also carry the identifier its file is named after.
    private func read(_ u: URL, asName name: String? = nil) -> StoredFile<CV> {
        let file = StoredFile<CV>.read(u, maxBytes: store.maxFileBytes, supportedVersion: CVFileV1.version, decode: CVFileV1.read)
        guard case .value(let cv) = file else { return file }
        guard (name ?? u.lastPathComponent) == cv.id.raw.uuidString + Self.suffix else { return .corrupt("id does not match file name") }
        return file
    }

    private func current(_ id: CVID) throws(RepositoryError) -> CV? { try store.current(url(id), read: { read($0) }) }

    /// Writes only what this repository will be able to read back: the encoded file must be within the size
    /// cap and must decode, through the same strict path as a read, to the same CV.
    private func write(_ cv: CV) throws(RepositoryError) {
        let name = url(cv.id).lastPathComponent
        guard let created = cv.createdAt, let updated = cv.updatedAt else { throw .writeFailed(file: name) }
        try store.write(name, encoded: { try CVFileV1(cv, createdAt: created, updatedAt: updated).encoded() },
                        readsBack: { data in try CVFileV1.read(data) == cv })
    }

    // MARK: CVRepository

    public func create(_ cv: CV) async throws(RepositoryError) -> CV {
        try store.withLock { () throws(RepositoryError) -> CV in
            guard try current(cv.id) == nil else { throw .alreadyExists(cv.id) }
            let stored = cv.stored(revision: 1, at: store.now()); try write(stored); return stored
        }
    }

    public func update(_ cv: CV) async throws(RepositoryError) -> CV {
        try store.withLock { () throws(RepositoryError) -> CV in
            guard let existing = try current(cv.id) else { throw .notFound(cv.id) }
            guard existing.revision == cv.revision else { throw .conflict(cv.id, storedRevision: existing.revision) }
            let stored = cv.stored(revision: cv.revision + 1, at: store.now())
            let written = CV(id: stored.id, revision: stored.revision, createdAt: existing.createdAt, updatedAt: stored.updatedAt, title: stored.title,
                             personal: stored.personal, sections: stored.sections, design: stored.design, language: stored.language)
            try write(written)
            return try current(cv.id) ?? written
        }
    }

    /// A CV is loaded by an identifier from a listing, so a store that is not there at all is unavailable: its CVs
    /// were not deleted one by one. Only a listing reads a missing store as a first run.
    public func load(_ id: CVID) async throws(RepositoryError) -> CV {
        guard let cv = try current(id) else {
            switch store.state() {
            case .present: throw .notFound(id)
            case .absent: throw .storeUnavailable(.cannotList)
            case .unavailable(let failure): throw .storeUnavailable(failure)
            }
        }
        return cv
    }

    public func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {
        try store.withLock { () throws(RepositoryError) in
            guard let existing = try current(id) else { throw .notFound(id) }
            guard existing.revision == revision else { throw .conflict(id, storedRevision: existing.revision) }
            do { try FileManager.default.removeItem(at: url(id)) } catch { throw .writeFailed(file: url(id).lastPathComponent) }
        }
    }

    public func list() async throws(RepositoryError) -> CVListing {
        // Only a store that does not exist yet means "empty" (first run). Anything else is an error: a store that
        // cannot be reached, or one behind a link whose target is gone. The store itself may be reached through a link.
        switch store.state() {
        case .absent: return CVListing(cvs: [], issues: [])
        case .unavailable(let failure): throw .storeUnavailable(failure)
        case .present: break
        }
        return try store.withLock { () throws(RepositoryError) -> CVListing in
            let found = try store.scan(suffix: Self.suffix, read: { read($0) })
            return CVListing(cvs: found.values.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }, issues: found.issues)
        }
    }

    // MARK: CVStoreMaintenance

    public func restore(quarantined name: String) async throws(RepositoryError) -> CV {
        try store.restore(quarantined: name, pattern: StoreNames.uuidPattern + "\\.cv\\.json",
                          taken: { original in UUID(uuidString: String(original.prefix(36))).map { .alreadyExists(CVID($0)) } },
                          read: { source, original in read(source, asName: original) })
    }

    public func erase(_ id: CVID) async throws(RepositoryError) {
        try store.withLock { () throws(RepositoryError) in try store.eraseCopies(of: id.raw.uuidString + Self.suffix) }
    }

    public func purgeQuarantine(olderThan date: Date) async throws(RepositoryError) -> Int {
        try store.purgeQuarantine(olderThan: date)
    }
}

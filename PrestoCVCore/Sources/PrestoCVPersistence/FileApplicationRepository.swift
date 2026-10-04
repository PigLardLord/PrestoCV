import Foundation
import PrestoCVDomain
import PrestoCVApplication

/// The application store on disk (ADR 0019, ADR 0009, R12). It gives an application every guarantee that `FileCVRepository`
/// gives a CV: one file per application, named from its identifier, in schema 1, in a directory of its own with its own lock
/// and its own `Quarantine/`; every outcome of R12; atomic writes that must read back; and every mutation under an exclusive
/// `flock`, so revision checks hold across repository instances and processes. The composition root keeps one instance per
/// process (ADR 0008). Waiting for the lock blocks a thread of the cooperative pool: #111.
///
/// The CV inside an application is part of its file, so the application's revision and times are the CV's, and erasing an
/// application erases the CV with it. Erasing a CV does not erase the applications made from it. Create is fail-open: it reads the
/// job of each file it can, so restoring a repaired file can bring back a second application for a job, and per-job uniqueness
/// holds for create only.
public actor FileApplicationRepository: ApplicationRepository, ApplicationStoreMaintenance {
    private let store: StoreDirectory<ApplicationRepositoryError>

    public init(directory: URL, clock: any TimeSource, maxFileBytes: Int = 5 * 1024 * 1024) {
        store = StoreDirectory(directory: directory, clock: clock, maxFileBytes: maxFileBytes)
    }

    static let suffix = ".application.json"
    private func url(_ id: ApplicationID) -> URL { store.directory.appendingPathComponent(id.raw.uuidString + Self.suffix) }

    // MARK: Reading one file

    /// A stored application, which must also carry the identifier its file is named after.
    private func read(_ u: URL, asName name: String? = nil) -> StoredFile<Application> {
        let file = StoredFile<Application>.read(u, maxBytes: store.maxFileBytes, supportedVersion: ApplicationFileV1.version, decode: ApplicationFileV1.read)
        guard case .value(let application) = file else { return file }
        guard (name ?? u.lastPathComponent) == application.id.raw.uuidString + Self.suffix else { return .corrupt("id does not match file name") }
        return file
    }

    private func current(_ id: ApplicationID) throws(ApplicationRepositoryError) -> Application? { try store.current(url(id), read: { read($0) }) }

    /// The application kept for a job, if the store holds one that it can read. Each file is peeked for its job alone, and only
    /// a file that names the job is read strictly, so keeping a result costs a pass over the store, not a strict read of every
    /// application. A file that cannot be read, or that names the job and fails the strict read, says nothing about its job:
    /// it is reported by the listing, and keeping a result is never refused because of another file. Call it under the lock;
    /// it moves nothing.
    private func kept(for job: JobID) throws(ApplicationRepositoryError) -> Application? {
        for file in try store.entries(suffix: Self.suffix) {
            let peeked = StoredFile<String>.read(file, maxBytes: store.maxFileBytes, supportedVersion: ApplicationFileV1.version, decode: ApplicationFileV1.peekJob)
            guard case .value(let named) = peeked, named == job.raw else { continue }
            if case .value(let application) = read(file), application.provenance.jobID == job { return application }
        }
        return nil
    }

    /// Writes only what this repository will be able to read back: the encoded file must be within the size cap and must
    /// decode, through the same strict path as a read, to the same application.
    private func write(_ application: Application) throws(ApplicationRepositoryError) {
        let name = url(application.id).lastPathComponent
        guard let created = application.createdAt, let updated = application.updatedAt else { throw .writeFailed(file: name) }
        try store.write(name, encoded: { try ApplicationFileV1(application, createdAt: created, updatedAt: updated).encoded() },
                        readsBack: { data in try ApplicationFileV1.read(data) == application })
    }

    // MARK: ApplicationRepository

    public func create(_ application: Application) async throws(ApplicationRepositoryError) -> Application {
        try store.withLock { () throws(ApplicationRepositoryError) -> Application in
            if let existing = try kept(for: application.provenance.jobID) { return existing }
            guard try current(application.id) == nil else { throw .alreadyExists(application.id) }
            let stored = application.stored(revision: 1, at: store.now()); try write(stored); return stored
        }
    }

    public func update(_ application: Application) async throws(ApplicationRepositoryError) -> Application {
        try store.withLock { () throws(ApplicationRepositoryError) -> Application in
            guard let existing = try current(application.id) else { throw .notFound(application.id) }
            guard existing.revision == application.revision else { throw .conflict(application.id, storedRevision: existing.revision) }
            let written = application.stamped(revision: application.revision + 1, createdAt: existing.createdAt, updatedAt: store.now())
            try write(written)
            return try current(application.id) ?? written
        }
    }

    /// An application is loaded by an identifier from a listing, so a store that is not there at all is unavailable: its
    /// applications were not deleted one by one. Only a listing reads a missing store as a first run.
    public func load(_ id: ApplicationID) async throws(ApplicationRepositoryError) -> Application {
        guard let application = try current(id) else {
            switch store.state() {
            case .present: throw .notFound(id)
            case .absent: throw .storeUnavailable(.cannotList)
            case .unavailable(let failure): throw .storeUnavailable(failure)
            }
        }
        return application
    }

    public func delete(_ id: ApplicationID, revision: Int) async throws(ApplicationRepositoryError) {
        try store.withLock { () throws(ApplicationRepositoryError) in
            guard let existing = try current(id) else { throw .notFound(id) }
            guard existing.revision == revision else { throw .conflict(id, storedRevision: existing.revision) }
            do { try FileManager.default.removeItem(at: url(id)) } catch { throw .writeFailed(file: url(id).lastPathComponent) }
        }
    }

    public func list() async throws(ApplicationRepositoryError) -> ApplicationListing {
        // Only a store that does not exist yet means "empty" (first run). Anything else is an error: a store that
        // cannot be reached, or one behind a link whose target is gone. The store itself may be reached through a link.
        switch store.state() {
        case .absent: return ApplicationListing(applications: [], issues: [])
        case .unavailable(let failure): throw .storeUnavailable(failure)
        case .present: break
        }
        return try store.withLock { () throws(ApplicationRepositoryError) -> ApplicationListing in
            let found = try store.scan(suffix: Self.suffix, read: { read($0) })
            return ApplicationListing(applications: found.values.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }, issues: found.issues)
        }
    }

    // MARK: ApplicationStoreMaintenance

    public func restore(quarantined name: String) async throws(ApplicationRepositoryError) -> Application {
        try store.restore(quarantined: name, pattern: StoreNames.uuidPattern + "\\.application\\.json",
                          taken: { original in UUID(uuidString: String(original.prefix(36))).map { .alreadyExists(ApplicationID($0)) } },
                          read: { source, original in read(source, asName: original) })
    }

    public func erase(_ id: ApplicationID) async throws(ApplicationRepositoryError) {
        try store.withLock { () throws(ApplicationRepositoryError) in try store.eraseCopies(of: id.raw.uuidString + Self.suffix) }
    }

    public func purgeQuarantine(olderThan date: Date) async throws(ApplicationRepositoryError) -> Int {
        try store.purgeQuarantine(olderThan: date)
    }
}

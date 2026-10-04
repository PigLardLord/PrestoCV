import Foundation
import PrestoCVDomain

// MARK: - Applications (ADR 0019). Outbound ports, owned by the layer that needs them (R3). Like CVRepository, they are
// atomic within the store's serialisation boundary, across instances and processes, and are not cancellable.

public protocol ApplicationRepository: Sendable {
    /// Stores a never-saved application (revision 0) as revision 1, with its CV at the same revision. For a job that the
    /// store already holds an application for, it returns that application and stores nothing: the repository checks the job's
    /// identifier under its lock, so two creates for one job leave one application. Fails with `alreadyExists` when the
    /// identifier is taken by an application of another job.
    func create(_ application: Application) async throws(ApplicationRepositoryError) -> Application
    /// Replaces the stored application only if its revision equals `application.revision`; returns it at revision + 1. The
    /// CV and the letter share that revision.
    func update(_ application: Application) async throws(ApplicationRepositoryError) -> Application
    func load(_ id: ApplicationID) async throws(ApplicationRepositoryError) -> Application
    /// Healthy applications, most recently changed first, plus every issue found. Never fails because of one file.
    func list() async throws(ApplicationRepositoryError) -> ApplicationListing
    func delete(_ id: ApplicationID, revision: Int) async throws(ApplicationRepositoryError)
}

/// Recovery and erasure of applications, reachable from the UI (quarantine review, "delete everything about this application").
public protocol ApplicationStoreMaintenance: Sendable {
    func restore(quarantined name: String) async throws(ApplicationRepositoryError) -> Application
    /// Removes every copy of an application: the stored file whatever its schema, and quarantined copies (GDPR erasure).
    func erase(_ id: ApplicationID) async throws(ApplicationRepositoryError)
    /// Deletes quarantined files older than `date`. Returns how many were removed.
    func purgeQuarantine(olderThan date: Date) async throws(ApplicationRepositoryError) -> Int
}

public struct ApplicationListing: Sendable, Equatable {
    public var applications: [Application], issues: [StoreIssue]
    public init(applications: [Application], issues: [StoreIssue]) { self.applications = applications; self.issues = issues }
}

/// No paths or free-form strings: file names only, and coded failures (R7).
public enum ApplicationRepositoryError: Error, Equatable, Sendable {
    case notFound(ApplicationID), alreadyExists(ApplicationID), conflict(ApplicationID, storedRevision: Int)
    case corrupt(file: String), unreadable(file: String), upgradeRequired(file: String, version: Int), tooLarge(file: String)
    case invalidName(String), storeUnavailable(StoreFailure), writeFailed(file: String)
    /// Refused before writing: the file would exceed the size cap, or would not read back (the previous version is kept).
    case wouldNotReadBack(file: String)
}

// MARK: - The person's letter defaults (ADR 0019)

/// Where the person's letter defaults are kept: one value, with a revision that a save is conditional on. Defaults never saved
/// are `StoredLetterDefaults.unsaved`, but a store that cannot be read is an error, never empty defaults (R7). Not cancellable.
public protocol LetterDefaultsStore: Sendable {
    func load() async throws(LetterDefaultsError) -> StoredLetterDefaults
    /// Stores the defaults only if the stored revision equals `expectedRevision`; returns them at revision + 1. The first save
    /// expects revision 0, that is, no file.
    func save(_ defaults: LetterDefaults, expectedRevision: Int) async throws(LetterDefaultsError) -> StoredLetterDefaults
    /// Removes every copy of the defaults: the stored file whatever its schema, and quarantined copies (GDPR erasure).
    func erase() async throws(LetterDefaultsError)
}

/// Recovery of the letter defaults from the quarantine, reachable from the UI.
public protocol LetterDefaultsMaintenance: Sendable {
    func restore(quarantined name: String) async throws(LetterDefaultsError) -> StoredLetterDefaults
    /// Deletes quarantined files older than `date`. Returns how many were removed.
    func purgeQuarantine(olderThan date: Date) async throws(LetterDefaultsError) -> Int
}

/// No paths or free-form strings: file names only, and coded failures (R7).
public enum LetterDefaultsError: Error, Equatable, Sendable {
    case conflict(storedRevision: Int), alreadyExists
    /// The file is corrupt, and a quarantined copy of it stands, which `restore` accepts by this name. The store reports it on
    /// every load until the copy is restored or new defaults are saved. `reason` is a code for the person who reads the copy.
    case corrupt(file: String, reason: String)
    case unreadable(file: String), upgradeRequired(file: String, version: Int), tooLarge(file: String)
    case invalidName(String), storeUnavailable(StoreFailure), writeFailed(file: String)
    /// Refused before writing: the file would exceed the size cap, or would not read back (the previous version is kept).
    case wouldNotReadBack(file: String)
}

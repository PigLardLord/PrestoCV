import Foundation
import PrestoCVDomain

// MARK: - Outbound ports (DIP). Every method is atomic within the repository's serialisation boundary,
// across instances and processes (the file adapter locks the store). Repository operations are short,
// synchronous I/O and are not cancellable: they complete or fail.

public protocol CVRepository: Sendable {
    /// Stores a never-saved CV (revision 0) as revision 1. Fails with `alreadyExists`.
    func create(_ cv: CV) async throws(RepositoryError) -> CV
    /// Replaces the stored CV only if its revision equals `cv.revision`; returns it at revision + 1.
    func update(_ cv: CV) async throws(RepositoryError) -> CV
    func load(_ id: CVID) async throws(RepositoryError) -> CV
    /// Healthy CVs, most recently changed first, plus every issue found. Never fails because of one file.
    func list() async throws(RepositoryError) -> CVListing
    func delete(_ id: CVID, revision: Int) async throws(RepositoryError)
}

/// Recovery and erasure, reachable from the UI (quarantine review, "delete everything about this CV").
public protocol CVStoreMaintenance: Sendable {
    func restore(quarantined name: String) async throws(RepositoryError) -> CV
    /// Removes every copy of a CV: the stored file whatever its schema, and quarantined copies (GDPR erasure).
    func erase(_ id: CVID) async throws(RepositoryError)
    /// Deletes quarantined files older than `date`. Returns how many were removed.
    func purgeQuarantine(olderThan date: Date) async throws(RepositoryError) -> Int
}

public struct CVListing: Sendable, Equatable {
    public var cvs: [CV], issues: [StoreIssue]
    public init(cvs: [CV], issues: [StoreIssue]) { self.cvs = cvs; self.issues = issues }
}

public enum StoreIssue: Sendable, Equatable {
    case corrupt(file: String, reason: String)       // quarantined, restorable
    case upgradeRequired(file: String, version: Int) // left untouched
    case unreadable(file: String)                    // I/O failure or symlink: left untouched, retried next time
    case tooLarge(file: String, bytes: Int)          // left untouched, never read
    case quarantineFailed(file: String)              // corrupt, but could not be moved aside
}

public enum StoreFailure: Sendable, Equatable { case notADirectory, cannotList, cannotLock }

/// No paths or free-form strings: file names only, and coded failures (CleanErrors).
public enum RepositoryError: Error, Equatable, Sendable {
    case notFound(CVID), alreadyExists(CVID), conflict(CVID, storedRevision: Int)
    case corrupt(file: String), unreadable(file: String), upgradeRequired(file: String, version: Int), tooLarge(file: String)
    case invalidName(String), storeUnavailable(StoreFailure), writeFailed(file: String)
    /// Refused before writing: the file would exceed the size cap, or would not read back (the previous version is kept).
    case wouldNotReadBack(file: String)
}

public protocol IDGenerator: Sendable { func next() -> CVID }
/// Named to avoid shadowing Swift.Clock.
public protocol TimeSource: Sendable { func now() -> Date }

/// The sample CVs offered on first run, in the stored format (docs/architecture/modules.md).
public protocol SampleCVSource: Sendable {
    func samples() async throws(RepositoryError) -> [CV]
}

import Foundation
import PrestoCVDomain

// MARK: - Outbound ports (DIP). Every method is atomic within the repository's serialisation boundary,
// across instances and processes (the file adapter locks the store). Repository operations are short,
// synchronous I/O and are not cancellable: they complete or fail.

/// What `SaveCV` needs of a store: to create a CV and to replace it.
public protocol CVSaver: Sendable {
    /// Stores a never-saved CV (revision 0) as revision 1. Fails with `alreadyExists`.
    func create(_ cv: CV) async throws(RepositoryError) -> CV
    /// Replaces the stored CV only if its revision equals `cv.revision`; returns it at revision + 1. Fails with `conflict`
    /// when the stored revision is another, and with `notFound` when the CV is gone.
    func update(_ cv: CV) async throws(RepositoryError) -> CV
}

/// What `LoadCV` needs of a store.
public protocol CVLoader: Sendable {
    /// Loads a stored CV. Fails with `notFound` when no CV has that identity, and with `storeUnavailable` when the store
    /// itself is not there.
    func load(_ id: CVID) async throws(RepositoryError) -> CV
}

/// What `ListCVs` needs of a store.
public protocol CVLister: Sendable {
    /// Healthy CVs, most recently changed first, plus every issue found. Never fails because of one file.
    func list() async throws(RepositoryError) -> CVListing
}

/// What `DeleteCV` needs of a store.
public protocol CVDeleter: Sendable {
    /// Deletes the CV only if it is stored at `revision`. Fails with `conflict` otherwise, and with `notFound` if it is gone.
    func delete(_ id: CVID, revision: Int) async throws(RepositoryError)
}

/// A store of CVs, which is every port a use case reads or writes through. An adapter implements this one; a use case
/// depends only on the part it calls.
public protocol CVRepository: CVSaver, CVLoader, CVLister, CVDeleter {}

/// Recovery and erasure, reachable from the UI (quarantine review, "delete everything about this CV").
public protocol CVStoreMaintenance: Sendable {
    /// Moves a quarantined file back into the store, if it now passes every read check. Fails with `invalidName` for a name
    /// that is not a quarantined file's, and with `alreadyExists` when the store holds a CV of that name.
    func restore(quarantined name: String) async throws(RepositoryError) -> CV
    /// Removes every copy of a CV: the stored file whatever its schema, and quarantined copies (GDPR erasure).
    func erase(_ id: CVID) async throws(RepositoryError)
    /// Deletes quarantined files older than `date`. Returns how many were removed.
    func purgeQuarantine(olderThan date: Date) async throws(RepositoryError) -> Int
}

/// The result of listing a store: the healthy CVs, and what was wrong with the files that are not.
public struct CVListing: Sendable, Equatable {
    public var cvs: [CV], issues: [StoreIssue]
    public init(cvs: [CV], issues: [StoreIssue]) { self.cvs = cvs; self.issues = issues }
}

/// A file of the store that is not a CV the app can use, and what became of it.
public enum StoreIssue: Sendable, Equatable {
    case corrupt(file: String, reason: String)       // quarantined, restorable
    case upgradeRequired(file: String, version: Int) // left untouched
    case unreadable(file: String)                    // I/O failure or symlink: left untouched, retried next time
    case tooLarge(file: String, bytes: Int)          // left untouched, never read
    case quarantineFailed(file: String)              // corrupt, but could not be moved aside
}

/// Why a store cannot be used as a whole.
public enum StoreFailure: Sendable, Equatable { case notADirectory, cannotList, cannotLock }

/// No paths or free-form strings: file names only, and coded failures (CleanErrors).
public enum RepositoryError: Error, Equatable, Sendable {
    case notFound(CVID), alreadyExists(CVID), conflict(CVID, storedRevision: Int)
    case corrupt(file: String), unreadable(file: String), upgradeRequired(file: String, version: Int), tooLarge(file: String)
    case invalidName(String), storeUnavailable(StoreFailure), writeFailed(file: String)
    /// Refused before writing: the file would exceed the size cap, or would not read back (the previous version is kept).
    case wouldNotReadBack(file: String)
}

/// Where new identities come from, so that no domain or application code creates one itself (PureCore).
public protocol IDGenerator: Sendable { func next() -> CVID }

/// Where the current time comes from (PureCore). Named to avoid shadowing Swift.Clock.
public protocol TimeSource: Sendable { func now() -> Date }

/// The sample CVs offered on first run, in the stored format (docs/architecture/modules.md).
public protocol SampleCVSource: Sendable {
    /// Every sample, in a fixed order. Fails when one cannot be used: the samples ship with the app, so none is skipped.
    func samples() async throws(RepositoryError) -> [CV]
}

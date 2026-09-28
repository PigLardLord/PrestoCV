import Foundation
import PrestoCVDomain

// MARK: - Outbound ports (R3). Every method is atomic within the repository's serialisation boundary,
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

/// No paths or free-form strings: file names only, and coded failures (R7).
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

// MARK: - Use cases

/// What presentation needs to know, without the port's error shape (R7).
public enum AuthoringError: Error, Equatable, Sendable {
    case notEnoughContent, conflict(storedRevision: Int), deletedElsewhere, tooLarge, unavailable
}

/// A new, unsaved CV with a fresh identity.
public struct NewCV: Sendable {
    let ids: any IDGenerator
    public init(ids: any IDGenerator) { self.ids = ids }
    public func callAsFunction() -> CV { CV(id: ids.next()) }
}

/// Saves a CV: create when never saved, conditional update otherwise. Returns the stored CV.
public struct SaveCV: Sendable {
    let repository: any CVRepository
    public init(repository: any CVRepository) { self.repository = repository }
    public func callAsFunction(_ cv: CV) async throws(AuthoringError) -> CV {
        guard cv.canBeSaved else { throw .notEnoughContent }
        do { return cv.revision == 0 ? try await repository.create(cv) : try await repository.update(cv) }
        catch .conflict(_, let stored) { throw .conflict(storedRevision: stored) }
        catch .notFound { throw .deletedElsewhere }
        catch .wouldNotReadBack { throw .tooLarge }
        catch { throw .unavailable }
    }
}

public struct LoadCV: Sendable {
    let repository: any CVRepository
    public init(repository: any CVRepository) { self.repository = repository }
    public func callAsFunction(_ id: CVID) async throws(AuthoringError) -> CV {
        do { return try await repository.load(id) } catch .notFound { throw .deletedElsewhere } catch { throw .unavailable }
    }
}

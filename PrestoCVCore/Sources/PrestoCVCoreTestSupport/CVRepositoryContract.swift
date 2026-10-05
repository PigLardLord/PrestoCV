import Foundation
import PrestoCVApplication
import PrestoCVDomain

/// The contract every `CVRepository` adapter must pass (LSP), the in-memory one and the file one alike. Each step checks one
/// behaviour of the port and throws a `Failure` that says which.
public enum CVRepositoryContract {
    /// What a step found wrong.
    public struct Failure: Error, CustomStringConvertible {
        /// What was found wrong, in a sentence.
        public let description: String
    }

    private static let adaId = FixtureID.repeating(0x11)

    /// Runs every step against `repository`, which must be empty.
    ///
    /// - Throws: `Failure` for the first step that is not met.
    public static func verify(_ repository: some CVRepository) async throws {
        let created = try await verifyCreateAndLoad(repository)
        let updated = try await verifyUpdate(repository, from: created)
        try await verifyStaleUpdateLosesToTheStoredOne(repository, stale: created)
        let raced = try await verifyOnlyOneConcurrentUpdateWins(repository, from: updated)
        try await verifyDelete(repository, of: raced)
        try await verifyListingOrder(repository)
    }

    private static func ada(_ id: CVID) -> CV { CV(id: id, personal: PersonalDetails(fullName: "Ada")) }

    private static func verifyCreateAndLoad(_ repository: some CVRepository) async throws -> CV {
        let created = try await repository.create(ada(adaId))
        let loaded = try await repository.load(adaId)
        let isRoundTrip = created.revision == 1 && created.createdAt != nil && created.createdAt == created.updatedAt && loaded == created
        guard isRoundTrip else { throw Failure(description: "create/load round trip with timestamps") }
        try await expect(.alreadyExists(adaId), "create twice") { _ = try await repository.create(ada(adaId)) }
        return created
    }

    private static func verifyUpdate(_ repository: some CVRepository, from created: CV) async throws -> CV {
        var edit = created
        edit.rename("Updated")
        let updated = try await repository.update(edit)
        let isBumped = updated.revision == 2 && updated.createdAt == created.createdAt && laterThan(created, updated)
        let listed = try await repository.list().cvs
        guard isBumped && listed == [updated] else {
            throw Failure(description: "update must bump revision and updatedAt, keep createdAt, not duplicate")
        }
        return updated
    }

    private static func laterThan(_ earlier: CV, _ later: CV) -> Bool {
        guard let before = earlier.updatedAt, let after = later.updatedAt else { return false }
        return after > before
    }

    private static func verifyStaleUpdateLosesToTheStoredOne(_ repository: some CVRepository, stale: CV) async throws {
        var staleEdit = stale
        staleEdit.rename("Stale window")
        try await expect(.conflict(adaId, storedRevision: 2), "stale update") { _ = try await repository.update(staleEdit) }
        guard try await repository.load(adaId).title == "Updated" else { throw Failure(description: "stale update overwrote") }
    }

    /// N updates from the same revision, at once on one instance, leave exactly one success.
    private static func verifyOnlyOneConcurrentUpdateWins(_ repository: some CVRepository, from base: CV) async throws -> CV {
        let successes = await withTaskGroup(of: Bool.self) { group in
            for racer in 0..<50 {
                group.addTask { await updateSucceeds(repository, renaming: base, to: "Racer \(racer)") }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        guard successes == 1 else { throw Failure(description: "\(successes) concurrent updates from one revision succeeded") }
        return try await repository.load(adaId)
    }

    private static func updateSucceeds(_ repository: some CVRepository, renaming cv: CV, to title: String) async -> Bool {
        var renamed = cv
        renamed.rename(title)
        do {
            _ = try await repository.update(renamed)
            return true
        } catch {
            return false
        }
    }

    private static func verifyDelete(_ repository: some CVRepository, of stored: CV) async throws {
        try await expect(.conflict(adaId, storedRevision: 3), "stale delete") { try await repository.delete(adaId, revision: 1) }
        try await repository.delete(adaId, revision: stored.revision)
        try await expect(.notFound(adaId), "update after delete must not resurrect") { _ = try await repository.update(stored) }
        guard try await repository.list().cvs.isEmpty else { throw Failure(description: "deleted CV came back") }
        try await expect(.notFound(adaId), "delete missing") { try await repository.delete(adaId, revision: 3) }
    }

    /// Listing order: most recently changed first.
    private static func verifyListingOrder(_ repository: some CVRepository) async throws {
        let first = try await repository.create(ada(FixtureID.repeating(0x22)))
        let second = try await repository.create(ada(FixtureID.repeating(0x33)))
        var touched = first
        touched.rename("touched")
        let updatedFirst = try await repository.update(touched)
        guard try await repository.list().cvs.map(\.id) == [updatedFirst.id, second.id] else {
            throw Failure(description: "list must be sorted by last change")
        }
    }

    private static func expect(_ error: RepositoryError, _ what: String, _ body: () async throws -> Void) async throws {
        do { try await body() } catch let failure as RepositoryError {
            guard failure == error else { throw Failure(description: "\(what): got \(failure)") }
            return
        }
        throw Failure(description: "\(what): expected \(error)")
    }
}

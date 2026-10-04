import Foundation
import PrestoCVDomain
import PrestoCVApplication

public actor InMemoryApplicationRepository: ApplicationRepository {
    var store: [ApplicationID: Application] = [:]
    let clock: any TimeSource
    public init(clock: any TimeSource = SteppingClock()) { self.clock = clock }

    public func create(_ application: Application) async throws(ApplicationRepositoryError) -> Application {
        if let kept = store.values.first(where: { $0.provenance.jobID == application.provenance.jobID }) { return kept }
        guard store[application.id] == nil else { throw .alreadyExists(application.id) }
        let stored = application.stored(revision: 1, at: clock.now()); store[application.id] = stored; return stored
    }

    public func update(_ application: Application) async throws(ApplicationRepositoryError) -> Application {
        guard let existing = store[application.id] else { throw .notFound(application.id) }
        guard existing.revision == application.revision else { throw .conflict(application.id, storedRevision: existing.revision) }
        let stored = application.stamped(revision: application.revision + 1, createdAt: existing.createdAt, updatedAt: clock.now())
        store[application.id] = stored; return stored
    }

    public func load(_ id: ApplicationID) async throws(ApplicationRepositoryError) -> Application {
        guard let application = store[id] else { throw .notFound(id) }
        return application
    }

    public func list() async throws(ApplicationRepositoryError) -> ApplicationListing {
        ApplicationListing(applications: store.values.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }, issues: [])
    }

    public func delete(_ id: ApplicationID, revision: Int) async throws(ApplicationRepositoryError) {
        guard let existing = store[id] else { throw .notFound(id) }
        guard existing.revision == revision else { throw .conflict(id, storedRevision: existing.revision) }
        store[id] = nil
    }
}

public enum ApplicationRepositoryContract {
    public typealias Failure = ContractFailure

    private static func id(_ n: Int) -> ApplicationID { ApplicationID(UUID(uuidString: "AAAAAAAA-0000-0000-0000-" + String(format: "%012d", n))!) }
    private static func cvID(_ n: Int) -> CVID { CVID(UUID(uuidString: "BBBBBBBB-0000-0000-0000-" + String(format: "%012d", n))!) }
    private static func application(_ n: Int, job: String? = nil) -> Application {
        FixtureApplication.full(id: id(n), cvID: cvID(n), jobID: job ?? "job-\(n)")
    }

    private static func letter(_ text: String) -> CoverLetter {
        do { return try CoverLetter(recipient: LetterRecipient(company: "Acme"), paragraphs: [text]) }
        catch { preconditionFailure("the contract's letter is valid: \(error)") }
    }

    /// An application whose CV carries `title`, built through the aggregate's own method.
    private static func retitled(_ application: Application, _ title: String) throws -> Application {
        var edited = application, cv = application.cv
        cv.rename(title)
        try edited.setCV(cv)
        return edited
    }

    /// Every ApplicationRepository adapter must pass this (R10).
    public static func verify(_ repo: some ApplicationRepository) async throws {
        let first = application(1)
        let v1 = try await repo.create(first)
        guard v1.revision == 1, v1.createdAt != nil, v1.createdAt == v1.updatedAt, try await repo.load(first.id) == v1 else {
            throw Failure(description: "create/load round trip with timestamps")
        }
        guard v1.cv.id == cvID(1), v1.cv.revision == 1, v1.cv.createdAt == v1.createdAt, v1.cv.updatedAt == v1.updatedAt else {
            throw Failure(description: "the CV must keep its identity and take the application's revision and times")
        }
        guard v1.letter == first.letter, v1.advert == first.advert, v1.provenance == first.provenance, v1.cv.sections == first.cv.sections else {
            throw Failure(description: "create must store every part of the application")
        }
        try await expect(.alreadyExists(first.id), { _ = try await repo.create(application(1, job: "another job")) }, "create twice")

        var edit = v1; edit.setLetter(letter("Updated"))
        let v2 = try await repo.update(edit)
        guard v2.revision == 2, v2.cv.revision == 2, v2.createdAt == v1.createdAt, let u1 = v1.updatedAt, let u2 = v2.updatedAt, u2 > u1,
              v2.cv.updatedAt == v2.updatedAt, v2.cv.id == v1.cv.id, try await repo.list().applications == [v2] else {
            throw Failure(description: "update must bump revision and updatedAt, keep createdAt and the CV's identity, not duplicate")
        }

        var stale = v1; stale.setLetter(letter("Stale window"))
        try await expect(.conflict(first.id, storedRevision: 2), { _ = try await repo.update(stale) }, "stale update")
        guard try await repo.load(first.id).letter == letter("Updated") else { throw Failure(description: "stale update overwrote") }

        // The CV and the letter share one revision: an edit of each from the same revision conflicts.
        let base = try await repo.load(first.id)
        let cvEdited = try await repo.update(try retitled(base, "Edited CV"))
        var letterEdit = base; letterEdit.setLetter(letter("Edited letter"))
        try await expect(.conflict(first.id, storedRevision: 3), { _ = try await repo.update(letterEdit) }, "letter edit after a CV edit from one revision")
        var staleCV = try retitled(base, "Edited elsewhere")
        staleCV.setLetter(cvEdited.letter)
        try await expect(.conflict(first.id, storedRevision: 3), { _ = try await repo.update(staleCV) }, "CV edit after a CV edit from one revision")
        let afterLetter = try await repo.update({ var a = cvEdited; a.setLetter(letter("Then the letter")); return a }())
        try await expect(.conflict(first.id, storedRevision: 4), { _ = try await repo.update(try retitled(cvEdited, "CV again")) }, "CV edit after a letter edit from one revision")
        guard afterLetter.revision == 4, afterLetter.cv.title == "Edited CV", afterLetter.letter == letter("Then the letter") else {
            throw Failure(description: "edits of the CV and of the letter from the current revision must both be kept")
        }

        // Concurrency on one instance: N updates from the same revision leave exactly one success.
        let successes = await withTaskGroup(of: Bool.self) { group in
            for n in 0..<50 {
                group.addTask { var a = afterLetter; a.setLetter(letter("Racer \(n)")); return (try? await repo.update(a)) != nil }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        guard successes == 1 else { throw Failure(description: "\(successes) concurrent updates from one revision succeeded") }
        let v5 = try await repo.load(first.id)

        try await expect(.conflict(first.id, storedRevision: 5), { try await repo.delete(first.id, revision: 1) }, "stale delete")
        try await repo.delete(first.id, revision: v5.revision)
        try await expect(.notFound(first.id), { _ = try await repo.update(v5) }, "update after delete must not resurrect")
        guard try await repo.list().applications.isEmpty else { throw Failure(description: "deleted application came back") }
        try await expect(.notFound(first.id), { try await repo.delete(first.id, revision: 5) }, "delete missing")
        try await expect(.notFound(first.id), { _ = try await repo.load(first.id) }, "load missing")

        // One application per job: a second create for the same job returns the first and stores nothing.
        let kept = try await repo.create(application(2, job: "one job"))
        let again = try await repo.create(application(3, job: "one job"))
        guard again == kept, try await repo.list().applications.map(\.id) == [kept.id] else {
            throw Failure(description: "create twice from one job must return the first and leave one application")
        }
        let racing = await withTaskGroup(of: ApplicationID?.self) { group in
            for n in 10..<40 { group.addTask { (try? await repo.create(application(n, job: "raced job")))?.id } }
            return await group.reduce(into: Set<ApplicationID?>()) { $0.insert($1) }
        }
        let held = try await repo.list().applications.filter { $0.provenance.jobID.raw == "raced job" }
        guard held.count == 1, racing == [held[0].id] else { throw Failure(description: "concurrent creates for one job must leave one, and return it to every caller") }
        // Deleting the application frees its job: the store holds what it holds, not what it once held.
        try await repo.delete(kept.id, revision: kept.revision)
        guard try await repo.create(application(4, job: "one job")).id == id(4) else { throw Failure(description: "a deleted application's job can be kept again") }

        // Listing order: most recently changed first.
        for held in try await repo.list().applications { try await repo.delete(held.id, revision: held.revision) }
        let a = try await repo.create(application(5)), b = try await repo.create(application(6))
        var a2 = a; a2.setLetter(letter("touched")); let a3 = try await repo.update(a2)
        guard try await repo.list().applications.map(\.id) == [a3.id, b.id] else { throw Failure(description: "list must be sorted by last change") }
    }
}

/// A repository whose every operation fails with one error, to test how a use case translates it.
public struct FailingApplicationRepository: ApplicationRepository {
    let error: ApplicationRepositoryError
    public init(_ error: ApplicationRepositoryError) { self.error = error }
    public func create(_ application: Application) async throws(ApplicationRepositoryError) -> Application { throw error }
    public func update(_ application: Application) async throws(ApplicationRepositoryError) -> Application { throw error }
    public func load(_ id: ApplicationID) async throws(ApplicationRepositoryError) -> Application { throw error }
    public func list() async throws(ApplicationRepositoryError) -> ApplicationListing { throw error }
    public func delete(_ id: ApplicationID, revision: Int) async throws(ApplicationRepositoryError) { throw error }
}

/// What a tailoring result maps to, for tests of the use cases: every field populated.
public enum FixtureApplicationValues {
    public static func full(jobID: String = "job-0001") -> ApplicationValues {
        let application = FixtureApplication.full(jobID: jobID), cv = application.cv
        return ApplicationValues(title: cv.title, personal: cv.personal, sections: cv.sections, design: cv.design, language: cv.language,
                                 letter: application.letter, advert: application.advert, provenance: application.provenance)
    }
}

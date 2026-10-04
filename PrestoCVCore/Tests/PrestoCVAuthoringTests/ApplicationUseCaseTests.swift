import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport

private func letter(_ text: String) throws -> CoverLetter { try CoverLetter(recipient: LetterRecipient(company: "Acme"), paragraphs: [text]) }

@Suite("ADR 0019 · application use cases")
struct ApplicationUseCaseTests {
    @Test("create takes values, gives the application and its CV an identity each from the generator, and stores both at revision 1")
    func create() async throws {
        let repository = InMemoryApplicationRepository(), ids = SequentialIDGenerator()
        let created = try await CreateApplication(repository: repository, ids: ids)(FixtureApplicationValues.full())
        #expect(created.id == ApplicationID(UUID(uuidString: "00000000-0000-0000-0001-000000000002")!))
        #expect(created.cv.id == CVID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
        #expect(created.revision == 1 && created.cv.revision == 1 && created.createdAt != nil)
        let source = FixtureApplication.full()
        #expect(created.cv.sections == source.cv.sections && created.cv.personal == source.cv.personal && created.letter == source.letter)
        #expect(created.advert == source.advert && created.provenance == source.provenance)
        #expect(try await ListApplications(repository: repository)().applications == [created])
    }

    @Test("a second create for the same job returns the first and keeps one application")
    func createIsIdempotentPerJob() async throws {
        let repository = InMemoryApplicationRepository(), create = CreateApplication(repository: repository, ids: SequentialIDGenerator())
        let first = try await create(FixtureApplicationValues.full(jobID: "job-7"))
        let second = try await create(FixtureApplicationValues.full(jobID: "job-7"))
        #expect(second == first)
        _ = try await create(FixtureApplicationValues.full(jobID: "job-8"))
        #expect(try await ListApplications(repository: repository)().applications.count == 2)
    }

    @Test("values that the domain refuses are not stored: a CV without a name is not enough content, any other is invalid")
    func createRefusals() async throws {
        let repository = InMemoryApplicationRepository(), create = CreateApplication(repository: repository, ids: SequentialIDGenerator())
        let full = FixtureApplicationValues.full()
        let nameless = ApplicationValues(title: "", personal: PersonalDetails(), sections: full.sections, design: nil, language: nil,
                                         letter: full.letter, advert: full.advert, provenance: full.provenance)
        await #expect(throws: AuthoringError.notEnoughContent) { _ = try await create(nameless) }
        #expect(try await ListApplications(repository: repository)().applications.isEmpty)
    }

    @Test("a store's failures are translated once into the typed errors of Authoring")
    func translation() async throws {
        let application = FixtureApplication.full().stored(revision: 2, at: Date(timeIntervalSince1970: 0))
        let id = application.id
        let cases: [(ApplicationRepositoryError, AuthoringError)] = [
            (.conflict(id, storedRevision: 5), .conflict(storedRevision: 5)), (.notFound(id), .deletedElsewhere), (.wouldNotReadBack(file: "f"), .tooLarge),
            (.storeUnavailable(.cannotList), .unavailable), (.corrupt(file: "f"), .unavailable), (.writeFailed(file: "f"), .unavailable),
        ]
        for (failure, expected) in cases {
            let repository = FailingApplicationRepository(failure)
            await #expect(throws: expected) { _ = try await CreateApplication(repository: repository, ids: SequentialIDGenerator())(FixtureApplicationValues.full()) }
            await #expect(throws: expected) { _ = try await LoadApplication(repository: repository)(id) }
            await #expect(throws: expected) { _ = try await ListApplications(repository: repository)() }
            await #expect(throws: expected) { _ = try await UpdateApplicationCV(repository: repository)(application, to: application.cv) }
            await #expect(throws: expected) { _ = try await UpdateApplicationLetter(repository: repository)(application, to: application.letter) }
            await #expect(throws: expected) { try await DeleteApplication(repository: repository)(application) }
        }
    }

    @Test("loading an application deleted elsewhere says so")
    func loadMissing() async throws {
        await #expect(throws: AuthoringError.deletedElsewhere) { _ = try await LoadApplication(repository: InMemoryApplicationRepository())(FixtureApplication.id) }
    }

    @Test("the list is ordered by last change, the one just edited first")
    func list() async throws {
        let repository = InMemoryApplicationRepository(), create = CreateApplication(repository: repository, ids: SequentialIDGenerator())
        let a = try await create(FixtureApplicationValues.full(jobID: "a")), b = try await create(FixtureApplicationValues.full(jobID: "b"))
        #expect(try await ListApplications(repository: repository)().applications.map(\.id) == [b.id, a.id])
        let touched = try await UpdateApplicationLetter(repository: repository)(a, to: try letter("Touched"))
        #expect(try await ListApplications(repository: repository)().applications.map(\.id) == [touched.id, b.id])
    }

    @Test("updating the CV keeps its identity and bumps the application's revision; it must stay saveable and keep its identity")
    func updateCV() async throws {
        let repository = InMemoryApplicationRepository()
        let created = try await CreateApplication(repository: repository, ids: SequentialIDGenerator())(FixtureApplicationValues.full())
        var edited = created.cv
        edited.rename("Tailored for Acme")
        let updated = try await UpdateApplicationCV(repository: repository)(created, to: edited)
        #expect(updated.revision == 2 && updated.cv.revision == 2 && updated.cv.title == "Tailored for Acme" && updated.cv.id == created.cv.id)
        #expect(try await LoadApplication(repository: repository)(created.id) == updated)

        var blank = updated.cv
        blank.setPersonalDetails(PersonalDetails())
        await #expect(throws: AuthoringError.notEnoughContent) { _ = try await UpdateApplicationCV(repository: repository)(updated, to: blank) }
        let other = CV(id: CVID(UUID()), personal: PersonalDetails(fullName: "Ada"))
        await #expect(throws: AuthoringError.invalid(.cvIdentityChanged)) { _ = try await UpdateApplicationCV(repository: repository)(updated, to: other) }
    }

    @Test("an edit of the CV and an edit of the letter made from the same revision conflict, whichever comes first")
    func sharedRevision() async throws {
        let repository = InMemoryApplicationRepository()
        let created = try await CreateApplication(repository: repository, ids: SequentialIDGenerator())(FixtureApplicationValues.full())
        var cv = created.cv
        cv.rename("Edited CV")
        _ = try await UpdateApplicationCV(repository: repository)(created, to: cv)
        await #expect(throws: AuthoringError.conflict(storedRevision: 2)) { _ = try await UpdateApplicationLetter(repository: repository)(created, to: try letter("Late")) }
        let current = try await LoadApplication(repository: repository)(created.id)
        _ = try await UpdateApplicationLetter(repository: repository)(current, to: try letter("First"))
        await #expect(throws: AuthoringError.conflict(storedRevision: 3)) { _ = try await UpdateApplicationCV(repository: repository)(current, to: cv) }
        #expect(try await LoadApplication(repository: repository)(created.id).cv.title == "Edited CV")
    }

    @Test("delete needs the revision the caller saw; a missing application is 'deleted elsewhere'")
    func delete() async throws {
        let repository = InMemoryApplicationRepository()
        let created = try await CreateApplication(repository: repository, ids: SequentialIDGenerator())(FixtureApplicationValues.full())
        _ = try await UpdateApplicationLetter(repository: repository)(created, to: try letter("Newer"))
        await #expect(throws: AuthoringError.conflict(storedRevision: 2)) { try await DeleteApplication(repository: repository)(created) }
        let current = try await LoadApplication(repository: repository)(created.id)
        try await DeleteApplication(repository: repository)(current)
        await #expect(throws: AuthoringError.deletedElsewhere) { try await DeleteApplication(repository: repository)(current) }
        #expect(try await ListApplications(repository: repository)().applications.isEmpty)
    }
}

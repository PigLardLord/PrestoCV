import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVWorkflowPorts
@testable import PrestoCVIntegration

@Suite("Editing a CV · new, save, load")
struct EditCVWorkflowTests {
    let repository = RepositorySpy()
    let workflow: EditCVWorkflow

    init() { workflow = EditCVWorkflow(repository: repository, ids: SequentialIDGenerator()) }

    @Test("a new CV has a fresh id and revision 0, and nothing is stored until it is saved")
    func newCVHasFreshIdAndNothingStored() async throws {
        let first = workflow.new(), second = workflow.new()

        #expect(first.id != second.id)
        #expect(first.revision == 0 && first.createdAt == nil)
        #expect(await repository.writes == 0)
        #expect(try await repository.list().cvs.isEmpty)
    }

    @Test("the first save creates the CV at its first revision, later saves update it, with the repository's revision and times")
    func firstSaveCreatesLaterSavesUpdate() async throws {
        var cv = Invented.cv("Ada Lovelace", id: workflow.new().id)

        let created = try await workflow.save(cv)
        #expect(created.revision == 1 && created.createdAt != nil && created.createdAt == created.updatedAt)
        let counts = await (repository.creates, repository.updates)
        #expect(counts == (1, 0))

        cv = created
        cv.rename("Engines")
        let updated = try await workflow.save(cv)
        #expect(updated.revision == 2 && updated.createdAt == created.createdAt)
        #expect(updated.updatedAt.map { $0 > (created.updatedAt ?? .distantFuture) } == true)
        let counts2 = await (repository.creates, repository.updates)
        #expect(counts2 == (1, 1))
        #expect(try await workflow.load(updated.id) == updated)
    }

    @Test("a save with a stale revision is a conflict that names the stored revision, and the stored CV is unchanged")
    func staleSaveIsConflictAndKeepsStoredData() async throws {
        let first = try await workflow.save(Invented.cv("Ada", id: workflow.new().id))
        var otherWindow = first
        otherWindow.rename("Changed in the other window")
        let stored = try await workflow.save(otherWindow)
        var stale = first
        stale.rename("Stale edit")

        await #expect(throws: EditFailure.conflict(storedRevision: stored.revision)) { _ = try await workflow.save(stale) }
        #expect(try await workflow.load(first.id) == stored)
    }

    @Test("a save of a CV deleted elsewhere is 'deleted elsewhere', and nothing comes back")
    func saveAfterDeleteElsewhereIsDeletedElsewhere() async throws {
        let saved = try await workflow.save(Invented.cv("Ada", id: workflow.new().id))
        try await workflow.delete(saved)

        await #expect(throws: EditFailure.deletedElsewhere) { _ = try await workflow.save(saved) }
        #expect(try await repository.list().cvs.isEmpty)
    }

    @Test("the same content saved as a copy under a new id is stored")
    func saveAsCopyAfterDeleteElsewhereStoresNewId() async throws {
        let saved = try await workflow.save(Invented.cv("Ada", id: workflow.new().id))
        try await workflow.delete(saved)

        let copy = try await workflow.duplicate(saved, title: "Ada (copia)")

        #expect(copy.id != saved.id && copy.revision == 1 && copy.title == "Ada (copia)")
        #expect(copy.personal == saved.personal)
        #expect(try await repository.list().cvs == [copy])
    }

    @Test("a CV with no content is not enough, and it does not reach the repository")
    func emptyCVIsNotEnoughContentAndNotStored() async {
        await #expect(throws: EditFailure.notEnoughContent) { _ = try await workflow.save(workflow.new()) }
        #expect(await repository.writes == 0)
    }

    @Test("a text that is too long names its field, and a section with too many entries names the section; neither reaches the repository")
    func tooLongTextNamesTheField() async {
        var long = workflow.new()
        long.setPersonalDetails(PersonalDetails(fullName: "Ada", summary: String(repeating: "a", count: CVLimits.maxTextCharacters + 1)))
        var many = workflow.new()
        many.setPersonalDetails(PersonalDetails(fullName: "Ada"))
        many.setSections(CVSections(interests: (0...CVLimits.maxEntriesPerSection).map { "Interest \($0)" }))

        await #expect(throws: EditFailure.textTooLong(.summary)) { _ = try await workflow.save(long) }
        await #expect(throws: EditFailure.tooManyEntries(.interests)) { _ = try await workflow.save(many) }
        #expect(await repository.writes == 0)
    }

    @Test("a CV above the limits as a whole is too large, and it does not reach the repository")
    func cvAboveTheLimitsAsAWholeIsRefused() async {
        let description = String(repeating: "a", count: CVLimits.maxTextCharacters)
        let experiences = (0..<28).map { Experience(role: "Role \($0)", company: "Company", description: description) }
        var big = workflow.new()
        big.setPersonalDetails(PersonalDetails(fullName: "Ada"))
        big.setSections(CVSections(experiences: experiences))

        await #expect(throws: EditFailure.cvTooLarge) { _ = try await workflow.save(big) }
        #expect(await repository.writes == 0)
    }

    @Test("a file the store would not read back is too large for the store")
    func tooLargeForTheStoreIsTooLarge() async {
        await repository.fail(with: .wouldNotReadBack(file: "cv.json"))

        await #expect(throws: EditFailure.tooLarge) { _ = try await workflow.save(Invented.cv("Ada", id: workflow.new().id)) }
    }

    /// Every error a use case throws, with the failure the app gets for it: the table is as long as `AuthoringError`.
    static let mapping: [(AuthoringError, EditFailure)] = [
        (.notEnoughContent, .notEnoughContent),
        (.conflict(storedRevision: 4), .conflict(storedRevision: 4)),
        (.deletedElsewhere, .deletedElsewhere),
        (.tooLarge, .tooLarge),
        (.unavailable, .unavailable),
        (.textTooLong(.fullName), .textTooLong(.fullName)),
        (.tooManyEntries(.skills), .tooManyEntries(.skills)),
        (.cvTooLarge, .cvTooLarge),
    ]

    @Test("every error of a use case has its failure for the app", arguments: mapping)
    func everyAuthoringErrorHasAWorkflowFailure(error: AuthoringError, failure: EditFailure) {
        #expect(EditFailure(error) == failure)
    }

    @Test("a store that cannot be used is 'unavailable'", arguments: [
        RepositoryError.storeUnavailable(.cannotLock), .unreadable(file: "cv.json"),
        .writeFailed(file: "cv.json", cause: FailureCause(domain: .posix, code: 28)),
    ])
    func anUnusableStoreIsUnavailable(error: RepositoryError) async {
        await repository.fail(with: error)

        await #expect(throws: EditFailure.unavailable) { _ = try await workflow.save(Invented.cv("Ada", id: workflow.new().id)) }
        await #expect(throws: EditFailure.unavailable) { _ = try await workflow.load(Invented.cv("Ada", id: workflow.new().id).id) }
    }

    @Test("loading a CV deleted elsewhere says so")
    func loadingAGoneCV() async {
        await #expect(throws: EditFailure.deletedElsewhere) { _ = try await workflow.load(workflow.new().id) }
    }

    @Test("a write of a cancelled task passes the cancellation through and stores nothing")
    func cancellationPassesThrough() async throws {
        let writer = workflow.autosaveWriter(startingFrom: nil)
        let cv = Invented.cv("Ada", id: workflow.new().id)

        let attempt = Task { () -> (any Error)? in
            withUnsafeCurrentTask { $0?.cancel() }
            do { try await writer.write(cv, isStored: false); return nil } catch { return error }
        }

        #expect(await attempt.value is CancellationError)
        #expect(await repository.writes == 0)
    }
}

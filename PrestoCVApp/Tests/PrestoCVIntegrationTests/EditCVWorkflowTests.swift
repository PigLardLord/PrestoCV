import Testing
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVWorkflowPorts
import PrestoCVIntegration
import PrestoCVCoreTestSupport

@Suite("EditCVWorkflow (#88)")
struct EditCVWorkflowTests {
    let repository = InMemoryCVRepository()
    let editing: any CVEditing

    init() { editing = EditCVWorkflow(repository: repository, ids: SequentialIDGenerator()) }

    @Test("a new CV is unsaved and has the next identity")
    func newCV() {
        let first = editing.newCV(), second = editing.newCV()

        #expect(first.revision == 0)
        #expect(first.id == SequentialIDGenerator().next())
        #expect(second.id != first.id)
    }

    @Test("a saved CV is stored at revision 1 and loads back unchanged")
    func saveThenLoad() async throws {
        var cv = editing.newCV()
        cv.setPersonalDetails(PersonalDetails(fullName: "Ada Lovelace"))

        let saved = try await editing.save(cv)
        let loaded = try await editing.load(saved.id)

        #expect(saved.revision == 1)
        #expect(loaded == saved)
    }

    @Test("a CV without a name is not saved")
    func saveWithoutName() async {
        let cv = editing.newCV()

        await #expect(throws: AuthoringError.notEnoughContent) { _ = try await editing.save(cv) }
    }

    @Test("saving from a stale revision fails with the stored revision")
    func staleSave() async throws {
        var cv = editing.newCV()
        cv.setPersonalDetails(PersonalDetails(fullName: "Ada"))
        let first = try await editing.save(cv)
        var otherWindow = first
        otherWindow.rename("Changed elsewhere")
        _ = try await editing.save(otherWindow)
        var stale = first
        stale.rename("Stale")

        await #expect(throws: AuthoringError.conflict(storedRevision: 2)) { _ = try await editing.save(stale) }
    }

    @Test("loading a CV deleted elsewhere fails with deletedElsewhere")
    func loadDeleted() async throws {
        var cv = editing.newCV()
        cv.setPersonalDetails(PersonalDetails(fullName: "Ada"))
        let saved = try await editing.save(cv)
        try await repository.delete(saved.id, revision: saved.revision)

        await #expect(throws: AuthoringError.deletedElsewhere) { _ = try await editing.load(saved.id) }
    }

    @Test("saving a CV deleted elsewhere fails with deletedElsewhere")
    func saveDeleted() async throws {
        var cv = editing.newCV()
        cv.setPersonalDetails(PersonalDetails(fullName: "Ada"))
        let saved = try await editing.save(cv)
        try await repository.delete(saved.id, revision: saved.revision)

        await #expect(throws: AuthoringError.deletedElsewhere) { _ = try await editing.save(saved) }
    }
}

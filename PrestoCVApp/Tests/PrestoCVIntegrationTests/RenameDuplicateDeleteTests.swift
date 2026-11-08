import Testing
import Foundation
import PrestoCVDomain
import PrestoCVCoreTestSupport
import PrestoCVWorkflowPorts
@testable import PrestoCVIntegration

@Suite("Editing a CV · rename, duplicate, delete")
struct RenameDuplicateDeleteTests {
    let repository = RepositorySpy()
    let workflow: EditCVWorkflow

    init() { workflow = EditCVWorkflow(repository: repository, ids: SequentialIDGenerator()) }

    private func storedFullCV() async throws -> CV {
        try await workflow.save(FixtureCV.full(id: workflow.new().id))
    }

    @Test("a rename is trimmed to one line and stored")
    func renameTrimsToOneLine() async throws {
        let saved = try await storedFullCV()

        let renamed = try await workflow.rename(saved, to: "  Backend\nroles \n")

        #expect(renamed.title == "Backend roles" && renamed.revision == saved.revision + 1)
        #expect(try await workflow.load(saved.id) == renamed)
    }

    @Test("a rename of a stale CV is a conflict")
    func renameStaleCVIsConflict() async throws {
        let saved = try await storedFullCV()
        let other = try await workflow.rename(saved, to: "Other window")

        await #expect(throws: EditFailure.conflict(storedRevision: other.revision)) { _ = try await workflow.rename(saved, to: "Stale") }
        #expect(try await workflow.load(saved.id) == other)
    }

    @Test("a duplicate keeps the content, the design and the language")
    func duplicateKeepsContentDesignAndLanguage() async throws {
        let saved = try await storedFullCV()

        let copy = try await workflow.duplicate(saved, title: "iOS roles (copy)")

        #expect(copy.personal == saved.personal && copy.sections == saved.sections)
        #expect(copy.design == saved.design && copy.design != nil)
        #expect(copy.language == saved.language && copy.language != nil)
        #expect(copy.title == "iOS roles (copy)")
    }

    @Test("a duplicate has a new id and is stored as a first revision, the original untouched")
    func duplicateHasNewIdAndRevisionZero() async throws {
        let saved = try await storedFullCV()

        let copy = try await workflow.duplicate(saved, title: "Copy")

        #expect(copy.id != saved.id && copy.revision == 1 && copy.createdAt != nil)
        #expect(await repository.creates == 2)
        #expect(try await workflow.load(saved.id) == saved)
        #expect(try await repository.list().cvs.count == 2)
    }

    @Test("a delete at the revision the caller saw removes the CV")
    func deleteAtSeenRevision() async throws {
        let saved = try await storedFullCV()

        try await workflow.delete(saved)

        #expect(try await repository.list().cvs.isEmpty)
    }

    @Test("a delete of a stale CV is a conflict, and the CV stays")
    func deleteStaleIsConflict() async throws {
        let saved = try await storedFullCV()
        let other = try await workflow.rename(saved, to: "Other window")

        await #expect(throws: EditFailure.conflict(storedRevision: other.revision)) { try await workflow.delete(saved) }
        #expect(try await workflow.load(saved.id) == other)
    }

    @Test("a delete of a CV already gone is 'deleted elsewhere'")
    func deleteGoneIsDeletedElsewhere() async throws {
        let saved = try await storedFullCV()
        try await workflow.delete(saved)

        await #expect(throws: EditFailure.deletedElsewhere) { try await workflow.delete(saved) }
    }
}

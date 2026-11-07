import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVWorkflowPorts
@testable import PrestoCVIntegration

/// The editor's `Autosave` writing through the workflow's writer, onto a repository that counts its writes.
@MainActor
@Suite("Autosave through the editing workflow")
struct AutosaveWorkflowTests {
    let repository = RepositorySpy()
    let clock = ManualClock()
    let workflow: EditCVWorkflow
    var failures: Box = Box()

    final class Box { var errors: [any Error] = [] }

    init() { workflow = EditCVWorkflow(repository: repository, ids: SequentialIDGenerator()) }

    private func autosave(starting cv: CV, stored: CV?, cancelFirstWrite: Bool = false) -> Autosave<CV> {
        let writer = workflow.autosaveWriter(startingFrom: stored)
        let box = failures
        var cancelNext = cancelFirstWrite
        return Autosave(content: cv, unchangedFrom: stored.map { $0 }, isStored: stored != nil, isWorthStoring: { $0.canBeSaved },
                        clock: clock, onWriteFailure: { box.errors.append($0) },
                        write: { content, isStored in
                            if cancelNext { cancelNext = false; withUnsafeCurrentTask { $0?.cancel() } }
                            try await writer.write(content, isStored: isStored)
                        })
    }

    @Test("content equal to what the store holds is not written")
    func equalContentIsNotWritten() async throws {
        let stored = try await workflow.save(FixtureCV.full(id: workflow.new().id))
        let autosave = autosave(starting: stored, stored: stored)

        autosave.changed(to: stored)
        try await autosave.flush()

        #expect(await repository.updates == 0)
    }

    @Test("the first write creates the CV, the next ones update it onto the revision the store holds")
    func firstWriteCreatesThenUpdates() async throws {
        let draft = Invented.cv("Ada", id: workflow.new().id)
        let autosave = autosave(starting: draft, stored: nil)

        var edited = draft
        edited.rename("First")
        autosave.changed(to: edited)
        try await autosave.flush()
        edited.rename("Second")
        autosave.changed(to: edited)
        try await autosave.flush()

        let counts = await (repository.creates, repository.updates)
        #expect(counts == (1, 1))
        let stored = try await workflow.load(draft.id)
        #expect(stored.title == "Second" && stored.revision == 2)
        #expect(autosave.status == .upToDate)
    }

    @Test("a failed write keeps the content, says so, and the next flush writes it")
    func failedWriteKeepsContentAndRetries() async throws {
        let draft = Invented.cv("Ada", id: workflow.new().id)
        let autosave = autosave(starting: draft, stored: nil)
        await repository.fail(with: .storeUnavailable(.cannotLock))

        autosave.changed(to: draft)
        try await autosave.flush()
        #expect(autosave.status == .failed && failures.errors.count == 1)
        #expect(failures.errors.first as? EditFailure == .unavailable)

        await repository.fail(with: nil)
        try await autosave.flush()
        #expect(autosave.status == .upToDate)
        #expect(try await workflow.load(draft.id).personal == draft.personal)
    }

    @Test("a conflict during autosave is a failure for the editor to show; the other window's version stays stored")
    func conflictDuringAutosaveSetsFailureNotOverwrite() async throws {
        let stored = try await workflow.save(FixtureCV.full(id: workflow.new().id))
        let autosave = autosave(starting: stored, stored: stored)
        let other = try await workflow.rename(stored, to: "Other window")

        // This window learned of no change, and the store moved on: its writer holds an older revision.
        var edited = stored
        edited.rename("This window")
        autosave.changed(to: edited)
        try await autosave.flush()

        #expect(failures.errors.first as? EditFailure == .conflict(storedRevision: other.revision))
        #expect(autosave.status == .failed)
        #expect(try await workflow.load(stored.id) == other)
    }

    @Test("a cancelled write is no failure: nothing is stored, the flush passes the cancellation on, and the write is repeated later")
    func cancelledWriteIsNoFailure() async throws {
        let draft = Invented.cv("Ada", id: workflow.new().id)
        let autosave = autosave(starting: draft, stored: nil, cancelFirstWrite: true)
        autosave.changed(to: draft)

        await #expect(throws: CancellationError.self) { try await autosave.flush() }
        #expect(autosave.status != .failed && failures.errors.isEmpty)
        #expect(await repository.writes == 0)

        try await autosave.flush()
        #expect(await repository.creates == 1)
    }
}

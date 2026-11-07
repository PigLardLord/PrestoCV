import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVWorkflowPorts
@testable import PrestoCVIntegration

/// The writer is the one owner of the revision of the open CV: the text, the look and the language all go through it.
@Suite("The autosave writer of an open CV")
struct AutosaveWriterTests {
    let repository = RepositorySpy()
    let workflow: EditCVWorkflow
    let shown = Invented.design("minimal", palette: "mono", fonts: "serif")
    let german = DocumentLanguage("de")

    init() { workflow = EditCVWorkflow(repository: repository, ids: SequentialIDGenerator()) }

    private func stored() async throws -> CV { try await workflow.save(FixtureCV.full(id: workflow.new().id)) }

    @Test("a look and a language change, then a text write: no conflict, all three are kept (stored start)")
    func changesThenWriteOfStoredCV() async throws {
        let start = try await stored()
        let writer = workflow.autosaveWriter(startingFrom: start)

        _ = try await writer.changeLook(LookChange(shown: shown, parts: [.design]), of: start)
        _ = try await writer.setDocumentLanguage(german, of: start)
        var edited = start
        edited.rename("Edited")
        try await writer.write(edited, isStored: true)

        let result = try await workflow.load(start.id)
        #expect(result.title == "Edited" && result.language == german && result.design?.design == "minimal")
        #expect(result.revision == start.revision + 3)
    }

    @Test("a look and a language chosen before the first write are written with it (not-stored start)")
    func changesThenWriteOfNewCV() async throws {
        let draft = Invented.cv("Ada", id: workflow.new().id)
        let writer = workflow.autosaveWriter(startingFrom: nil)

        let looked = try await writer.changeLook(LookChange(shown: shown, parts: [.design]), of: draft)
        #expect(looked.design == shown && looked.revision == 0)
        #expect(await repository.writes == 0)
        try await writer.write(looked, isStored: false)

        let spoken = try await writer.setDocumentLanguage(german, of: looked)
        #expect(spoken.language == german && spoken.revision == 2)
        var edited = looked
        edited.rename("Edited")
        try await writer.write(edited, isStored: true)

        let result = try await workflow.load(draft.id)
        #expect(result.title == "Edited" && result.language == german && result.design == shown)
        #expect(await repository.creates == 1)
    }

    @Test("a text snapshot that predates a look or a language change does not revert it")
    func olderSnapshotDoesNotRevert() async throws {
        let start = try await stored()
        let writer = workflow.autosaveWriter(startingFrom: start)
        _ = try await writer.changeLook(LookChange(shown: shown, parts: [.design]), of: start)
        _ = try await writer.setDocumentLanguage(german, of: start)

        var snapshot = start
        snapshot.rename("Typed before the change")
        try await writer.write(snapshot, isStored: true)

        let result = try await workflow.load(start.id)
        #expect(result.design?.design == "minimal" && result.language == german && result.title == "Typed before the change")
    }

    @Test("the change of a stored CV does not store the text the person has typed")
    func changeLeavesUnsavedTextAlone() async throws {
        let start = try await stored()
        let writer = workflow.autosaveWriter(startingFrom: start)
        var typed = start
        typed.rename("Not saved yet")

        let changed = try await writer.changeLook(LookChange(shown: shown, parts: [.design]), of: typed)

        #expect(changed.title == start.title)
        #expect(try await workflow.load(start.id).title == start.title)
    }

    @Test("two calls on one writer never run in the store at the same time")
    func callsDoNotOverlap() async throws {
        let gated = GatedRepository()
        let flow = EditCVWorkflow(repository: gated, ids: SequentialIDGenerator())
        let start = try await flow.save(FixtureCV.full(id: flow.new().id))
        let writer = flow.autosaveWriter(startingFrom: start)
        var edited = start
        edited.rename("Edited")
        await gated.holdNextWrite()

        let first = Task { try await writer.write(edited, isStored: true) }
        await gated.untilHeld()
        let second = Task { try await writer.changeLook(LookChange(shown: shown, parts: [.design]), of: start) }
        for _ in 0..<200 { await Task.yield() }
        await gated.release(failing: false)

        try await first.value
        let changed = try await second.value
        #expect(await gated.peak == 1)
        #expect(changed.title == "Edited" && changed.design?.design == "minimal")
        #expect(try await flow.load(start.id) == changed)
    }

    @Test("a write cancelled while the store holds it, and then committed, counts as done: the next write is an update")
    func cancelledWriteThatCommitsIsDone() async throws {
        let gated = GatedRepository()
        let flow = EditCVWorkflow(repository: gated, ids: SequentialIDGenerator())
        let start = try await flow.save(FixtureCV.full(id: flow.new().id))
        let writer = flow.autosaveWriter(startingFrom: start)
        var typed = start
        typed.rename("First")
        let first = typed
        await gated.holdNextWrite()

        let task = Task { try await writer.write(first, isStored: true) }
        await gated.untilHeld()
        task.cancel()
        await gated.release(failing: false)
        try await task.value

        typed.rename("Second")
        try await writer.write(typed, isStored: true)
        let result = try await flow.load(start.id)
        #expect(result.title == "Second" && result.revision == start.revision + 2)
    }

    @Test("a write cancelled while the store holds it, and then failed, throws CancellationError and stores nothing")
    func cancelledWriteThatFailsIsCancellation() async throws {
        let gated = GatedRepository()
        let flow = EditCVWorkflow(repository: gated, ids: SequentialIDGenerator())
        let start = try await flow.save(FixtureCV.full(id: flow.new().id))
        let writer = flow.autosaveWriter(startingFrom: start)
        var typed = start
        typed.rename("Never stored")
        let edited = typed
        await gated.holdNextWrite()

        let task = Task { try await writer.write(edited, isStored: true) }
        await gated.untilHeld()
        task.cancel()
        await gated.release(failing: true)

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try await flow.load(start.id) == start)
    }

    @Test("a look change cancelled while the store holds it, and then failed, throws CancellationError")
    func cancelledChangeThatFailsIsCancellation() async throws {
        let gated = GatedRepository()
        let flow = EditCVWorkflow(repository: gated, ids: SequentialIDGenerator())
        let start = try await flow.save(FixtureCV.full(id: flow.new().id))
        let writer = flow.autosaveWriter(startingFrom: start)
        await gated.holdNextWrite()

        let task = Task { try await writer.changeLook(LookChange(shown: shown, parts: [.design]), of: start) }
        await gated.untilHeld()
        task.cancel()
        await gated.release(failing: true)

        await #expect(throws: CancellationError.self) { _ = try await task.value }
    }
}

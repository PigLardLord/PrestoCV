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
        try await writer.write(edited)

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
        try await writer.write(looked)

        let spoken = try await writer.setDocumentLanguage(german, of: looked)
        #expect(spoken.language == german && spoken.revision == 2)
        var edited = looked
        edited.rename("Edited")
        try await writer.write(edited)

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
        try await writer.write(snapshot)

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

        let first = Task { try await writer.write(edited) }
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

        let task = Task { try await writer.write(first) }
        await gated.untilHeld()
        task.cancel()
        await gated.release(failing: false)
        try await task.value

        typed.rename("Second")
        try await writer.write(typed)
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

        let task = Task { try await writer.write(edited) }
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

    // MARK: The table: every state of the writer against every call

    /// What the writer holds when the call is made. Every look and language change is passed the ORIGINAL draft, as an
    /// editor does that has not seen the result of the one before.
    enum State: CaseIterable {
        case stored, unsavedPlain, unsavedLooked, unsavedSpoken, unsavedBoth
        var isStored: Bool { self == .stored }
        var looked: Bool { self == .unsavedLooked || self == .unsavedBoth }
        var spoken: Bool { self == .unsavedSpoken || self == .unsavedBoth }
    }

    enum Call: CaseIterable {
        case write, changeLook, setLanguage, failedWrite, cancelledWriteThatStored, cancelledWriteThatDidNotStore
    }

    @Test("every state of the writer against every call keeps the look and the language the writer holds", arguments: State.allCases, Call.allCases)
    func table(state: State, call: Call) async throws {
        let gated = GatedRepository()
        let flow = EditCVWorkflow(repository: gated, ids: SequentialIDGenerator())
        let classic = Invented.design("classic")
        let french = DocumentLanguage("fr")
        var draft = Invented.cv("Ada", id: flow.new().id)
        if state.isStored { draft = try await flow.save(draft) }
        let writer = flow.autosaveWriter(startingFrom: state.isStored ? draft : nil)
        var look: DesignChoice?, language: DocumentLanguage?
        if state.looked { _ = try await writer.changeLook(LookChange(shown: shown, parts: [.design]), of: draft); look = shown }
        if state.spoken { _ = try await writer.setDocumentLanguage(german, of: draft); language = german }
        let entriesBefore = await gated.entries
        var typed = draft
        typed.rename("Typed")
        let attempt = typed

        switch call {
        case .write:
            try await writer.write(attempt)
        case .changeLook:
            let classicLook = LookChange(shown: classic, parts: [.design])
            let changed = try await writer.changeLook(classicLook, of: draft)
            look = classicLook.applying(to: look)
            #expect(changed.design == look && changed.language == language && changed.title == draft.title)
            #expect(await gated.entries == entriesBefore + (state.isStored ? 1 : 0))
        case .setLanguage:
            let changed = try await writer.setDocumentLanguage(french, of: draft)
            language = french
            #expect(changed.language == french && changed.design == look && changed.title == draft.title)
            #expect(await gated.entries == entriesBefore + (state.isStored ? 1 : 0))
        case .failedWrite:
            await gated.holdNextWrite()
            let task = Task { try await writer.write(attempt) }
            await gated.untilHeld()
            await gated.release(failing: true)
            await #expect(throws: EditFailure.self) { try await task.value }
        case .cancelledWriteThatStored:
            await gated.holdNextWrite()
            let task = Task { try await writer.write(attempt) }
            await gated.untilHeld()
            task.cancel()
            await gated.release(failing: false)
            try await task.value
        case .cancelledWriteThatDidNotStore:
            await gated.holdNextWrite()
            let task = Task { try await writer.write(attempt) }
            await gated.untilHeld()
            task.cancel()
            await gated.release(failing: true)
            await #expect(throws: CancellationError.self) { try await task.value }
        }

        // The next write, of a text snapshot older than every change above: it stores its text and the writer's look and language.
        var snapshot = draft
        snapshot.rename("Snapshot")
        try await writer.write(snapshot)
        let result = try await flow.load(draft.id)
        #expect(result.title == "Snapshot")
        #expect(result.design == look)
        #expect(result.language == language)
    }

    @Test("two changes before the first save, each given the original draft, then a write of an older snapshot: both are stored with the old text")
    func twoChangesBeforeTheFirstSave() async throws {
        let draft = Invented.cv("Ada", id: workflow.new().id)
        var snapshot = draft
        snapshot.rename("Older")
        let writer = workflow.autosaveWriter(startingFrom: nil)

        let looked = try await writer.changeLook(LookChange(shown: shown, parts: [.design]), of: draft)
        let spoken = try await writer.setDocumentLanguage(german, of: draft)
        #expect(looked.design == shown)
        #expect(spoken.design == shown && spoken.language == german)
        #expect(await repository.writes == 0)
        try await writer.write(snapshot)

        let result = try await workflow.load(draft.id)
        #expect(result.title == "Older" && result.design == shown && result.language == german)
        #expect(await repository.creates == 1)
    }
}

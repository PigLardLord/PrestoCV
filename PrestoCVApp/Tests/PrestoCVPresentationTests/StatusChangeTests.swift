import Testing
import PrestoCVWorkflowPorts
@testable import PrestoCVPresentation

/// The status the person is told of as it changes (VoiceOver): a problem, a failure and the save after one, never each
/// write of the autosave, which the status line shows (#402, as the legacy editor's `SaveAnnouncement`).
@MainActor
@Suite("Status change")
struct StatusChangeTests {

    @Test("opening a CV, typing in it and the autosave's writes change nothing to tell: the status stays where it settled")
    func typingAndSavingTellNothing() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        #expect(editor.statusChange == nil, "the CV opened saved")
        await world.editing.gate.close()

        editor.type(\.fullName, "Mara Ellison-Reyes")
        #expect(editor.saveStatus == .pending)
        await world.passThePause(thenWrites: 1)
        #expect(editor.saveStatus == .saving)
        #expect(editor.statusChange == nil, "the write is at the store's door")
        await world.editing.gate.open()
        await waitUntil("the write is stored") { editor.saveStatus == .saved }

        #expect(editor.statusChange == nil, "a save that went well is told by the status line only")
    }

    @Test("a problem met is told, and so is the save once the text reads again")
    func aProblemAndTheSaveAfterItAreTold() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())

        editor.type(\.email, "mara at example")
        #expect(editor.statusChange == nil, "the person is still in the field")
        editor.fieldWasLeft(.email)
        #expect(editor.statusChange == .unreadable(.email))

        editor.type(\.email, "mara@example.org")
        await editor.saveNow()
        #expect(editor.statusChange == .saved)
    }

    @Test("a write the store refused is told, and so is the first save of a new CV")
    func aFailureAndAFirstSaveAreTold() async throws {
        let world = Editing()
        let editor = world.editor(.blank)
        await editor.load()
        #expect(editor.statusChange == nil, "a blank CV opens with not enough to store")

        editor.type(\.fullName, "Tobias Renn")
        await editor.saveNow()
        #expect(editor.statusChange == .saved)

        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }
        editor.type(\.fullName, "Tobias Renn-Okafor")
        await editor.saveNow()
        #expect(editor.statusChange == .failed)
    }
}

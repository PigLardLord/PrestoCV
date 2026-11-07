import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// What the save status and "saved on this device" say as failures of text writes, failures of look and language changes,
/// and copies come and go: a failure of one kind is cleared only by what resolves it, and never hides the other.
@MainActor
@Suite("Editor save status across failures")
struct EditorFailureStatusTests {

    /// What the editor shows at one point of a scenario.
    struct Shown: Equatable, CustomTestStringConvertible {
        let status: SaveStatus
        let savedOnThisDevice: Bool
        var testDescription: String { "\(status), saved: \(savedOnThisDevice)" }
        init(_ status: SaveStatus, _ saved: Bool) { self.status = status; savedOnThisDevice = saved }
        @MainActor init(_ editor: EditorViewModel) { self.init(editor.saveStatus, editor.isSavedOnThisDevice) }
    }

    enum Scenario: String, CaseIterable, CustomTestStringConvertible {
        case changeFailsThenSucceeds = "a change fails, then succeeds, with no text edited"
        case changeSucceedsWhileTextWriteFailed = "a change fails while a text write has also failed; the change then succeeds"
        case textWriteSucceedsWhileChangeFailed = "a text write fails, then succeeds, while a change failure is outstanding"
        case copySavedWhileTitleHeld = "a copy is saved while a title edit is held"

        var testDescription: String { rawValue }

        /// What is shown after each step, in order.
        var expected: [Shown] {
            switch self {
            case .changeFailsThenSucceeds:
                [Shown(.saved, true), Shown(.failed, false), Shown(.saved, true)]
            case .changeSucceedsWhileTextWriteFailed:
                [Shown(.failed, false), Shown(.failed, false), Shown(.failed, false), Shown(.saved, true)]
            case .textWriteSucceedsWhileChangeFailed:
                [Shown(.failed, false), Shown(.failed, false), Shown(.failed, false), Shown(.saved, true)]
            case .copySavedWhileTitleHeld:
                [Shown(.conflict, false), Shown(.pending, false), Shown(.saved, true)]
            }
        }
    }

    func run(_ scenario: Scenario, in world: Editing) async throws -> [Shown] {
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        let fails = { world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] } }
        let changeFails = { world.editing.restyleErrors.withLock { $0 = [EditFailure.unavailable] } }
        switch scenario {
        case .changeFailsThenSucceeds:
            var shown = [Shown(editor)]
            changeFails()
            await editor.setDocumentLanguage("de")
            shown.append(Shown(editor))
            await editor.setDocumentLanguage("de")
            shown.append(Shown(editor))
            return shown
        case .changeSucceedsWhileTextWriteFailed:
            fails()
            editor.type(\.fullName, "Mara A")
            await editor.saveNow()
            var shown = [Shown(editor)]
            changeFails()
            await editor.setDocumentLanguage("de")
            shown.append(Shown(editor))
            await editor.setDocumentLanguage("de")
            shown.append(Shown(editor))
            await editor.saveNow()
            shown.append(Shown(editor))
            return shown
        case .textWriteSucceedsWhileChangeFailed:
            changeFails()
            await editor.setDocumentLanguage("de")
            var shown = [Shown(editor)]
            fails()
            editor.type(\.fullName, "Mara A")
            await editor.saveNow()
            shown.append(Shown(editor))
            await editor.saveNow()
            shown.append(Shown(editor))
            await editor.setDocumentLanguage("de")
            shown.append(Shown(editor))
            return shown
        case .copySavedWhileTitleHeld:
            try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
            editor.type(\.fullName, "Mara Ellison-Renn")
            await editor.saveNow()
            var shown = [Shown(editor)]
            await world.editing.duplicateGate.close()
            let copying = Task { await editor.saveAsCopy() }
            await waitUntil("the copy to wait at the store") { await world.editing.duplicateGate.waiting == 1 }
            editor.type(\.title, "Product roles")
            await world.editing.duplicateGate.open()
            await copying.value
            shown.append(Shown(editor))
            await editor.saveNow()
            shown.append(Shown(editor))
            return shown
        }
    }

    @Test("the save status and the saved flag follow each kind of failure until its own cause is resolved", arguments: Scenario.allCases)
    func statusFollowsEachFailure(_ scenario: Scenario) async throws {
        let shown = try await run(scenario, in: Editing())

        #expect(shown == scenario.expected)
    }
}

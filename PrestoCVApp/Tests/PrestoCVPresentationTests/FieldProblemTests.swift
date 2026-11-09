import Testing
import PrestoCVPresentation

/// When a field's text that cannot be read is named: once the person has left the field, or tried to store, and never
/// while they are still typing it (#33: "the email is red after one character").
@MainActor
@Suite("Field problems")
struct FieldProblemTests {

    @Test("text that cannot be read yet is no problem while the person is still in the field: it waits for them")
    func noProblemWhileTheFieldIsFocused() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())

        editor.type(\.email, "m")
        editor.type(\.email, "mara at")

        #expect(editor.problems.isEmpty, "the person has not left the field yet")
        #expect(editor.saveStatus == .pending, "the email waits for the person to finish it, so the store does not hold it")
    }

    @Test("once the person leaves a field whose text cannot be read, the field has a problem and the status names it")
    func problemAfterTheFieldIsLeft() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.type(\.email, "mara at example")
        editor.type(\.phone, "+39 055 0100")

        editor.fieldWasLeft(.phone)
        #expect(editor.problems.isEmpty, "a phone number that reads is no problem")
        editor.fieldWasLeft(.email)

        #expect(editor.problems.map(\.field) == [.email])
        #expect(editor.problems.map(\.code) == [.unreadable])
        #expect(editor.problems.map(\.row) == [nil], "the email is a detail, on no row")
        #expect(editor.saveStatus == .unreadable(.email))
    }

    @Test("a problem goes as soon as the text reads, and text typed again after that waits until the field is left again")
    func problemGoesWhenTheTextReads() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.type(\.email, "mara at example")
        editor.fieldWasLeft(.email)

        editor.type(\.email, "mara@example.org")
        #expect(editor.problems.isEmpty, "the email reads now")

        editor.type(\.email, "mara@")
        #expect(editor.problems.isEmpty, "the person is back in the field, typing")
        editor.fieldWasLeft(.email)
        #expect(editor.problems.map(\.field) == [.email])
    }

    @Test("a store attempt names every field that cannot be read, one problem per row and field, in the form's order")
    func onePerRowAndField() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        editor.addRow(to: .experiences)
        editor.content.experiences[0].periodStart = "last spring"
        editor.content.experiences[1].periodStart = "two winters ago"
        editor.type(\.email, "mara at example")
        editor.fieldWasLeft(.email)
        editor.fieldWasLeft(.email)

        await editor.saveNow()

        let rows = editor.content.experiences.map(\.id)
        #expect(editor.problems.map(\.field) == [.email, .experiencePeriod, .experiencePeriod])
        #expect(editor.problems.map(\.row) == [nil, rows[0], rows[1]])
        #expect(editor.saveStatus == .unreadable(.email), "the status names the first problem")
    }

    @Test("the list's store of what the editor shows is no store attempt of the person: a field they are in stays quiet")
    func theListsStoreNamesNoProblem() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.type(\.email, "mara at")

        await editor.saveWhatItShows()

        #expect(editor.problems.isEmpty)
        #expect(editor.saveStatus == .pending)
    }
}

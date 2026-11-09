import Testing
import PrestoCVPresentation

/// The period of a row: its problem is named on its own row, once the person has left the period or tried to store, and
/// goes as soon as the period reads. A period that goes on has no end.
@MainActor
@Suite("Period problems")
struct PeriodProblemTests {

    @Test("an end before the start is named on its own row once the person leaves the period, and goes when it is right")
    func endBeforeStartIsNamedOnItsRow() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        editor.addRow(to: .experiences)
        let rows = editor.content.experiences.map(\.id)
        editor.content.experiences[1].period.start.year = "2021"
        editor.content.experiences[1].period.start.month = 3
        editor.content.experiences[1].period.end.year = "2019"
        #expect(editor.problems.isEmpty, "the person is still in the period")

        editor.fieldWasLeft(.experiencePeriod, row: rows[1])

        #expect(editor.problems.map(\.row) == [rows[1]])
        #expect(editor.problem(of: .experiencePeriod, row: rows[1]) == .endBeforeStart)
        #expect(editor.problem(of: .experiencePeriod, row: rows[0]) == nil)
        #expect(editor.saveStatus == .unreadable(.experiencePeriod))
        // The note under the period is hidden from VoiceOver: the change of status is what it announces
        #expect(editor.statusChange == .unreadable(.experiencePeriod), "VoiceOver is told when the person leaves")
        editor.content.experiences[1].period.end.year = "2023"
        #expect(editor.problems.isEmpty, "the period reads now")
    }

    @Test("a period that goes on and has an end too is named, as one that cannot be read")
    func currentWithAnEndIsNamed() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .education)
        let row = editor.content.education[0].id
        editor.content.education[0].period.start.year = "2018"
        editor.content.education[0].period.isCurrent = true
        editor.content.education[0].period.end.year = "2022"

        editor.fieldWasLeft(.educationPeriod, row: row)

        #expect(editor.problem(of: .educationPeriod, row: row) == .unreadable)
    }

    @Test("turning \"currently here\" on clears the end, and the form no longer asks for one")
    func currentClearsTheEnd() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        editor.content.experiences[0].period.start.year = "2018"
        editor.content.experiences[0].period.end.year = "2022"
        editor.content.experiences[0].period.end.month = 4
        #expect(editor.content.experiences[0].period.asksForEnd)

        editor.content.experiences[0].period.isCurrent = true

        let period = editor.content.experiences[0].period
        #expect(period.end.year == "" && period.end.month == nil)
        #expect(!period.asksForEnd)
        await editor.saveNow()
        #expect(editor.problems.isEmpty, "a start and \"currently here\" read")
    }
}

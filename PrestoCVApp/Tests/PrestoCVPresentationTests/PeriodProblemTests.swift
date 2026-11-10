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
        // VoiceOver is told by the status, which names the problem; the note is read with the period
        #expect(editor.announcement?.status == .unreadable(.experiencePeriod), "VoiceOver is told when the person leaves")
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

    // MARK: - A problem met while the status names another

    @Test("a period problem met while an invalid email holds the status is told by itself")
    func periodProblemUnderAnotherIsTold() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        let row = editor.content.experiences[0].id
        editor.type(\.email, "mara at example")
        editor.fieldWasLeft(.email)
        #expect(editor.announcement?.problems == [], "the email is told by the status")
        editor.viewToldTheAnnouncement()
        editor.content.experiences[0].period.start.year = "2021"
        editor.content.experiences[0].period.end.year = "2019"

        editor.fieldWasLeft(.experiencePeriod, row: row)

        #expect(editor.announcement.map { periodsBeforeTheirStart($0.problems) } == [row])
        #expect(editor.announcement?.status == nil, "the status did not move")
        #expect(editor.saveStatus == .unreadable(.email), "the status still tells the first problem")
    }

    @Test("an end before the start on a second row is told with its row, though the status does not change")
    func secondRowIsTold() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        editor.addRow(to: .experiences)
        let rows = editor.content.experiences.map(\.id)
        for index in 0..<2 {
            editor.content.experiences[index].period.start.year = "2021"
            editor.content.experiences[index].period.end.year = "2019"
        }
        editor.fieldWasLeft(.experiencePeriod, row: rows[0])
        #expect(editor.announcement?.problems == [], "the first problem is told by the status")
        editor.viewToldTheAnnouncement()

        editor.fieldWasLeft(.experiencePeriod, row: rows[1])

        #expect(editor.announcement.map { periodsBeforeTheirStart($0.problems) } == [rows[1]])
        #expect(editor.announcement?.status == nil, "the status did not move")
    }

    @Test("a problem that read and broke again is told again, while another problem holds the status")
    func problemMetAgainIsToldAgain() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        let row = editor.content.experiences[0].id
        editor.type(\.email, "mara at example")
        editor.fieldWasLeft(.email)
        editor.content.experiences[0].period.start.year = "2021"
        editor.content.experiences[0].period.end.year = "2019"
        editor.fieldWasLeft(.experiencePeriod, row: row)
        let first = editor.announcement
        #expect(first?.problems.map(\.row) == [row])
        editor.viewToldTheAnnouncement()

        editor.content.experiences[0].period.end.year = "2023"
        editor.content.experiences[0].period.end.year = "2019"
        editor.fieldWasLeft(.experiencePeriod, row: row)

        #expect(editor.announcement?.problems.map(\.row) == [row])
        #expect(editor.announcement != first, "a new value, so the view tells it again")
    }

    @Test("a store attempt that meets several problems while an invalid email holds the status tells each of them")
    func severalProblemsUnderAnotherAreEachTold() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        editor.addRow(to: .experiences)
        let rows = editor.content.experiences.map(\.id)
        editor.type(\.email, "mara at example")
        editor.fieldWasLeft(.email)
        editor.viewToldTheAnnouncement()
        for index in 0..<2 {
            editor.content.experiences[index].period.start.year = "2021"
            editor.content.experiences[index].period.end.year = "2019"
        }

        await editor.saveNow()

        #expect(editor.saveStatus == .unreadable(.email), "the status still tells the email")
        #expect(editor.announcement?.status == nil, "the status did not move")
        #expect(editor.announcement.map { periodsBeforeTheirStart($0.problems) } == rows, "both periods, in the order of the form")
    }

    @Test("a store attempt that changes the status to the first of several problems tells the others after it")
    func problemsAfterTheStatusAreTold() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        editor.addRow(to: .experiences)
        let rows = editor.content.experiences.map(\.id)
        editor.type(\.email, "mara at example")
        for index in 0..<2 {
            editor.content.experiences[index].period.start.year = "2021"
            editor.content.experiences[index].period.end.year = "2019"
        }

        await editor.saveNow()

        #expect(editor.announcement?.status == .unreadable(.email), "the status tells the first problem")
        #expect(editor.announcement.map { periodsBeforeTheirStart($0.problems) } == rows, "then every other one, and not the email")
    }

    @Test("the first problem alone is told by the status, and not again by its note")
    func firstProblemAloneIsNotTwiceTold() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        let row = editor.content.experiences[0].id
        editor.content.experiences[0].period.start.year = "2021"
        editor.content.experiences[0].period.end.year = "2019"

        editor.fieldWasLeft(.experiencePeriod, row: row)

        #expect(editor.announcement?.status == .unreadable(.experiencePeriod))
        #expect(editor.announcement?.problems == [])
    }

    /// The rows of `problems` when each is an end of a job's period before its start, in their order; nil otherwise.
    private func periodsBeforeTheirStart(_ problems: [FieldProblem]) -> [RowID?]? {
        problems.allSatisfy { $0.field == .experiencePeriod && $0.code == .endBeforeStart } ? problems.map(\.row) : nil
    }
}

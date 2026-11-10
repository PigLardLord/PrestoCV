import Testing
import PrestoCVWorkflowPorts
@testable import PrestoCVPresentation

/// What VoiceOver is told as the editor changes, in one announcement per change: where the status settled (a problem, a
/// failure and the save after one, never each write of the autosave, which the status line shows; #402, as the legacy
/// editor's `SaveAnnouncement`), then the problems met that the status does not name. What waits until the view told it
/// is joined with what comes next, so nothing is lost between two updates of the view.
@MainActor
@Suite("Status change")
struct StatusChangeTests {

    @Test("opening a CV, typing in it and the autosave's writes change nothing to tell: the status stays where it settled")
    func typingAndSavingTellNothing() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        #expect(editor.announcement == nil, "the CV opened saved")
        await world.editing.gate.close()

        editor.type(\.fullName, "Mara Ellison-Reyes")
        #expect(editor.saveStatus == .pending)
        await world.passThePause(thenWrites: 1)
        #expect(editor.saveStatus == .saving)
        #expect(editor.announcement == nil, "the write is at the store's door")
        await world.editing.gate.open()
        await waitUntil("the write is stored") { editor.saveStatus == .saved }

        #expect(editor.announcement == nil, "a save that went well is told by the status line only")
    }

    @Test("a problem met is told, and so is the save once the text reads again")
    func aProblemAndTheSaveAfterItAreTold() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())

        editor.type(\.email, "mara at example")
        #expect(editor.announcement == nil, "the person is still in the field")
        editor.fieldWasLeft(.email)
        #expect(editor.announcement?.status == .unreadable(.email))
        #expect(editor.announcement?.problems == [], "the status names the email: its note would tell it twice")
        editor.viewToldTheAnnouncement()

        editor.type(\.email, "mara@example.org")
        await editor.saveNow()
        #expect(editor.announcement?.status == .saved)
    }

    @Test("a write the store refused is told, and so is the first save of a new CV")
    func aFailureAndAFirstSaveAreTold() async throws {
        let world = Editing()
        let editor = world.editor(.blank)
        await editor.load()
        #expect(editor.announcement == nil, "a blank CV opens with not enough to store")

        editor.type(\.fullName, "Tobias Renn")
        await editor.saveNow()
        #expect(editor.announcement?.status == .saved)
        editor.viewToldTheAnnouncement()

        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }
        editor.type(\.fullName, "Tobias Renn-Okafor")
        await editor.saveNow()
        #expect(editor.announcement?.status == .failed)
    }

    // MARK: - One announcement per change

    @Test("a store attempt that meets several problems is one announcement: the status, then every other problem")
    func oneStoreAttemptIsOneAnnouncement() async throws {
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
        let before = editor.announcements

        await editor.saveNow()

        #expect(editor.announcements == before + 1, "one announcement, so that none cuts another short")
        #expect(editor.announcement?.status == .unreadable(.email))
        #expect(editor.announcement?.problems.map(\.row) == rows.map(Optional.some), "both periods, in the order of the form")
    }

    @Test("a problem met before the view told the one before is joined to it, not put in its place")
    func changesBeforeTheViewToldAreJoined() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        let row = editor.content.experiences[0].id
        editor.type(\.email, "mara at example")
        editor.content.experiences[0].period.start.year = "2021"
        editor.content.experiences[0].period.end.year = "2019"

        // In one turn, as a month picked in the menu does: the view reads the value once
        editor.fieldWasLeft(.email)
        editor.fieldWasLeft(.experiencePeriod, row: row)

        #expect(editor.announcement?.status == .unreadable(.email), "the email is still to tell")
        #expect(editor.announcement?.problems.map(\.row) == [row], "and the period after it")
    }

    @Test("a status that takes the place of the one naming a problem leaves that problem to its note")
    func replacedStatusLeavesItsProblemToItsNote() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.type(\.email, "mara at example")
        editor.fieldWasLeft(.email)
        #expect(editor.announcement?.status == .unreadable(.email))

        editor.type(\.fullName, "Mara Ellison-Reyes")
        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }
        await editor.saveNow()

        #expect(editor.announcement?.status == .failed)
        #expect(editor.announcement?.problems.map(\.field) == [.email], "the failure does not name the email: its note does")
    }

    @Test("an announcement the view told goes, and a report of an older one keeps what came after it")
    func toldAnnouncementGoes() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        let row = editor.content.experiences[0].id
        editor.type(\.email, "mara at example")
        editor.content.experiences[0].period.start.year = "2021"
        editor.content.experiences[0].period.end.year = "2019"
        editor.fieldWasLeft(.email)
        let older = try #require(editor.announcement)
        editor.fieldWasLeft(.experiencePeriod, row: row)
        let newer = try #require(editor.announcement)

        editor.announcementWasTold(older)
        #expect(editor.announcement == newer, "the period came after what the view told")
        editor.announcementWasTold(newer)
        #expect(editor.announcement == nil)

        editor.type(\.email, "mara@example.org")
        #expect(editor.announcement?.status == .unreadable(.experiencePeriod))
        #expect(editor.announcement?.problems == [], "what was told is not told again")
    }

    // MARK: - What no longer holds before the view told it

    @Test("a problem fixed before the view told it is not told, while a failure holds the status")
    func aProblemFixedBeforeItWasToldIsNotTold() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }
        editor.type(\.fullName, "Mara Ellison-Reyes")
        await editor.saveNow()
        #expect(editor.saveStatus == .failed)
        editor.viewToldTheAnnouncement()
        editor.type(\.email, "mara at example")
        editor.fieldWasLeft(.email)
        #expect(editor.announcement?.status == nil, "the failure still holds: it was told")
        #expect(editor.announcement?.problems.map(\.field) == [.email])

        editor.type(\.email, "mara@example.org")

        #expect(editor.announcement == nil, "the email reads again: its note would tell a problem the person fixed")
    }

    @Test("a problem the status names, fixed before the view told it, is not told")
    func aProblemTheStatusNamesFixedBeforeItWasToldIsNotTold() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.type(\.email, "mara at example")
        editor.fieldWasLeft(.email)
        #expect(editor.announcement?.status == .unreadable(.email))

        editor.type(\.email, "mara@example.org")

        #expect(editor.announcement == nil, "the email reads again: the status no longer stands there")
    }

    @Test("a problem whose row went before the view told it is not told")
    func aProblemOfARemovedRowIsNotTold() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        let row = editor.content.experiences[0].id
        editor.type(\.email, "mara at example")
        editor.content.experiences[0].period.start.year = "2021"
        editor.content.experiences[0].period.end.year = "2019"
        editor.fieldWasLeft(.email)
        editor.fieldWasLeft(.experiencePeriod, row: row)
        #expect(editor.announcement?.problems.map(\.row) == [row])

        editor.removeRow(in: .experiences, id: row)
        editor.confirmRemoval()

        #expect(!editor.content.experiences.contains { $0.id == row })
        #expect(editor.announcement?.status == .unreadable(.email), "the email still cannot be read")
        #expect(editor.announcement?.problems == [], "the period went with its row")
    }

    @Test("a status whose problem was fixed before the view told it gives way to the problem still there")
    func aFixedProblemsStatusGivesWayToTheNext() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        let row = editor.content.experiences[0].id
        editor.type(\.email, "mara at example")
        editor.content.experiences[0].period.start.year = "2021"
        editor.content.experiences[0].period.end.year = "2019"
        await editor.saveNow()
        #expect(editor.announcement?.status == .unreadable(.email))
        #expect(editor.announcement?.problems.map(\.row) == [row])

        editor.type(\.email, "mara@example.org")

        #expect(editor.announcement?.status == .unreadable(.experiencePeriod), "the period now keeps the CV from being stored")
        #expect(editor.announcement?.problems == [], "the status names the period: its note would tell it twice")
    }
}

extension EditorViewModel {
    /// What the view does once it has posted the announcement.
    func viewToldTheAnnouncement() {
        if let told = announcement { announcementWasTold(told) }
    }
}

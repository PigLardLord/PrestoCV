import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// For every save status: whether it keeps the person in the editor, what the notice above the form offers, and what the
/// shell answers when the person opens another CV or goes back (#402, decisions 7, 8 and 13).
@MainActor
@Suite("Leave verdict per status")
struct LeaveVerdictTests {

    /// A way to bring the shell's open editor to one status.
    enum Case: String, CaseIterable, CustomTestStringConvertible {
        case saved, pending, saving, notEnoughContent, textTooLong, tooManyEntries, tooLarge, unreadable, conflict,
             deletedElsewhere, failed

        var testDescription: String { rawValue }

        var status: SaveStatus {
            switch self {
            case .saved: .saved
            case .pending: .pending
            case .saving: .saving
            case .notEnoughContent: .notEnoughContent
            case .textTooLong: .textTooLong(.summary)
            case .tooManyEntries: .tooManyEntries(.skills)
            case .tooLarge: .tooLarge
            case .unreadable: .unreadable(.email)
            case .conflict: .conflict
            case .deletedElsewhere: .deletedElsewhere
            case .failed: .failed
            }
        }

        var blocks: Bool {
            switch self {
            case .conflict, .deletedElsewhere, .failed, .tooLarge, .textTooLong, .tooManyEntries: true
            case .saved, .pending, .saving, .notEnoughContent, .unreadable: false
            }
        }

        var actions: [StatusAction] {
            switch self {
            case .conflict: [.reload, .saveAsCopy]
            case .deletedElsewhere: [.saveAsCopy, .discard]
            case .failed: [.retry]
            case .saved, .pending, .saving, .notEnoughContent, .textTooLong, .tooManyEntries, .tooLarge, .unreadable: []
            }
        }

        /// Opens a CV in `shell` and brings its editor to this case's status.
        @MainActor
        func reach(in world: Editing, _ shell: ShellNavigationModel) async throws -> EditorViewModel {
            if self == .tooManyEntries {
                let skills = (0...CVLimits.maxEntriesPerSection).map { Skill(name: "Skill \($0)") }
                let draft = CV(id: world.editing.ids.next(), personal: PersonalDetails(fullName: "Tobias Renn"),
                               sections: CVSections(skills: skills))
                shell.open(.draft(CVDraft(cv: draft)))
                let editor = try #require(shell.editor)
                await editor.load()
                return editor
            }
            let cv = try await world.storedCV()
            shell.open(.stored(CVReference(id: cv.id)))
            let editor = try #require(shell.editor)
            await editor.load()
            switch self {
            case .saved, .tooManyEntries: break
            case .pending: editor.type(\.fullName, "Mara Ellison-Renn")
            case .saving:
                await world.editing.gate.close()
                editor.type(\.fullName, "Mara Ellison-Renn")
                Task { await editor.saveNow() }
                await waitUntil("the write to wait at the store's door") { await world.editing.gate.waiting == 1 }
            case .notEnoughContent: editor.type(\.fullName, "")
            case .textTooLong: editor.type(\.summary, String(repeating: "a", count: CVLimits.maxTextCharacters + 1))
            case .tooLarge, .failed:
                world.editing.writeErrors.withLock { $0 = [self == .failed ? EditFailure.unavailable : .tooLarge] }
                editor.type(\.fullName, "Mara Ellison-Renn")
                await editor.saveNow()
            case .unreadable:
                editor.type(\.email, "mara at example")
                editor.fieldWasLeft(.email)
            case .conflict:
                try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
                editor.type(\.fullName, "Mara Ellison-Renn")
                await editor.saveNow()
            case .deletedElsewhere:
                try await world.editing.delete(cv)
                editor.type(\.fullName, "Mara Ellison-Renn")
                await editor.saveNow()
            }
            return editor
        }
    }

    @Test("every status is covered by a case")
    func everyStatusIsCovered() {
        let covered = Set(Case.allCases.map(\.status))
        for status in covered {
            switch status {
            case .saved, .pending, .saving, .notEnoughContent, .textTooLong, .tooManyEntries, .tooLarge, .unreadable,
                 .conflict, .deletedElsewhere, .failed: break
            }
        }
        #expect(covered.count == Case.allCases.count)
    }

    @Test("a status keeps the person in the editor exactly when no write can store the text as it is", arguments: Case.allCases)
    func blocksLeaving(_ given: Case) {
        #expect(given.status.blocksLeaving == given.blocks)
    }

    @Test("the notice offers the ways on of its status, in order, and none where the person must change the text", arguments: Case.allCases)
    func statusActions(_ given: Case) {
        #expect(given.status.statusActions == given.actions)
    }

    @Test("opening another CV or going back stays exactly while the status blocks leaving, and says why", arguments: Case.allCases)
    func verdict(_ given: Case) async throws {
        let world = Editing()
        let other = try await world.editing.stored(title: "Teaching roles", fullName: "Tobias Renn", language: "en")
        let shell = world.shell()
        let editor = try await given.reach(in: world, shell)
        #expect(editor.saveStatus == given.status)
        let expected: LeaveVerdict = given.blocks ? .stayed(given.status) : .left

        #expect(shell.canLeave == !given.blocks)
        if given.blocks {
            #expect(shell.open(.stored(CVReference(id: other.id))) == expected)
            #expect(shell.deselect() == expected)
            #expect(shell.editor === editor, "the person's text stays where they can still keep it")
        } else {
            #expect(shell.deselect() == expected)
            #expect(shell.editor == nil)
        }
        await world.editing.gate.open()
    }
}

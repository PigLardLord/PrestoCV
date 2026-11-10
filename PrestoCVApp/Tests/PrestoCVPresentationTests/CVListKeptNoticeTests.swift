import Testing
import PrestoCVApplication
import PrestoCVDomain
@testable import PrestoCVPresentation

/// The notices of the editors the shell kept (#402, decisions 16 and 17): under the row of their CV when the list has it,
/// above the rows otherwise, each with what its text needs.
@MainActor
@Suite("CV list: kept editors")
struct CVListKeptNoticeTests {

    @Test("a kept editor of a listed CV shows under its row, named by the row's label")
    func listedCVGoesUnderItsRow() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        let kept = KeptEditor(id: 1, reference: world.reference(cv), status: .failed, title: .name("Backend draft"))

        let notices = list.keptNotices([kept])

        #expect(notices.above.isEmpty)
        #expect(notices.under[world.reference(cv)] == KeptNotice(id: 1, label: "Backend", status: .failed, canRetry: true))
    }

    @Test("a kept draft and a kept CV the list does not have show above the rows, named by their own title")
    func unlistedOnesGoAbove() async throws {
        let world = Browsing()
        let list = await world.loadedList()
        let later = try await world.stored(title: "Later")
        let draft = KeptEditor(id: 2, reference: nil, status: .unreadable(.email), title: .person("Mara Ellison"))
        let unlisted = KeptEditor(id: 3, reference: world.reference(later), status: .conflict, title: .name("Later"))
        let untitled = KeptEditor(id: 4, reference: nil, status: .pending, title: .untitled)

        let notices = list.keptNotices([draft, unlisted, untitled])

        #expect(notices.under.isEmpty)
        #expect(notices.above == [
            KeptNotice(id: 2, label: "Mara Ellison", status: .unreadable(.email), canRetry: false),
            KeptNotice(id: 3, label: "Later", status: .conflict, canRetry: false),
            KeptNotice(id: 4, label: Browsing.untitled, status: .pending, canRetry: true),
        ])
    }

    @Test("a row with two kept editors shows the one left last under it and the other above: none is hidden")
    func secondKeptEditorOfARowGoesAbove() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        let editors = [
            KeptEditor(id: 1, reference: world.reference(cv), status: .failed, title: .name("Backend")),
            KeptEditor(id: 2, reference: world.reference(cv), status: .tooLarge, title: .name("Backend")),
        ]

        let notices = list.keptNotices(editors)

        #expect(notices.under[world.reference(cv)] == KeptNotice(id: 2, label: "Backend", status: .tooLarge, canRetry: false))
        #expect(notices.above == [KeptNotice(id: 1, label: "Backend", status: .failed, canRetry: true)])
    }

    @Test("the notices follow the order the editors were left in")
    func orderIsKept() async throws {
        let world = Browsing()
        let first = try await world.stored(title: "First")
        let second = try await world.stored(title: "Second")
        let list = await world.loadedList()

        let notices = list.keptNotices([
            KeptEditor(id: 5, reference: nil, status: .failed, title: .name("Draft B")),
            KeptEditor(id: 7, reference: world.reference(second), status: .failed, title: .name("Second")),
            KeptEditor(id: 9, reference: nil, status: .failed, title: .name("Draft A")),
            KeptEditor(id: 11, reference: world.reference(first), status: .failed, title: .name("First")),
        ])

        #expect(notices.above.map(\KeptNotice.id) == [5, 9])
        #expect(notices.under.mapValues(\KeptNotice.id) == [world.reference(second): 7, world.reference(first): 11])
    }

    @Test("no kept editor, no notice")
    func nothingKept() async {
        let list = await Browsing().loadedList()

        #expect(list.keptNotices([]) == KeptNotices(above: [], under: [:]))
    }
}

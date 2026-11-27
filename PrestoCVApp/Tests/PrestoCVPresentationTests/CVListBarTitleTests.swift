import Testing
import PrestoCVApplication
import PrestoCVDomain
@testable import PrestoCVPresentation

@MainActor
@Suite("Editor bar title")
struct CVListBarTitleTests {

    @Test("a CV not stored yet reads with the bar's word for a new CV, whichever way it was started")
    func newCVUsesTheBarWord() async throws {
        let list = await Browsing().loadedList()

        #expect(list.barTitle(of: .blank, selected: nil, editorTitle: "") == Browsing.barNewCV)
        #expect(list.barTitle(of: nil, selected: nil, editorTitle: "") == Browsing.barNewCV)
    }

    @Test("a CV with no name reads with the bar's word, and the list keeps its own")
    func untitledUsesTheBarWord() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "", fullName: "")
        let list = await world.loadedList()
        let reference = world.reference(cv)

        #expect(list.barTitle(of: .stored(reference), selected: reference, editorTitle: "") == Browsing.barUntitled)
        #expect(list.rows.first?.label == Browsing.untitled)
    }

    @Test("two CVs with no name are numbered in the bar as the list numbers them, with the bar's word")
    func untitledNumbersLikeTheList() async throws {
        let world = Browsing()
        let first = try await world.stored(title: "", fullName: "")
        let second = try await world.stored(title: "", fullName: "")
        let list = await world.loadedList()

        let cvs = [first, second].map(world.reference)
        let bar = cvs.map { list.barTitle(of: .stored($0), selected: $0, editorTitle: "") }
        let listed = list.rows.reduce(into: [CVReference: String]()) { $0[$1.reference] = $1.label }

        #expect(Set(bar).count == 2)
        #expect(bar == cvs.map { (listed[$0] ?? "").replacingOccurrences(of: Browsing.untitled, with: Browsing.barUntitled) })
        #expect(bar.allSatisfy { $0.hasPrefix(Browsing.barUntitled) })
    }

    @Test("a CV with a name reads with its own label")
    func namedKeepsItsLabel() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        let reference = world.reference(cv)

        #expect(list.barTitle(of: .stored(reference), selected: reference, editorTitle: "x") == "Backend")
    }

    @Test("a stored CV the list does not hold reads with the editor's own title")
    func unlistedFallsBack() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()

        #expect(list.barTitle(of: .stored(world.reference(cv)), selected: nil, editorTitle: "Backend") == "Backend")
    }
}

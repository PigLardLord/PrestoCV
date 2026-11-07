import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation

@MainActor
@Suite("Look picker")
struct LookViewModelTests {

    private let modernForest = DesignChoice(design: "modern", palette: "forest", fonts: "serif")

    @Test("the picker starts from the look the CV holds, and offers the choices it is given")
    func startsFromTheCVsLook() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: modernForest)
        let look = world.look(of: cv)

        await look.load()

        #expect(look.shown == EditorLook(design: "modern", palette: "forest", fonts: "serif"))
        #expect(look.chosen.isEmpty)
        #expect(look.status == .ready)
        #expect(look.choices.designs.map(\.id) == ["classic", "modern"])
        #expect(look.choices.palettes.map(\.nameCode) == ["palette.ocean", "palette.forest"])
        #expect(look.choices.fontSchemes.map(\.id) == ["sans", "serif"])
    }

    @Test("a CV with no look shows the defaults it was given")
    func noLookShowsTheDefaults() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let look = world.look(of: cv)

        await look.load()

        #expect(look.shown == EditorLook(design: "classic", palette: "ocean", fonts: "sans"))
        #expect(look.chosen.isEmpty)
    }

    @Test("choosing only a palette changes only the palette")
    func onlyChosenPartChanges() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: modernForest)
        let look = world.look(of: cv)
        await look.load()

        look.choose(palette: "ocean")
        #expect(look.chosen == [.palette])
        await look.apply()

        #expect(world.editing.looks.withLock { $0.map(\.parts) } == [[.palette]])
        let stored = try await world.editing.inStore(cv.id).design
        #expect(stored == DesignChoice(design: "modern", palette: "ocean", fonts: "serif"))
        #expect(look.status == .applied)
    }

    @Test("an id the app does not know stays as the CV holds it")
    func unknownIdsStay() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: DesignChoice(design: "retired-design", palette: "gone", fonts: nil))
        let look = world.look(of: cv)
        await look.load()

        look.choose(fonts: "serif")
        await look.apply()

        #expect(look.shown == EditorLook(design: "retired-design", palette: "gone", fonts: "serif"))
        #expect(!look.choices.designs.contains { $0.id == look.shown.design })
        let stored = try await world.editing.inStore(cv.id).design
        #expect(stored == DesignChoice(design: "retired-design", palette: "gone", fonts: "serif"))
    }

    @Test("two choices made before either is stored send one change that holds both")
    func twoChoicesBeforeStoreGiveOneChange() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: modernForest)
        let look = world.look(of: cv)
        await look.load()

        look.choose(palette: "ocean")
        look.choose(fonts: "sans")
        look.choose(palette: "forest")
        await look.apply()

        #expect(world.editing.looks.withLock { $0.count } == 1)
        #expect(world.editing.looks.withLock { $0.first?.parts } == [.palette, .fonts])
        let stored = try await world.editing.inStore(cv.id).design
        #expect(stored == DesignChoice(design: "modern", palette: "forest", fonts: "sans"))
    }

    @Test("a change over another window's save is a conflict code, and the CV is not overwritten")
    func staleLookChangeIsConflict() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: modernForest)
        let look = world.look(of: cv)
        await look.load()
        try await world.editing.otherWindowSaves(cv, fullName: "Someone Else")

        look.choose(design: "classic")
        await look.apply()

        #expect(look.status == .conflict)
        let stored = try await world.editing.inStore(cv.id)
        #expect(stored.design == modernForest)
        #expect(stored.personal.fullName == "Someone Else")
    }

    @Test("a look change leaves the text the person typed as it is")
    func lookChangeKeepsTheText() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", fullName: "Mara Ellison")
        let look = world.look(of: cv)
        await look.load()

        look.choose(design: "modern")
        await look.apply()

        let stored = try await world.editing.inStore(cv.id)
        #expect(stored.title == "Backend")
        #expect(stored.personal == cv.personal)
        #expect(stored.design?.design == "modern")
    }

    @Test("a CV that is not in the store is a code, and a cancelled task is no failure")
    func missingAndCancelled() async throws {
        let world = Browsing()
        let gone = try await world.stored(title: "Gone")
        let missing = world.look(of: gone)
        try await world.editing.delete(gone)
        await missing.load()
        #expect(missing.status == .missing)

        let cv = try await world.stored(title: "Backend")
        let look = world.look(of: cv)
        await look.load()
        try await world.editing.otherWindowSaves(cv, fullName: "Someone Else")
        look.choose(design: "modern")
        let applying = Task { await look.apply() }
        applying.cancel()
        await applying.value
        #expect(look.status != .conflict)
        #expect(look.status != .failed)
    }
}

import Testing
import PrestoCVApplication
import PrestoCVDomain

@Suite("A change of the look of a CV")
struct LookChangeTests {
    private let modern = DesignChoice(design: "modern", palette: "creative", fonts: "serif")!
    private let minimal = DesignChoice(design: "minimal", palette: "minimal", fonts: "classic")!

    @Test("a change keeps the parts chosen and the look the sheet showed")
    func holdsWhatWasChosen() {
        let change = LookChange(shown: modern, parts: [.palette])

        #expect(change.parts == [.palette])
        #expect(change.shown == modern)
    }

    @Test("two changes made one after the other are one change: the parts of both, as the sheet showed them last")
    func followingChangesAreOne() {
        let first = LookChange(shown: DesignChoice(design: "modern", palette: "professional", fonts: "classic")!, parts: [.design])
        let second = LookChange(shown: modern, parts: [.palette])

        let together = first.followed(by: second)

        #expect(together == LookChange(shown: modern, parts: [.design, .palette]))
    }

    @Test("a part chosen twice is one part, with the value of the later choice")
    func aPartChosenTwiceKeepsTheLaterValue() {
        let first = LookChange(shown: modern, parts: [.fonts])
        let second = LookChange(shown: minimal, parts: [.fonts])

        let together = first.followed(by: second)

        #expect(together.parts == [.fonts])
        #expect(together.shown.fonts == "classic")
    }

    @Test("a part chosen in the earlier change keeps its value when the later change is of another part, whatever the later showed")
    func anEarlierPartKeepsItsValue() {
        let first = LookChange(shown: modern, parts: [.design, .palette])
        let second = LookChange(shown: minimal, parts: [.fonts])

        let together = first.followed(by: second)

        #expect(together.parts == [.design, .palette, .fonts])
        #expect(together.shown == DesignChoice(design: "modern", palette: "creative", fonts: "classic"))
    }

    @Test("following is the same whatever way three changes are grouped")
    func followingIsAssociative() {
        let a = LookChange(shown: modern, parts: [.design])
        let b = LookChange(shown: minimal, parts: [.palette])
        let c = LookChange(shown: modern, parts: [.fonts])

        #expect(a.followed(by: b).followed(by: c) == a.followed(by: b.followed(by: c)))
        #expect(a.followed(by: b).followed(by: c) == LookChange(shown: DesignChoice(design: "modern", palette: "minimal", fonts: "serif")!, parts: [.design, .palette, .fonts]))
    }
}

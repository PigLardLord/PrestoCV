import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// What was chosen in an export sheet and the CV does not hold yet.
@Suite("ExportChoices Tests - the choices a CV does not show yet")
struct ExportChoicesTests {

    private let cv = CVModel(
        name: "Luca – Sales",
        documentLanguage: "it",
        look: CVLook(design: "future-design", palette: "neon", fonts: "handwritten")
    )

    // MARK: - Nothing chosen

    @Test("Nothing is chosen until a language or a look is, and Automatic is a language")
    func isEmpty() {
        #expect(ExportChoices().isEmpty)
        #expect(!ExportChoices(documentLanguage: .init(value: nil)).isEmpty, "Automatic is a choice")
        #expect(!ExportChoices(look: lookChange([.fonts])).isEmpty)
    }

    @Test("A CV is left as it is when nothing was chosen")
    func emptyChoicesLeaveTheCV() {
        #expect(ExportChoices().applied(to: cv) == cv)
    }

    // MARK: - Applying

    @Test("The language chosen is the CV's, and Automatic takes the language off it")
    func appliesTheLanguage() {
        #expect(ExportChoices(documentLanguage: .init(value: .german)).applied(to: cv).documentLanguage == "de")
        #expect(ExportChoices(documentLanguage: .init(value: nil)).applied(to: cv).documentLanguage == nil)
    }

    @Test("Only the parts of the look that were chosen change, and the ids the app does not know stay")
    func appliesTheChosenPartsOfTheLook() {
        let chosen = ExportChoices(look: lookChange([.design], design: "modern"))

        #expect(chosen.applied(to: cv).look == CVLook(design: "modern", palette: "neon", fonts: "handwritten"))
    }

    @Test("A CV with no look takes the look the sheet showed")
    func lookOfACVWithoutOne() {
        var withoutLook = cv
        withoutLook.look = nil

        let applied = ExportChoices(look: lookChange([.palette], design: "modern", palette: "creative", fonts: "serif")).applied(to: withoutLook)

        #expect(applied.look == CVLook(design: "modern", palette: "creative", fonts: "serif"))
    }

    @Test("A CV that shows the choices already is not changed by them: applying them twice is applying them once")
    func applyingIsIdempotent() {
        let chosen = ExportChoices(documentLanguage: .init(value: .french), look: lookChange([.design, .fonts], design: "modern", fonts: "serif"))

        let once = chosen.applied(to: cv)

        #expect(chosen.applied(to: once) == once)
    }

    @Test("Nothing but the language and the look is touched")
    func touchesNothingElse() {
        var named = cv
        named.name = "Luca – Account manager"
        let chosen = ExportChoices(documentLanguage: .init(value: .german), look: lookChange([.design], design: "modern"))

        var expected = chosen.applied(to: cv)
        expected.name = "Luca – Account manager"
        #expect(chosen.applied(to: named) == expected)
    }

    // MARK: - Following

    @Test("The latest language chosen is the one kept, Automatic included")
    func latestLanguageWins() {
        let german = ExportChoices(documentLanguage: .init(value: .german))
        let french = ExportChoices(documentLanguage: .init(value: .french))
        let automatic = ExportChoices(documentLanguage: .init(value: nil))

        #expect(german.followed(by: french).documentLanguage == .init(value: .french))
        #expect(german.followed(by: automatic).documentLanguage == .init(value: nil))
        #expect(german.followed(by: ExportChoices(look: lookChange([.fonts]))).documentLanguage == .init(value: .german), "A look does not take back a language")
    }

    @Test("The parts of the look chosen in either choice are kept, each with the value of its latest choice")
    func looksAreFollowed() {
        let design = ExportChoices(look: lookChange([.design], design: "modern"))
        let palette = ExportChoices(look: lookChange([.palette], design: "modern", palette: "creative"))
        let designAgain = ExportChoices(look: lookChange([.design], design: "minimal", palette: "creative"))

        let followed = design.followed(by: palette).followed(by: designAgain)

        #expect(followed.look == lookChange([.design, .palette], design: "minimal", palette: "creative"))
    }

    @Test("A choice that follows nothing, or is followed by nothing, is itself")
    func followingNothing() {
        let chosen = ExportChoices(documentLanguage: .init(value: .german), look: lookChange([.design], design: "modern"))

        #expect(ExportChoices().followed(by: chosen) == chosen)
        #expect(chosen.followed(by: ExportChoices()) == chosen)
    }
}

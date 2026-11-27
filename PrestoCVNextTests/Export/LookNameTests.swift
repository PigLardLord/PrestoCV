import SwiftUI
import Testing
@testable import PrestoCVNext

/// A choice the look picker offers is named by its code, which is its key in the app's string catalog (#407). That the
/// codes the launch offers and the catalog's keys are the same set is checked by the composition's LookNamesTests.
@Suite("Names of the look picker")
struct LookNameTests {

    @Test("An offered choice reads the catalog's text under its code", arguments: [
        ("design.professional", "Professional", "Professionale"), ("palette.ocean", "Ocean", "Oceano"),
    ])
    func anOfferedChoiceReadsItsCode(code: String, english: String, italian: String) {
        #expect(Self.text(of: LookName.offered(code), in: "en") == english)
        #expect(Self.text(of: LookName.offered(code), in: "it") == italian)
    }

    @Test("A code the catalog has no text for is still named by its code, never as a kept choice")
    func anUnknownCodeIsNamedByItsCode() {
        #expect(LookName.offered("design.retro").key == "design.retro")
    }

    private static func text(of name: LocalizedStringResource, in language: String) -> String {
        var name = name
        name.locale = Locale(identifier: language)
        return String(localized: name)
    }
}

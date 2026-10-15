import Testing
import SwiftUI
@testable import PrestoCV

@Suite("WordFit Tests - labels that break between words, not inside one")
struct WordFitTests {

    @Test("At a regular size a label keeps the size the person chose",
          arguments: [DynamicTypeSize.xSmall, .medium, .large, .xLarge, .xxLarge, .xxxLarge])
    func regularSizeIsKept(size: DynamicTypeSize) {
        #expect(WordFit.sizes(upTo: size) == [size])
    }

    @Test("At an accessibility size a label tries the chosen size first, then each smaller one down to the largest regular size")
    func accessibilitySizesStepDown() {
        #expect(WordFit.sizes(upTo: .accessibility5) == [
            .accessibility5, .accessibility4, .accessibility3, .accessibility2, .accessibility1, .xxxLarge,
        ])
        #expect(WordFit.sizes(upTo: .accessibility1) == [.accessibility1, .xxxLarge])
    }

    @Test("A compound is one word: it must fit on a line whole")
    func compoundIsOneWord() {
        #expect(WordFit.words(in: "Dokumentsprache") == ["Dokumentsprache"])
    }

    @Test("A line breaks at a space, so each word is measured on its own")
    func spacesSeparateWords() {
        #expect(WordFit.words(in: "C1 - Fortgeschritten") == ["C1", "-", "Fortgeschritten"])
        #expect(WordFit.words(in: "Noch keine  Berufserfahrung\n") == ["Noch", "keine", "Berufserfahrung"])
    }

    @Test("A line may break after a hyphen, so a hyphenated compound is measured in its parts")
    func hyphenSeparatesParts() {
        #expect(WordFit.words(in: "Social-Media-Profile") == ["Social-", "Media-", "Profile"])
        #expect(WordFit.words(in: "E-Mail") == ["E-", "Mail"])
    }

    @Test("A text with no words has nothing to measure")
    func emptyText() {
        #expect(WordFit.words(in: "").isEmpty)
        #expect(WordFit.words(in: "   ").isEmpty)
    }
}

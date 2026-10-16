import Testing
import Foundation
@testable import CVGeneratorAI

/// The words and numbers of a text, as the clauses of the description and the prose of a draft are read.
@Suite("Words: the words and numbers of a text")
struct WordTests {
    private func folded(_ text: String) -> [String] {
        Word.words(in: text).map(\.folded)
    }

    @Test("Words are written without case or accents, and numbers keep their separator")
    func foldedWords() {
        #expect(folded("Il Mio Inglese è fluente") == ["il", "mio", "inglese", "e", "fluente"])
        #expect(folded("I worked 3.5 years, 1,000 days and 35 hours") == ["i", "worked", "3.5", "years", "1.000", "days", "and", "35", "hours"])
    }

    @Test("A word keeps its accents next to the folded one: \"è\" (is) is not \"e\" (and)")
    func accentedWords() {
        let words = Word.words(in: "Parlo italiano e inglese. Mio inglese è fluente")

        #expect(words.first { $0.folded == "e" && $0.accented == "e" }.map { StatementWords.isConjunction($0.accented, in: .italian) } == true)
        #expect(words.first { $0.folded == "e" && $0.accented == "è" }.map { StatementWords.isConjunction($0.accented, in: .italian) } == false)
    }

    @Test("A conjunction belongs to its language: Italian \"ma\" (but) is French \"ma\" (my), and Portuguese \"o\" is the")
    func conjunctionsByLanguage() {
        #expect(StatementWords.isConjunction("ma", in: .italian))
        #expect(!StatementWords.isConjunction("ma", in: .french))
        #expect(StatementWords.isConjunction("o", in: .spanish))
        #expect(!StatementWords.isConjunction("o", in: .portuguese))
        #expect(StatementWords.isConjunction("ma", in: nil), "With no language, a conjunction of any language is one")
        #expect(!StatementWords.isConjunction("and", in: .italian))
    }

    @Test("A word that a hyphen and a letter follow is told: the \"e\" of \"e-mail\" is no conjunction")
    func hyphenatedWords() {
        let words = Word.words(in: "La mia e-mail \u{e8} me@example.com e il mio telefono - 333, 2012-2016 e basta")

        #expect(words.filter(\.isHyphenated).map(\.range.lowerBound) == [7])
        #expect(words.filter { $0.accented == "e" && !$0.isHyphenated }.count == 2)
    }

    @Test("A run of letters and digits with a letter in it is a word, a run of digits is a number")
    func alphanumericWords() {
        let words = Word.words(in: "English (B2), the 3rd of 2016")

        #expect(words.map(\.folded) == ["english", "b2", "the", "3rd", "of", "2016"])
        #expect(words.map(\.isNumber) == [false, false, false, false, false, true])
    }

    @Test("Digits of any script are the same digits", arguments: ["９９", "٩٩", "९९"])
    func digitsOfAnyScript(digits: String) {
        #expect(folded("I trained \(digits) people") == ["i", "trained", "99", "people"])
    }

    @Test("Apostrophes and hyphens separate words, so an elided article is a word of its own")
    func apostrophesAndHyphens() {
        #expect(folded("l'école d'été, mother-tongue") == ["l", "ecole", "d", "ete", "mother", "tongue"])
        #expect(folded("I'm a nurse") == ["i", "m", "a", "nurse"])
    }

    @Test("A comma or a semicolon after a word, past the brackets and quotes that close it, ends its clause")
    func breaks() {
        let words = Word.words(in: "Italian (native), French; \"English\", Swift ,Go and Kotlin")

        #expect(words.map(\.endsWithABreak) == [false, true, true, true, true, false, false, false])
    }

    @Test("A semicolon after a word is told from a comma")
    func semicolons() {
        let words = Word.words(in: "Italian (native), French; \"English\"; Swift, Go")

        #expect(words.map(\.endsWithASemicolon) == [false, false, true, true, false, false])
    }

    @Test("A comma inside a number is a separator, not a break")
    func commaInsideANumber() {
        let words = Word.words(in: "I handled 1,000 calls, 3, 4")

        #expect(words.map(\.endsWithABreak) == [false, false, false, true, true, false])
    }

    @Test("Where a word stands is a character offset in the text it was read from")
    func ranges() {
        let words = Word.words(in: "At Acme 2012")

        #expect(words.map(\.range) == [0..<2, 3..<7, 8..<12])
    }
}

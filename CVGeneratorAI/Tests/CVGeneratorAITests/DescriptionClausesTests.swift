import Testing
import Foundation
@testable import CVGeneratorAI

/// The description cut into clauses (ADR 0023, rule (c)): at sentence ends, commas, semicolons and conjunctions.
@Suite("Description clauses: where a clause ends")
struct DescriptionClausesTests {
    private func texts(_ text: String, protecting quotes: [String] = []) -> [String] {
        let result = DescriptionClauses(sentences: SentenceSplitter.sentences(in: text), protecting: quotes.map { Word.words(in: $0).map(\.folded) })
        return result.sentences.flatMap { $0 }.map { $0.words.map(\.folded).joined(separator: " ") }
    }

    @Test("A clause ends at a comma, a semicolon, a sentence end or a conjunction, which belongs to none")
    func ends() {
        #expect(texts("At Acme I worked, from 2012 to 2016; and at Beta. Then I left") == ["at acme i worked", "from 2012 to 2016", "at beta", "then i left"])
        #expect(texts("Parlo italiano e inglese o francese, ma poco") == ["parlo italiano", "inglese", "francese", "poco"])
        #expect(texts("Ich arbeite bei Acme und Beta") == ["ich arbeite bei acme", "beta"])
    }

    @Test("\"è\" (is) does not end a clause the way \"e\" (and) does")
    func accentedConjunction() {
        #expect(texts("Il mio inglese è fluente e il francese è base") == ["il mio inglese e fluente", "il francese e base"])
    }

    @Test("The \"e\" of \"e-mail\" ends no clause, and an \"e\" with spaces around it does")
    func eMail() {
        #expect(texts("La mia e-mail \u{e8} anna e il mio telefono") == ["la mia e mail e anna", "il mio telefono"])
        #expect(texts("My e-mail is anna and my phone is 333") == ["my e mail is anna", "my phone is 333"])
    }

    @Test("A quote of the draft is not cut, whatever it holds", arguments: [
        ("Dal 2004 al 2008 ho lavorato presso lo Studio Rossi e Associati a Verona.", "Studio Rossi e Associati", "dal 2004 al 2008 ho lavorato presso lo studio rossi e associati a verona"),
        ("From 2004 to 2008 I worked at Procter and Gamble.", "Procter and Gamble", "from 2004 to 2008 i worked at procter and gamble"),
        ("I worked at Acme, Inc in 2012.", "Acme, Inc", "i worked at acme inc in 2012"),
    ])
    func quotesAreNotCut(description: String, quote: String, clause: String) {
        #expect(texts(description, protecting: [quote]) == [clause])
        #expect(texts(description).count > 1)
    }

    @Test("The clauses of a sentence are next to each other, and those of another sentence are not")
    func neighbours() {
        let result = DescriptionClauses(sentences: ["At Acme, from 2012, I worked", "Then Beta"], protecting: [])
        let places = result.places

        #expect(places.count == 4)
        #expect(result.neighbours(of: places[0]) == [places[1]])
        #expect(result.neighbours(of: places[1]) == [places[0], places[2]])
        #expect(result.neighbours(of: places[2]) == [places[1]])
        #expect(result.neighbours(of: places[3]) == [])
    }

    @Test("Keeping every clause gives the sentences back, address and punctuation included", arguments: [
        "I speak Italian, my sister speaks French (C2) and I know Swift", "me@example.com is my email", "Email: me@example.com",
        "anna@example.com", "(see example.com/me) I worked at Acme; Beta", "Languages: Italian (native), French (C2).",
    ])
    func keepingEverything(sentence: String) {
        let result = DescriptionClauses(sentences: [sentence], protecting: [])

        #expect(result.sentences(keeping: { _ in true }) == [sentence])
    }

    @Test("The clauses that are rejected become a semicolon, and the ones around them stay apart")
    func keepingSome() {
        let result = DescriptionClauses(sentences: ["I speak Italian, my sister speaks French (C2) and I know Swift", "anna@example.com"], protecting: [])
        let kept = result.sentences { $0.sentence == 1 || $0.clause != 1 }
        let none = result.sentences { _ in false }

        #expect(kept == ["I speak Italian, ; I know Swift", "anna@example.com"])
        #expect(none == ["; ; ; ", "anna@example.com"], "A sentence of no words is not a clause: it stays as written")
    }

    @Test("A clause writes the links it holds, and the address is not read as words")
    func links() {
        let result = DescriptionClauses(sentences: ["I earned a BLS in 2023 at bls.example.org/123, my site is example.com"], protecting: [])
        let first = result.sentences[0][0]

        #expect(first.links == ["bls.example.org/123"])
        #expect(first.words.map(\.folded) == ["i", "earned", "a", "bls", "in", "2023", "at"])
        #expect(result.sentences[0][1].links == ["example.com"])
    }

    @Test("The first clause of a sentence stands on its own, even when a conjunction starts it")
    func firstClauseIsAnchored() {
        #expect(DescriptionClauses(sentences: ["And I worked at Acme, Beta"], protecting: []).sentences[0].map(\.isAnchored) == [true, false])
    }

    @Test("A conjunction is read in the language of the description: French \"ma\" is my, Italian \"ma\" is but")
    func conjunctionsAreOfTheirLanguage() {
        func texts(_ sentence: String, _ language: Vocabulary.Language) -> [String] {
            DescriptionClauses(sentences: [sentence], protecting: [], language: language).sentences[0].map { $0.words.map(\.folded).joined(separator: " ") }
        }

        #expect(texts("Ma collègue a dirigé une école", .french) == ["ma collegue a dirige une ecole"])
        #expect(texts("Ho lavorato ma non molto", .italian) == ["ho lavorato", "non molto"])
        #expect(texts("Trabalhei o dia", .portuguese) == ["trabalhei o dia"])
    }

    @Test("A clause stands on its own when it starts its sentence or follows a semicolon, and belongs to the one before it after a comma or a conjunction")
    func anchors() {
        func anchored(_ text: String) -> [Bool] {
            DescriptionClauses(sentences: [text], protecting: []).sentences[0].map(\.isAnchored)
        }

        #expect(anchored("Nurse at Acme, 2016\u{2013}2020") == [true, false])
        #expect(anchored("I worked at Acme; Beta, Gamma and Delta") == [true, true, false, false])
        #expect(anchored("I worked at Acme or Beta; and Gamma") == [true, false, false])
        #expect(DescriptionClauses(sentences: ["At Acme", "Beta, Gamma"], protecting: []).sentences.map { $0.map(\.isAnchored) } == [[true], [true, false]])
    }

    @Test("A clause cut short holds the words before the cut, the text of them and the links they write")
    func truncated() {
        let text = "I worked at Acme (acme.example.com) to support 3 teams (teams.example.org)"
        let clause = DescriptionClauses(sentences: [text], protecting: []).sentences[0][0]
        let cut = clause.truncated(to: 4)

        #expect(cut.words.map(\.folded) == ["i", "worked", "at", "acme"])
        #expect(cut.text == "i worked at acme")
        #expect(cut.links == ["acme.example.com"])
        #expect(clause.truncated(to: clause.words.count).text == clause.text)
        #expect(clause.truncated(to: 0).words.isEmpty)
        #expect(clause.links == ["acme.example.com", "teams.example.org"])
    }

    @Test("A clause says where it begins to name the phrases, as itself: the last, among them, of the places where each first stands")
    func nameStart() {
        let clause = DescriptionClauses(sentences: ["I was head nurse at Acme Labs in Acme"], protecting: []).sentences[0][0]

        #expect(clause.nameStart(of: [["acme"]], amongQuotes: []) == 5)
        #expect(clause.nameStart(of: [["acme"], ["nurse"]], amongQuotes: []) == 5)
        #expect(clause.nameStart(of: [["nurse"], ["head"]], amongQuotes: []) == 3)
        #expect(clause.nameStart(of: [["acme"]], amongQuotes: [["acme", "labs"]]) == 8)
        #expect(clause.nameStart(of: [["acme"], ["beta"]], amongQuotes: []) == nil)
        #expect(clause.nameStart(of: [], amongQuotes: []) == nil)
    }

    @Test("A name stands in a clause as itself, and not as a part of a longer quote")
    func standaloneSpans() {
        let clause = DescriptionClauses(sentences: ["I was head nurse at Acme Labs"], protecting: []).sentences[0][0]

        #expect(clause.spans(of: ["nurse"]) == [3..<4])
        #expect(clause.standaloneSpans(of: ["nurse"], amongQuotes: [["head", "nurse"]]).isEmpty)
        #expect(clause.standaloneSpans(of: ["acme"], amongQuotes: [["acme", "labs"]]).isEmpty)
        #expect(clause.standaloneSpans(of: ["acme"], amongQuotes: [["acme"]]) == [5..<6])
    }

    @Test("A clause tells which of its words are written with a capital letter, past an address and in the clauses after the first")
    func capitals() {
        let result = DescriptionClauses(sentences: ["I'm Maria Rossi, me@example.com, a friend of Anna Verdi."], protecting: [])
        let fragment = result.sentences[0][1]

        #expect(fragment.words.map(\.folded) == ["a", "friend", "of", "anna", "verdi"])
        #expect(fragment.words.indices.filter(fragment.isCapitalised) == [3, 4])
        #expect(result.sentences[0][0].words.indices.filter(result.sentences[0][0].isCapitalised) == [0, 2, 3])
    }

    private func quoted(_ text: String) -> [String] {
        let clauses = DescriptionClauses(sentences: SentenceSplitter.sentences(in: text), protecting: [])
        return clauses.places.flatMap { place in
            clauses.quotedWords(at: place).sorted().map { clauses.clause(at: place).words[$0].folded }
        }
    }

    @Test("The words inside quotation marks are quoted, over two sentences too; an apostrophe or an inch mark is no mark, nor one that nothing closes")
    func quotationMarks() {
        #expect(quoted("She wrote “I speak French” to me") == ["i", "speak", "french"])
        #expect(quoted("Il a écrit : « Je parle français. Je parle allemand. »") == ["je", "parle", "francais", "je", "parle", "allemand"])
        #expect(quoted("Er schrieb: »Ich spreche Französisch« und ging") == ["ich", "spreche", "franzosisch"])
        #expect(quoted("I’m sure l’inglese isn't 'hard'") == ["hard"])
        #expect(quoted("A 27\" monitor and a \"big\" desk") == ["big"])
        #expect(quoted("I speak “French and German").isEmpty)
    }

    @Test("A clause keeps only the words it is given: a run of words left out becomes a semicolon, and so does a clause with none")
    func keepingWords() {
        let clauses = DescriptionClauses(sentences: ["I work with a colleague who speaks French.", "I speak “fluent” French, German."], protecting: [])
        let kept: [DescriptionClauses.Place: Set<Int>] = [
            .init(sentence: 0, clause: 0): [0, 1, 2, 3, 4], .init(sentence: 1, clause: 0): [0, 1, 3], .init(sentence: 1, clause: 1): [],
        ]

        #expect(clauses.sentences(keepingWords: { kept[$0] ?? [] }) == ["I work with a colleague ; ", "I speak “; French, ; "])
    }

    @Test("A clause ends a question when a question mark ends it, past closing marks")
    func questions() {
        let sentences = ["Parlo francese e tedesco, giusto?", "«Parli francese?»", "«Parli francese?», mi chiedono."]
        let clauses = DescriptionClauses(sentences: sentences, protecting: [])

        #expect(clauses.sentences.map { $0.map(\.endsAQuestion) } == [[false, false, true], [true], [false]])
    }
}

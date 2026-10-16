import Testing
import Foundation
@testable import CVGeneratorAI

/// Prose is quoted from the description (ADR 0023, rule (d)): a clause of prose is a clause of the description, in its own words and
/// order, to its end or to where its purpose tail starts, after at most a lead-in.
@Suite("Prose quotes: a clause of prose quotes one clause of the description")
struct ProseQuotesTests {
    private func quotes(_ description: String, in language: Vocabulary.Language?, endingAt ends: [Int]? = nil) -> ProseQuotes {
        let clauses = DescriptionClauses(sentences: [description], protecting: []).sentences[0]
        return ProseQuotes(sources: clauses.map { ProseQuotes.Source($0, ends: ends) }, language: language)
    }

    private func quoting(_ prose: String, _ description: String, in language: Vocabulary.Language?, endingAt ends: [Int]? = nil) -> Bool {
        quotes(description, in: language, endingAt: ends).quotes(Word.words(in: prose))
    }

    @Test("The whole clause is a quote, whatever its case, diacritics and punctuation")
    func wholeClause() {
        #expect(quoting("I managed the school library in Rome", "I managed the school library in Rome.", in: .english))
        #expect(quoting("I MANAGED the school library, in Rome!", "i managed the school library in rome", in: .english))
        #expect(quoting("Ho gestito la biblioteca della scuola", "Ho gestito la biblioteca della scuola.", in: .italian))
        #expect(quoting("J'ai dirigé la bibliothèque", "j ai dirige la bibliotheque", in: .french))
    }

    @Test("A word left out, another word, another order or another form is no quote")
    func notAQuote() {
        let clause = "I managed the school library in Rome."

        #expect(!quoting("I managed the library in Rome", clause, in: .english), "a word left out of the middle")
        #expect(!quoting("I managed the school libraries in Rome", clause, in: .english), "another form: no lemma")
        #expect(!quoting("I managed in Rome the school library", clause, in: .english), "another order")
        #expect(!quoting("She managed the school library in Rome", clause, in: .english), "another person")
        #expect(!quoting("I manage the school library in Rome", clause, in: .english), "another tense")
        #expect(!quoting("", clause, in: .english))
    }

    @Test("A quote runs to the end of the clause, and to where its purpose tail starts when there is one")
    func endOfTheClause() {
        let clause = "I taught 3 courses at Acme to support students."

        #expect(!quoting("I taught 3 courses at Acme", clause, in: .english), "it stops before the clause's end")
        #expect(quoting("I taught 3 courses at Acme", clause, in: .english, endingAt: [6]), "the purpose tail starts at to")
        #expect(quoting("I taught 3 courses at Acme to support students", clause, in: .english, endingAt: [6, 9]))
        #expect(!quoting("I taught 3 courses at Acme to", clause, in: .english, endingAt: [6]))
    }

    @Test("A quote may leave out a lead-in: first-person pronouns and joining words, then the auxiliary or the form of to be", arguments: [
        ("taught at Acme since 2016", "I have taught at Acme since 2016", Vocabulary.Language.english),
        ("A nurse in Turin", "I'm a nurse in Turin", .english),
        ("I trained interns", "where I trained interns", .english),
        ("trained interns", "where I trained interns", .english),
        ("Ho formato tirocinanti", "dove ho formato tirocinanti", .italian),
        ("Formato tirocinanti", "Ho formato tirocinanti", .italian),
        ("Laureata nel 2012", "mi sono laureata nel 2012", .italian),
        ("Praktikanten ausgebildet habe", "wo ich Praktikanten ausgebildet habe", .german),
        ("gearbeitet", "Ich habe gearbeitet", .german),
        ("J'ai formé des stagiaires", "où j'ai formé des stagiaires", .french),
        ("Formé des stagiaires", "j'ai formé des stagiaires", .french),
        ("Formé a becarios", "donde formé a becarios", .spanish),
        ("Trabajado en Roma", "He trabajado en Roma", .spanish),
        ("Formei estagiários", "onde formei estagiários", .portuguese),
        ("Trabalhado em Roma", "Tenho trabalhado em Roma", .portuguese),
    ])
    func leadIn(prose: String, description: String, language: Vocabulary.Language) {
        #expect(quoting(prose, description, in: language), "\(prose) quotes \(description)")
    }

    @Test("A quote never leaves out an article, a word of negation, doubt, wish, future or condition, another word or another person", arguments: [
        ("nurse in Turin", "I'm a nurse in Turin", Vocabulary.Language.english),
        ("worked at Acme", "I have never worked at Acme", .english),
        ("worked at Acme", "I would like to work at Acme", .english),
        ("worked at Acme", "She has worked at Acme", .english),
        ("worked at Acme", "My colleague worked at Acme", .english),
        ("Gestito una scuola", "Ha gestito una scuola", .italian),
        ("Lavorato presso Acme", "Non ho mai lavorato presso Acme", .italian),
        ("gearbeitet", "Sie hat gearbeitet", .german),
        ("travaillé chez Acme", "Je n'ai pas travaillé chez Acme", .french),
        ("Trabajado en Roma", "Nunca he trabajado en Roma", .spanish),
        ("Trabalhado em Roma", "Ela tem trabalhado em Roma", .portuguese),
    ])
    func noLeadIn(prose: String, description: String, language: Vocabulary.Language) {
        #expect(!quoting(prose, description, in: language), "\(prose) does not quote \(description)")
    }

    @Test("Without a language only the pronouns, the joining words and a form of to be are a lead-in")
    func withoutALanguage() {
        #expect(quoting("A nurse in Turin", "I'm a nurse in Turin", in: nil))
        #expect(quoting("trained interns", "where I trained interns", in: nil))
        #expect(!quoting("taught at Acme", "I have taught at Acme", in: nil), "have is an auxiliary of English only")
    }

    @Test("The lead-in is read from the start of the clause only")
    func leadInIsAtTheStart() {
        #expect(!quoting("trained interns", "I worked at Acme where I trained interns", in: .english), "I worked at Acme is no lead-in")
        #expect(!quoting("trained", "I trained interns", in: .english))
    }

    @Test("Any clause of the sources may be quoted, and the ends belong to their own source")
    func oneOfManyClauses() {
        let description = "I worked at Acme in Rome, I trained interns."

        #expect(quoting("Trained interns", description, in: .english))
        #expect(quoting("worked at Acme in Rome", description, in: .english))
        #expect(!quoting("worked at Acme in Rome I trained interns", description, in: .english), "two clauses are not one quote")
    }

    @Test("Two sets of quotes make one")
    func adding() {
        let first = quotes("I worked at Acme.", in: .english)
        let second = quotes("I trained interns.", in: .english)

        #expect(!first.quotes(Word.words(in: "trained interns")))
        #expect(first.adding(second).quotes(Word.words(in: "trained interns")))
        #expect(first.adding(second).quotes(Word.words(in: "worked at Acme")))
    }
}

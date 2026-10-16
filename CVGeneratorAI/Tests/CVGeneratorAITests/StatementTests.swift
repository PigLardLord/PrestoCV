import Testing
import Foundation
@testable import CVGeneratorAI

/// What the verbs and the words of a clause make of a mention of an entry (ADR 0023, rule (c)): factual when every verb before the
/// name, and before the first factual verb, is a listed present or past form, and every word there is explained; and the words from
/// a verb after both give no facts.
@Suite("Statement: the verbs of a clause that names an entry")
struct StatementTests {
    /// - Parameters:
    ///   - tagged: The words the device's lexical class tags as verbs: its tags are given here, so that the rule is the same on every platform.
    ///   - quoted: The words that are part of a quote of the draft.
    ///   - explaining: Whether every word before the name, and the first factual verb, is asked to be explained: by the vocabulary, or
    ///     by the name and the quoted words.
    private func statement(
        _ text: String, name: String, language: Vocabulary.Language?, tagged: Set<String> = [], quoted: Set<String> = [], explaining: Bool = false
    ) -> Statement {
        var words = Word.words(in: text)
        for index in words.indices where tagged.contains(words[index].folded) { words[index].isTaggedVerb = true }
        let start = words.firstIndex { $0.folded == name }!
        let positions = Set(words.indices.filter { quoted.contains(words[$0].folded) || words[$0].folded == name })
        return Statement(words: words, name: start, quoted: positions, own: explaining ? positions : nil, language: language)
    }

    @Test("A clause without a verb, or with listed present and past forms, is factual", arguments: [
        ("Nurse at Acme, 2016", Vocabulary.Language.english),
        ("I work at Acme since 2016", .english),
        ("I worked at Acme in 2012", .english),
        ("I'm a nurse at Acme since 2016", .english),
        ("I was a nurse at Acme", .english),
        ("I have a BLS from Acme", .english),
        ("Sono infermiera presso Acme dal 2016", .italian),
        ("Ho lavorato presso Acme dal 2016", .italian),
        ("Ich habe 2012 bei Acme gearbeitet", .german),
        ("Soy enfermera en Acme desde 2016", .spanish),
        ("J'étais infirmière chez Acme en 2012", .french),
        ("J'ai travaillé à l'école Acme", .french),
        ("Tenho trabalhado na Acme desde 2016", .portuguese),
    ])
    func factual(text: String, language: Vocabulary.Language) {
        let tagged: Set<String> = ["have", "work", "worked", "was", "m", "habe", "gearbeitet"]
        #expect(statement(text, name: "acme", language: language, tagged: tagged, quoted: ["nurse", "infermiera"]).isFactual, "\(text)")
    }

    @Test("A verb that is no listed form, an infinitive or a verb after to or zu makes the mention not factual", arguments: [
        ("I try to work at Acme", Vocabulary.Language.english),
        ("I am going to work at Acme from 2027", .english),
        ("I studied hard to work at Acme", .english),
        ("I have to work at Acme", .english),
        ("Resterò presso Acme dal 2027", .italian),
        ("Ho intenzione di lavorare presso Acme", .italian),
        ("Sto per lavorare presso Acme", .italian),
        ("Me quedaré en Acme desde 2027", .spanish),
        ("Intento trabajar en Acme", .spanish),
        ("Voy a trabajar en Acme", .spanish),
        ("Je resterai chez Acme", .french),
        ("J'essaie de travailler chez Acme", .french),
        ("Je vais travailler chez Acme", .french),
        ("Ficarei na Acme a partir de 2027", .portuguese),
        ("Pretendo trabalhar na Acme", .portuguese),
        ("bei Acme zu arbeiten", .german),
    ])
    func notFactual(text: String, language: Vocabulary.Language) {
        let tagged: Set<String> = ["try", "going", "work", "studied", "arbeiten"]
        #expect(!statement(text, name: "acme", language: language, tagged: tagged).isFactual, "\(text)")
    }

    @Test("A noun that ends like an infinitive is no verb after an article, a preposition or a verb of the vocabulary, or in a quote")
    func nounsThatEndLikeInfinitives() {
        #expect(statement("Lavoro come ingegnere presso Acme", name: "acme", language: .italian).isFactual)
        #expect(statement("Sono ingegnere presso Acme", name: "acme", language: .italian).isFactual)
        #expect(statement("J'ai travaillé au centre Acme", name: "acme", language: .french).isFactual)
        #expect(statement("Trabajé en enfermería en Acme", name: "acme", language: .spanish).isFactual)
        #expect(statement("Ingegnere presso Acme", name: "acme", language: .italian, quoted: ["ingegnere"]).isFactual)
        #expect(!statement("Ingegnere presso Acme", name: "acme", language: .italian).isFactual, "At the start of a clause it reads as an infinitive")
    }

    @Test("A verb after the name and a factual verb is a purpose: the words from it on give no facts")
    func purposeGivesNoFacts() {
        let words = "I worked at Acme to support 3 teams"

        #expect(statement(words, name: "acme", language: .english, tagged: ["support"]).factualWords == 4)
        #expect(statement("Ho lavorato presso Acme per sostenere 3 squadre", name: "acme", language: .italian).factualWords == 4)
        #expect(statement("Trabalhei na Acme para apoiar 3 equipes", name: "acme", language: .portuguese).factualWords == 3)
        #expect(statement("I worked at Acme", name: "acme", language: .english).factualWords == 4)
    }

    @Test("A verb that completes the first factual one is part of the statement, and no purpose")
    func participleCompletesTheAuxiliary() {
        #expect(statement("Presso Acme ho lavorato per 3 anni nel 2012", name: "acme", language: .italian).factualWords == 9)
        #expect(statement("Bei Acme habe ich 2012 3 Jahre gearbeitet", name: "acme", language: .german).factualWords == 8)
        #expect(statement("At Acme I have also worked since 2016", name: "acme", language: .english).factualWords == 8)
        #expect(statement("At Acme I have been working since 2016", name: "acme", language: .english).factualWords == 8)
        #expect(statement("At Acme I was working in 2012", name: "acme", language: .english).factualWords == 7)
    }

    @Test("Another verb after a copula, a participle that is not next to it, or a participle after the name is a detail")
    func detailAfterTheStatement() {
        #expect(statement("I was a nurse at Acme working with 3 teams", name: "acme", language: .english, quoted: ["nurse"]).factualWords == 6)
        #expect(statement("I hold PALS obtained in 2019", name: "pals", language: .english).factualWords == 3)
        #expect(statement("I worked at Acme where I trained 3 nurses", name: "acme", language: .english).factualWords == 6)
    }

    @Test("A verb before the name that is not factual undoes a factual verb after the name")
    func verbBeforeTheNameDecides() {
        #expect(!statement("To work I try at Acme", name: "acme", language: .english, tagged: ["try", "work"]).isFactual)
        #expect(statement("At Acme I worked to support students", name: "acme", language: .english, tagged: ["support"]).isFactual)
    }

    @Test("A word that leads in to the statement and that nothing explains makes the mention not factual: it may be a verb the device cannot see", arguments: [
        ("Cerco lavoro come infermiera presso Acme", Vocabulary.Language.italian),
        ("Sogno Acme dal 2027", .italian),
        ("Je rêve d'Acme depuis 2027", .french),
        ("Sonho com a Acme desde 2027", .portuguese),
        ("Engineer at Acme", .english),
        ("Sogno e ho lavorato presso Acme", .italian),
        ("Zorblax Acme", .english),
    ])
    func unexplainedWordLeadingIn(text: String, language: Vocabulary.Language) {
        #expect(!statement(text, name: "acme", language: language, explaining: true).isFactual, "\(text)")
        #expect(statement(text, name: "acme", language: language).isFactual, "\(text): without the rule it is factual")
    }

    @Test("The device's tag of an English verb is a word nothing explains in the lead-in")
    func taggedVerbLeadingIn() {
        let text = "I'm looking for a job at Acme"

        #expect(!statement(text, name: "acme", language: .english, tagged: ["looking"], explaining: true).isFactual)
    }

    @Test("Words before the name that the vocabulary or a quote explains keep the mention, and so do numbers", arguments: [
        ("Then I also worked at Acme", Vocabulary.Language.english),
        ("Poi ho anche lavorato presso Acme", .italian),
        ("Depuis 2016 je travaille chez Acme", .french),
        ("Since 2016 I worked as a nurse at Acme", .english),
    ])
    func explainedWordsBeforeTheName(text: String, language: Vocabulary.Language) {
        #expect(statement(text, name: "acme", language: language, quoted: ["nurse"], explaining: true).isFactual, "\(text)")
    }

    @Test("What comes after the name or the first factual verb, whichever comes first, is the statement's own: it is not asked to be explained")
    func wordsOfTheStatement() {
        #expect(statement("At Acme in Zorblax I worked", name: "acme", language: .english, explaining: true).isFactual)
        #expect(statement("I worked at Acme in Zorblax", name: "acme", language: .english, explaining: true).isFactual)
        #expect(statement("In 2012 I moved from Zorblax to Acme", name: "acme", language: .english, explaining: true).isFactual)
        #expect(statement("Acme certifications from Zorblax", name: "acme", language: .english, explaining: true).isFactual)
        #expect(!statement("En Acme sueño con trabajar", name: "acme", language: .spanish, explaining: true).isFactual, "trabajar is an infinitive after con")
    }

    @Test("A clause speaks for the person when its first-person pronoun is its subject, or when it has none the way a CV writes", arguments: [
        ("I worked at Acme", Vocabulary.Language.english, true),
        ("Worked at Acme", .english, true),
        ("Nurse at Acme", .english, true),
        ("Beta employed me at Acme", .english, false),
        ("She worked at Acme", .english, false),
        ("My sister is a nurse at Acme", .english, false),
        ("My colleague managed Acme", .english, false),
        ("Ho lavorato presso Acme", .italian, true),
        ("Sono infermiera presso Acme", .italian, true),
        ("Ha lavorato presso Acme", .italian, false),
        ("Dal 2012 ha lavorato presso Acme", .italian, false),
        ("Lei lavora presso Acme", .italian, false),
        ("Mia sorella è infermiera presso Acme", .italian, false),
        ("Beta ha assunto Acme", .italian, false),
        ("A nurse worked at Acme", .english, false),
        ("Trabajé en Acme", .spanish, true),
        ("Trabajó en Acme", .spanish, false),
        ("Era enfermera en Acme", .spanish, true),
        ("Trabalhei na Acme", .portuguese, true),
        ("Trabalhou na Acme", .portuguese, false),
        ("Era enfermeira na Acme", .portuguese, true),
        ("Er arbeitet bei Acme", .german, false),
        ("Ich habe bei Acme gearbeitet", .german, true),
        ("Meine Kollegin hat bei Acme gearbeitet", .german, false),
        ("Elle a travaillé chez Acme", .french, false),
        ("J'ai travaillé chez Acme", .french, true),
        ("Ma collègue a travaillé chez Acme", .french, false),
    ])
    func speaksForThePerson(text: String, language: Vocabulary.Language, speaks: Bool) {
        let tagged: Set<String> = ["worked", "managed", "employed", "arbeitet", "gearbeitet", "travaillé"]
        let result = statement(text, name: "acme", language: language, tagged: tagged)

        #expect(result.speaksForThePerson == speaks, "\(text)")
        #expect(speaks || !result.isFactual, "\(text): a clause that speaks for someone else gives no mention")
    }

    @Test("A person's own name before the verb is a subject of its own, and a name is never the person")
    func ownNameIsNotThePerson() {
        let words = Word.words(in: "Anna Rossi ha lavorato presso Acme")
        let own = Set(words.indices.filter { ["anna", "rossi", "acme"].contains(words[$0].folded) })

        #expect(!Statement(words: words, name: 4, quoted: own, own: own, language: .italian).speaksForThePerson)
    }

    @Test("A form of a verb after an article, a possessive or a simple preposition is a noun, where the device tags no verb", arguments: [
        ("Professora do ensino fundamental em Acme", Vocabulary.Language.portuguese, false),
        ("Desde 2016 leciono na escola Acme", .portuguese, true),
        ("Il mio lavoro presso Acme", .italian, false),
        ("Gestione del lavoro presso Acme", .italian, false),
        ("Lavoro presso Acme", .italian, true),
        ("Nel 2016 lavoro presso Acme", .italian, true),
        ("Mi trabajo en Acme", .spanish, false),
        ("Trabajo en Acme", .spanish, true),
        ("Au travail chez Acme", .french, false),
        ("Je travaille chez Acme", .french, true),
        ("The lead at Acme", .english, true),
    ])
    func nounAfterASign(text: String, language: Vocabulary.Language, hasVerbs: Bool) {
        #expect(statement(text, name: "acme", language: language).hasVerbs == hasVerbs, "\(text)")
    }

    @Test("A noun before a verb is a subject only of a verb it can be the subject of: a list item is no subject and its verb no verb", arguments: [
        ("Direzione lavori presso Acme", Vocabulary.Language.italian, true),
        ("Gestione progetti presso Acme", .italian, true),
        ("Il direttore della guida presso Acme", .italian, true),
        ("Il direttore lavora presso Acme", .italian, false),
        ("Il direttore ha lavorato presso Acme", .italian, false),
        ("Gerente trabajas en Acme", .spanish, true),
        ("El gerente trabaj\u{f3} en Acme", .spanish, false),
        ("Alice conosce Kotlin presso Acme", .italian, false),
        ("Il direttore ama gli scacchi presso Acme", .italian, false),
        ("Alice juega al ajedrez en Acme", .spanish, false),
        ("Alice joue aux \u{e9}checs chez Acme", .french, false),
        ("Alice mora em Milão na Acme", .portuguese, false),
        ("Gestione progetti presso Acme", .italian, true),
        ("Il direttore della guida presso Acme", .italian, true),
    ])
    func nounBeforeAVerb(text: String, language: Vocabulary.Language, speaks: Bool) {
        #expect(statement(text, name: "acme", language: language).speaksForThePerson == speaks, "\(text)")
    }

    @Test("Where the device tags the verbs, a listed form it leaves untagged is a noun, and a bare gerund is no verb a subject goes with", arguments: [
        ("Quality control at Acme", [], true),
        ("Customer support at Acme", [], true),
        ("Alice controls Acme", ["controls"], false),
        ("Alice managed Acme", [], false),
        ("Alice works at Acme", [], false),
        ("Alice lives at Acme", [], false),
        ("Problem solving at Acme", ["solving"], true),
        ("Interests reading at Acme", ["reading"], true),
        ("Alice is leading Acme", ["is", "leading"], false),
    ] as [(String, Set<String>, Bool)])
    func finiteVerbsByTags(text: String, tagged: Set<String>, speaks: Bool) {
        #expect(statement(text, name: "acme", language: .english, tagged: tagged).speaksForThePerson == speaks, "\(text)")
    }

    @Test("An everyday verb in a quote of the draft is a name, no verb")
    func everydayVerbInAQuote() {
        let words = Word.words(in: "Il direttore ama Acme")
        let quoted = Set(words.indices.filter { ["ama", "acme"].contains(words[$0].folded) })

        #expect(Statement(words: words, name: 3, quoted: quoted, own: nil, language: .italian).speaksForThePerson)
        #expect(!Statement(words: words, name: 3, quoted: [3], own: nil, language: .italian).speaksForThePerson)
    }

    @Test("An infinitive is no verb a subject goes with")
    func infinitiveIsNoFiniteVerb() {
        #expect(statement("Zorblax to work at Acme", name: "acme", language: .english, tagged: ["work"]).speaksForThePerson)
    }

    @Test("A level word the device tags as a verb is no verb: \"Swift (fortgeschritten)\" is a list item")
    func levelWordTaggedAsAVerb() {
        let tagged = statement("Swift fortgeschritten bei Acme", name: "acme", language: .german, tagged: ["fortgeschritten"])

        #expect(tagged.speaksForThePerson)
        #expect(tagged.hasVerbs, "the tag stays: only the subject reading ignores it")
    }

    @Test("A clause that starts with its verb is told so, and one with a subject is not")
    func startsWithItsVerb() {
        #expect(statement("Worked at Acme", name: "acme", language: .english, tagged: ["worked"]).startsWithItsVerb)
        #expect(!statement("I worked at Acme", name: "acme", language: .english, tagged: ["worked"]).startsWithItsVerb)
        #expect(!statement("Nurse at Acme", name: "acme", language: .english).startsWithItsVerb)
    }

    @Test("A statement says whether its clause holds a verb, and a condition makes it factual only when it holds")
    func verbsAndConditions() {
        #expect(!statement("Nurse at Acme", name: "acme", language: .english).hasVerbs)
        #expect(statement("I worked at Acme", name: "acme", language: .english).hasVerbs)

        let factual = statement("I worked at Acme", name: "acme", language: .english)
        #expect(factual.requiring(true).isFactual)
        #expect(!factual.requiring(false).isFactual)
        #expect(!statement("I try to work at Acme", name: "acme", language: .english).requiring(true).isFactual)
    }

    @Test("A clause that names no entry is factual when every verb of it is, the ones after a factual verb included")
    func clauseWithoutAName() {
        func isFactual(_ text: String) -> Bool {
            let clause = DescriptionClauses(sentences: [text], protecting: [], language: .english).sentences[0][0]
            return Statement(clause: clause, quotes: [], language: .english).isFactual
        }

        #expect(isFactual("where I taught 3 courses"))
        #expect(isFactual("3 courses"))
        #expect(!isFactual("to teach 3 courses"))
        #expect(!isFactual("I taught 3 courses to support students"))
    }

    @Test("An auxiliary is a verb of its own in its language only: French \"a\" (has) is no \"à\" (at)")
    func auxiliariesBelongToTheirLanguage() {
        #expect(statement("J'enseigne à l'école Acme", name: "acme", language: .french).isFactual)
        #expect(statement("Trabajé a Acme", name: "acme", language: .spanish).isFactual)
        #expect(statement("I worked as a nurse at Acme", name: "acme", language: nil).isFactual, "With no language, no word is an auxiliary")
    }
}

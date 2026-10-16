import Testing
import Foundation
@testable import CVGeneratorAI

/// Whose voice a clause is in (ADR 0023, rule (c), "The explicit subject").
@Suite("Voice: the person is the subject of the clauses that speak for them")
struct VoiceTests {
    typealias Case = (text: String, verbs: [String], language: Vocabulary.Language, speaks: Bool)

    /// Whether the clause `text` speaks for the person, its verbs being the words named in `verbs` (as `Word.accented` writes them).
    private func speaks(_ text: String, verbs: [String], in language: Vocabulary.Language?) -> Bool {
        let words = Word.words(in: text)
        let positions = Set(words.indices.filter { verbs.contains(words[$0].accented) })
        return Voice.speaks(words: words, verbs: positions, language: language)
    }

    @Test("A first-person pronoun is the person, and so is a clause with no subject the way a CV writes", arguments: [
        ("I worked at Acme", ["worked"], Vocabulary.Language.english, true),
        ("Worked at Acme", ["worked"], .english, true),
        ("Since 2016 I work at Acme", ["work"], .english, true),
        ("In Rome I worked at Acme", ["worked"], .english, true),
        ("From 2012 to 2016 worked at Acme", ["worked"], .english, true),
        ("Ho lavorato presso Acme", ["ho", "lavorato"], .italian, true),
        ("Dal 2016 lavoro presso Acme", ["lavoro"], .italian, true),
        ("A Roma ho lavorato presso Acme", ["ho", "lavorato"], .italian, true),
        ("Mi piacciono gli scacchi", ["piacciono"], .italian, true),
        ("En Roma trabajé en Acme", ["trabajé"], .spanish, true),
        ("Me gustan el ajedrez", ["gustan"], .spanish, true),
        ("Em Roma trabalhei na Acme", ["trabalhei"], .portuguese, true),
        ("À Rome j'ai travaillé chez Acme", ["ai", "travaillé"], .french, true),
        ("Ich habe bei Acme gearbeitet", ["habe", "gearbeitet"], .german, true),
        ("Seit 2016 arbeite ich bei Acme", ["arbeite"], .german, true),
        ("In Rom habe ich bei Acme gearbeitet", ["habe", "gearbeitet"], .german, true),
        ("Danach habe ich bei Acme gearbeitet", ["habe", "gearbeitet"], .german, true),
        ("Bei Acme gearbeitet", ["gearbeitet"], .german, true),
        ("Bei Acme gearbeitet f\u{fc}r sie", ["gearbeitet"], .german, true),
        ("Leitete 3 neue Lehrkr\u{e4}fte im Jahr 2018", ["leitete"], .german, true),
        ("Mi sono laureata nel 2012", ["sono", "laureata"], .italian, true),
        ("2012 meinen Abschluss gemacht", ["gemacht"], .german, true),
        ("En mi tiempo libre me gustan el ajedrez", ["gustan"], .spanish, true),
        ("Is a nurse at Acme", ["is"], .english, true),
        ("At her company I worked", ["worked"], .english, true),
        ("En su empresa trabajé", ["trabajé"], .spanish, true),
    ] as [Case])
    func person(_ example: Case) {
        #expect(speaks(example.text, verbs: example.verbs, in: example.language) == example.speaks, "\(example.text)")
    }

    @Test("A noun, a name, a pronoun of the third person or a possession of a person is someone else", arguments: [
        ("A nurse worked at Acme", ["worked"], Vocabulary.Language.english, false),
        ("The doctor worked at Acme", ["worked"], .english, false),
        ("Marco worked at Acme", ["worked"], .english, false),
        ("Alice managed a school", ["managed"], .english, false),
        ("She worked at Acme", ["worked"], .english, false),
        ("My sister speaks French", ["speaks"], .english, false),
        ("My sister's email is anna", ["is"], .english, false),
        ("In 2019 Alice managed a school", ["managed"], .english, false),
        ("In Rome the doctor worked at Acme", ["worked"], .english, false),
        ("You worked at Acme", ["worked"], .english, false),
        ("Un infermiere ha lavorato presso Acme", ["ha", "lavorato"], .italian, false),
        ("Beta ha assunto Acme", ["ha", "assunto"], .italian, false),
        ("La email di mia sorella è anna", ["è"], .italian, false),
        ("Presso Acme ha lavorato un infermiere", ["ha", "lavorato"], .italian, false),
        ("Mia sorella parla francese", ["parla"], .italian, false),
        ("En Acme trabajó una enfermera", ["trabajó"], .spanish, false),
        ("Una enfermera trabajó en Acme", ["trabajó"], .spanish, false),
        ("A Beta contratou a Acme", ["contratou"], .portuguese, false),
        ("Une infirmière a travaillé chez Acme", ["a", "travaillé"], .french, false),
        ("Marco a travaillé chez Acme", ["a", "travaillé"], .french, false),
        ("Eine Krankenschwester hat 2019 bei Acme gearbeitet", ["hat", "gearbeitet"], .german, false),
        ("Bei Acme arbeitete eine Krankenschwester seit 2016", ["arbeitete"], .german, false),
        ("2019 hat eine Krankenschwester bei Acme gearbeitet", ["hat", "gearbeitet"], .german, false),
        ("Seit 2016 arbeitet sie bei Acme", ["arbeitet"], .german, false),
        ("Her sister worked at Acme", ["worked"], .english, false),
        ("Su hermana trabajó en Acme", ["trabajó"], .spanish, false),
        ("Sua irmã trabalhou na Acme", ["trabalhou"], .portuguese, false),
        ("Ihre Schwester hat bei Acme gearbeitet", ["hat", "gearbeitet"], .german, false),
        ("Our team managed a school", ["managed"], .english, false),
        ("Is my sister's email", ["is"], .english, false),
        ("Was her assistant at Acme", ["was"], .english, false),
        ("Direzione lavori presso Acme", ["lavori"], .italian, true),
    ] as [Case])
    func someoneElse(_ example: Case) {
        #expect(speaks(example.text, verbs: example.verbs, in: example.language) == example.speaks, "\(example.text)")
    }

    @Test("A possession of one of the person's own fields is the person: a closed list of field words", arguments: [
        ("My email is anna", ["is"], Vocabulary.Language.english, true),
        ("My English is fluent", ["is"], .english, true),
        ("My phone number is 333", ["is"], .english, true),
        ("My e-mail address is anna", ["is"], .english, true),
        ("Il mio inglese è fluente", ["è"], .italian, true),
        ("La mia e-mail è anna", ["è"], .italian, true),
        ("Il mio numero di telefono è 333", ["è"], .italian, true),
        ("Meine E-Mail ist anna", ["ist"], .german, true),
        ("Mi inglés es fluido", ["es"], .spanish, true),
        ("Mon profil est anna", ["est"], .french, true),
        ("Meu inglês é fluente", ["é"], .portuguese, true),
        ("My experience includes triage", ["includes"], .english, true),
        ("My job at Acme was in nursing", ["was"], .english, true),
        ("My current job is at Acme", ["is"], .english, true),
        ("Il mio lavoro presso Acme \u{e8} stato bello", ["\u{e8}", "stato"], .italian, true),
        ("La mia esperienza include il triage", ["include"], .italian, true),
        ("My sister at Acme was a nurse", ["was"], .english, false),
        ("My manager at Acme is Anna", ["is"], .english, false),
        ("My mother worked at Acme", ["worked"], .english, false),
        ("My contact at Acme speaks French", ["speaks"], .english, false),
        ("La mia madre ha lavorato presso Acme", ["ha", "lavorato"], .italian, false),
        ("Il mio contatto presso Acme parla francese", ["parla"], .italian, false),
        ("My colleague's job at Acme ended", ["ended"], .english, false),
        ("My sister's English is fluent", ["is"], .english, false),
        ("My English teacher worked at Acme", ["worked"], .english, false),
        ("My manager is Anna", ["is"], .english, false),
        ("Il mio responsabile è Anna", ["è"], .italian, false),
        ("My degree is in nursing", ["is"], .english, true),
        ("My sister's degree is in nursing", ["is"], .english, false),
    ] as [Case])
    func ownFields(_ example: Case) {
        #expect(speaks(example.text, verbs: example.verbs, in: example.language) == example.speaks, "\(example.text)")
    }

    @Test("A clause addressed to the reader is the person's when its object is the person", arguments: [
        ("You can reach me at anna", ["can"], Vocabulary.Language.english, true),
        ("You can reach me at anna", ["reach"], .english, true),
        ("Du kannst mich unter anna erreichen", ["kannst", "erreichen"], .german, true),
        ("Seit 2016 kannst du mich erreichen", ["kannst", "erreichen"], .german, true),
        ("You can reach Anna at anna", ["can"], .english, false),
        ("You and Anna worked at Acme", ["worked"], .english, false),
        ("You can write to me at anna", ["can", "write"], .english, true),
        ("You can reach out to me at anna", ["can", "reach"], .english, true),
        ("You can find me at anna", ["can", "find"], .english, true),
        ("Du erreichst mich unter anna", ["erreichst"], .german, true),
        ("Você pode me contatar em", ["pode"], .portuguese, true),
    ] as [Case])
    func reader(_ example: Case) {
        #expect(speaks(example.text, verbs: example.verbs, in: example.language) == example.speaks, "\(example.text)")
    }

    @Test("The person must be the object of the verb of contacting itself: a third party right after it is someone else", arguments: [
        ("You can reach my manager through me at anna", ["can", "reach"], Vocabulary.Language.english, false),
        ("Through me you can reach my colleague at anna", ["can", "reach"], .english, false),
        ("You can write to my manager at anna", ["can", "write"], .english, false),
        ("You worked with me at Acme", ["worked"], .english, false),
        ("Du kannst meinen Chef \u{fc}ber mich unter anna erreichen", ["kannst", "erreichen"], .german, false),
        ("Você pode contatar meu chefe através de mim em", ["pode"], .portuguese, false),
    ] as [Case])
    func readerReachesSomeoneElse(_ example: Case) {
        #expect(speaks(example.text, verbs: example.verbs, in: example.language) == example.speaks, "\(example.text)")
    }

    @Test("A clause with no subject that asks the reader to contact someone is the person's only when the person is the object", arguments: [
        ("Contact my agent at anna", ["contact"], Vocabulary.Language.english, false),
        ("Write to my manager at anna", ["write"], .english, false),
        ("Feel free to contact my manager at anna", ["feel", "contact"], .english, false),
        ("Kontaktieren Sie meinen Agenten unter anna", ["kontaktieren"], .german, false),
        ("Puede contactar a mi jefe en", ["puede"], .spanish, false),
        ("Contact me at anna", ["contact"], .english, true),
        ("Feel free to contact me at anna", ["feel", "contact"], .english, true),
        ("Erreichen Sie mich unter anna", ["erreichen"], .german, true),
        ("Write technical documentation at Acme", ["write"], .english, true),
        ("Worked at Acme to contact new clients", ["worked", "contact"], .english, true),
        ("Contact details anna", [], .english, true),
    ] as [Case])
    func imperative(_ example: Case) {
        #expect(speaks(example.text, verbs: example.verbs, in: example.language) == example.speaks, "\(example.text)")
    }

    @Test("A clause with no verb that holds a verb of contacting is the person's only when the person is its object", arguments: [
        ("Puoi contattare il mio responsabile tramite me a", Vocabulary.Language.italian, false),
        ("Puoi scrivere al mio responsabile", .italian, false),
        ("Puedes contactar a mi jefe a trav\u{e9}s de m\u{ed} en", .spanish, false),
        ("Vous pouvez contacter mon responsable via moi \u{e0}", .french, false),
        ("Puoi contattarmi a", .italian, true),
        ("Mi potete contattare a", .italian, true),
        ("Puoi scrivere a me", .italian, true),
        ("Cont\u{e1}ctame en", .spanish, true),
        ("Vous pouvez me contacter \u{e0}", .french, true),
        ("Contactez-moi \u{e0}", .french, true),
        ("Contacte-me em", .portuguese, true),
        ("Mi occupo di contattare i clienti presso Acme", .italian, true),
        ("Non esitate a contattare il mio responsabile a", .italian, false),
        ("Je contacte les clients", .french, true),
        ("Contact details: anna", .english, true),
        ("Call center agent at Acme", .english, true),
    ] as [(String, Vocabulary.Language, Bool)])
    func contactingWithoutAVerb(text: String, language: Vocabulary.Language, speaks: Bool) {
        #expect(self.speaks(text, verbs: [], in: language) == speaks, "\(text)")
    }

    @Test("After a phrase of time or place the subject is the next noun phrase, and a possessive right after a preposition is none", arguments: [
        ("In Rome my sister speaks French", ["speaks"], Vocabulary.Language.english, false),
        ("Since 2016 my sister worked at Acme", ["worked"], .english, false),
        ("In Rome her sister speaks French", ["speaks"], .english, false),
        ("\u{c0} Rome ma s\u{153}ur parle fran\u{e7}ais", ["parle"], .french, false),
        ("Dal 2016 la mia collega lavora presso Acme", ["lavora"], .italian, false),
        ("In my free time I play chess", ["play"], .english, true),
        ("In Rome my email is anna", ["is"], .english, true),
        ("At her company I worked", ["worked"], .english, true),
        ("In Rom spricht meine Schwester Franz\u{f6}sisch", ["spricht"], .german, false),
        ("2012 meinen Abschluss gemacht", ["gemacht"], .german, true),
        ("2016 meine Stelle bei Acme angetreten", ["angetreten"], .german, true),
        ("In Rome Anna speaks French", ["speaks"], .english, false),
        ("\u{c0} Rome Anna parle fran\u{e7}ais", ["parle"], .french, false),
        ("At Acme Anna worked as a nurse", ["worked"], .english, false),
        ("In Rome worked at Acme", ["worked"], .english, false),
        ("In Berlin arbeitete Anna bei Acme", ["arbeitete"], .german, false),
        ("Since 2016 worked at Acme", ["worked"], .english, true),
        ("Currently work at Acme", ["work"], .english, true),
        ("Depuis 2016 travaille chez Acme", ["travaille"], .french, true),
        ("Bei Acme gearbeitet", ["gearbeitet"], .german, true),
        ("Presso l'azienda mia di Roma ho lavorato", ["ho", "lavorato"], .italian, true),
    ] as [Case])
    func subjectAfterALeadingPhrase(_ example: Case) {
        #expect(speaks(example.text, verbs: example.verbs, in: example.language) == example.speaks, "\(example.text)")
    }

    @Test("A clause names another person by a pronoun of a third person, a possession of a person or a name a verb of contacting reaches", arguments: [
        ("I can put you in touch with my manager at", [String](), Vocabulary.Language.english, true),
        ("I can put you in touch with him at", [], .english, true),
        ("You can reach me through my manager at", ["can", "reach"], .english, true),
        ("I suggest you contact Anna at", ["suggest", "contact"], .english, true),
        ("Ich kann dich mit meinem Chef unter in Kontakt bringen", ["kann", "bringen"], .german, true),
        ("Je peux vous mettre en contact avec lui \u{e0}", [], .french, true),
        ("You can reach me at", ["can", "reach"], .english, false),
        ("You can write to me at my personal address", ["can", "write"], .english, false),
        ("Du kannst mir an meine E-Mail-Adresse schreiben", ["kannst", "schreiben"], .german, false),
        ("Erreichen Sie mich unter", ["erreichen"], .german, false),
        ("My email is", ["is"], .english, false),
        ("Email me at if it is urgent", ["email", "is"], .english, false),
        ("Anna s email", [], .english, true),
        ("It s me", ["s"], .english, false),
        ("My email s", [], .english, false),
    ] as [Case])
    func namesAnotherPerson(_ example: Case) {
        let words = Word.words(in: example.text)
        let verbs = Set(words.indices.filter { example.verbs.contains(words[$0].accented) })

        #expect(Voice.namesAnotherPerson(words: words, verbs: verbs, language: example.language) == example.speaks, "\(example.text)")
    }

    @Test("A clause offers the person's contact as their possession of a contact field or a verb of contacting whose object is the person", arguments: [
        ("My email is", ["is"], Vocabulary.Language.english, true),
        ("My portfolio is", ["is"], .english, true),
        ("You can reach me at", ["can", "reach"], .english, true),
        ("Puoi contattarmi a", [], .italian, true),
        ("Meine E-Mail-Adresse ist", ["ist"], .german, true),
        ("I am at", ["am"], .english, false),
        ("I worked with the team at", ["worked"], .english, false),
        ("I can put you in touch with the recruiter at", ["can", "put"], .english, false),
        ("My job is at", ["is"], .english, false),
        ("My contact is", ["is"], .english, false),
        ("Vous pouvez me contacter \u{e0} Turin \u{e0}", [], .french, true),
        ("I can be reached at", ["can", "be", "reached"], .english, true),
        ("Sono raggiungibile a", ["sono"], .italian, true),
        ("Ich bin unter erreichbar", ["bin"], .german, true),
        ("I am at", ["am"], .english, false),
    ] as [Case])
    func offersAContact(_ example: Case) {
        let words = Word.words(in: example.text)
        let verbs = Set(words.indices.filter { example.verbs.contains(words[$0].accented) })

        #expect(Voice.offersAContact(words: words, verbs: verbs, language: example.language) == example.speaks, "\(example.text)")
    }

    @Test("Beside a contact stand only contact and field words, numbers, function words and the words of its shape", arguments: [
        ("Feel free to contact me at 333", Vocabulary.Language.english, true), ("You can reach me through my email", .english, true),
        ("Puoi contattarmi a", .italian, true), ("Du kannst mich unter erreichen", .german, true), ("My email is", .english, true),
        ("N hésitez pas à me contacter à", .french, true), ("Não hesite em me contatar em", .portuguese, true),
        ("You can reach me through Anna at", .english, false), ("Puoi contattarmi tramite Anna a", .italian, false),
        ("I can put you in touch with the recruiter at", .english, false), ("Reference Anna Verdi", .english, false),
    ] as [(String, Vocabulary.Language, Bool)])
    func besideAContact(text: String, language: Vocabulary.Language, stands: Bool) {
        #expect(Word.words(in: text).allSatisfy { Voice.standsBesideAContact($0, in: language) } == stands, "\(text)")
    }

    @Test("A verbless clause before a verbless contact is explained by label words, and function words and forms of to be of any language", arguments: [
        ("Software engineer", Vocabulary.Language.english, false), ("Sono", .portuguese, true), ("Email", .english, true),
        ("Anna Verdi", .english, false), ("a nurse in", .english, false), ("Since 2016", .english, true),
    ] as [(String, Vocabulary.Language, Bool)])
    func explainedBeforeAContact(text: String, language: Vocabulary.Language, explained: Bool) {
        #expect(Word.words(in: text).allSatisfy { Voice.explainsBeforeAContact($0, in: language) } == explained, "\(text)")
    }

    @Test("A word of a references section counts in any of the six languages", arguments: [
        ("References", true), ("Referente Anna Verdi", true), ("Referenzen", true), ("Referencias", true), ("R\u{e9}f\u{e9}rences", true),
        ("Refer\u{ea}ncias", true), ("Recommendation", true), ("Email me", false), ("I referred clients", false),
    ] as [(String, Bool)])
    func reference(text: String, holds: Bool) {
        #expect(Voice.holdsAReference(Word.words(in: text)) == holds, "\(text)")
    }

    @Test("A label is made of words that name a contact or a field, numbers and function words that are no verbs", arguments: [
        ("Email", Vocabulary.Language.english, true), ("Contact details", .english, true), ("Phone 39 333", .english, true),
        ("Courriel", .english, true), ("Il mio numero di telefono", .italian, true),
        ("I am at", .english, false), ("Sono a", .italian, false), ("Reference Anna", .english, false), ("Posso metterti in contatto", .italian, false),
    ] as [(String, Vocabulary.Language, Bool)])
    func label(text: String, language: Vocabulary.Language, isALabel: Bool) {
        #expect(Word.words(in: text).allSatisfy { Voice.standsInALabel($0, in: language) } == isALabel, "\(text)")
    }

    @Test("A clause with no verb is someone else's only with a pronoun of the third person, or a possession of a person that starts it", arguments: [
        ("She", Vocabulary.Language.english, false), ("My sister", .english, false), ("My colleague Anna", .english, false),
        ("Lei", .italian, false), ("Mia sorella", .italian, false), ("Il mio responsabile Anna", .italian, false),
        ("Er", .german, false), ("Meine Chefin Anna", .german, false),
        ("Ella", .spanish, false), ("Él", .spanish, false), ("Mi jefa", .spanish, false),
        ("Elle", .french, false), ("Ma collègue", .french, false), ("Her email", .english, false), ("Sua irmã", .portuguese, false),
        ("Ela", .portuguese, false), ("Minha irmã", .portuguese, false),
        ("Beta", .english, true), ("Nurse at Acme", .english, true), ("Since 2016", .english, true), ("Alice, nurse", .english, true),
        ("2012 meinen Abschluss", .german, true), ("Dal 2016", .italian, true), ("El ajedrez", .spanish, true),
        ("My email", .english, true), ("Il mio inglese", .italian, true), ("Languages Italian native", .english, true),
    ] as [(String, Vocabulary.Language, Bool)])
    func withoutAVerb(text: String, language: Vocabulary.Language, speaks: Bool) {
        #expect(self.speaks(text, verbs: [], in: language) == speaks, "\(text)")
    }

    @Test("Without a language the words of every language are read")
    func withoutALanguage() {
        #expect(!speaks("Mia sorella", verbs: [], in: nil))
        #expect(speaks("Beta", verbs: [], in: nil))
        #expect(speaks("Ich arbeite bei Acme", verbs: ["arbeite"], in: nil))
        #expect(!speaks("Alice arbeitet bei Acme", verbs: ["arbeitet"], in: nil))
        #expect(speaks("Mi sono laureata nel 2012", verbs: ["sono", "laureata"], in: nil), "Spanish \"mi\" is my, Italian \"mi\" is me: a possessive owns what follows")
        #expect(speaks("I miei colleghi hanno lavorato", verbs: ["hanno", "lavorato"], in: nil) == false, "the Italian article \"i\" is not the English pronoun")
        #expect(speaks("Il mio inglese è fluente", verbs: ["è"], in: nil))
        #expect(!speaks("Contacta a mi agente en", verbs: [], in: nil), "Italian \"mi\" is me, Spanish \"mi\" is my: with no language it is no object")
    }
}

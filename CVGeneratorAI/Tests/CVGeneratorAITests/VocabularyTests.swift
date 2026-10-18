import Testing
import Foundation
@testable import CVGeneratorAI

/// The closed vocabulary of ADR 0023: a short list per language, written as `DescriptionText.normalized` writes a word. A
/// missing word only drops data; a word that should not be there lets a clause back an entry it should not.
@Suite("Vocabulary: the words that explain themselves")
struct VocabularyTests {
    @Test("Every entry is written as normalized writes a word, so a word of a description meets it as it is")
    func entriesAreNormalized() {
        for language in Vocabulary.Language.allCases {
            let words = language.words
            let kinds = [words.function, words.verbs, words.time, words.level, words.studying, words.timePhrase, words.graduating, words.graduationFrame]
            for entry in kinds.flatMap({ $0 }) {
                #expect(DescriptionText.normalized(entry) == entry, "\(language): \(entry)")
                #expect(!entry.contains(" ") && !entry.contains("'"), "\(language): \(entry)")
            }
        }
    }

    @Test("No negation, hedge or \"without\" is a word of the vocabulary: they change what a clause states",
          arguments: [
            "not", "never", "none", "nobody", "nothing", "neither", "nor", "about", "around", "approximately", "roughly", "nearly",
            "almost", "over", "under", "up", "more", "most", "less", "least", "than", "only", "without", "yet",
            "non", "nessuno", "niente", "nulla", "piu", "meno", "quasi", "almeno", "oltre", "solo", "circa", "senza",
            "nicht", "kein", "keine", "nie", "niemals", "nichts", "etwa", "fast", "mehr", "weniger", "nur", "uber", "ohne",
            "nunca", "jamas", "nadie", "nada", "casi", "menos", "apenas", "sin",
            "pas", "jamais", "personne", "rien", "aucun", "environ", "presque", "plus", "moins", "seulement", "sans",
            "nao", "nem", "ninguem", "nenhum", "quase", "somente", "sem",
          ])
    func negationsAndHedgesAreOut(word: String) {
        #expect(!Vocabulary.explains(word), "\(word)")
        #expect(!Vocabulary.explains(word, in: .portuguese), "\(word)")
    }

    @Test("A word that means a negation in one language is explained only in the languages where it is none")
    func wordsOfOneLanguageOnly() {
        #expect(!Vocabulary.explains("no"))
        #expect(!Vocabulary.explains("no", in: .spanish))
        #expect(Vocabulary.explains("no", in: .portuguese))
        #expect(!Vocabulary.explains("mai"))
        #expect(!Vocabulary.explains("mai", in: .italian))
        #expect(Vocabulary.explains("mai", in: .german))
        #expect(Vocabulary.explains("mai", in: .french))
    }

    @Test("The plain words of a CV are explained", arguments: [
        "worked", "taught", "trained", "studied", "graduated", "started", "moved", "employed", "since", "from", "years", "now", "degree",
        "ho", "lavorato", "insegno", "dal", "anni", "laureata", "scuola", "habe", "gearbeitet", "unterrichte", "seit", "jahre", "abschluss",
        "trabaje", "desde", "anos", "gradue", "travaille", "enseigne", "depuis", "diplome", "ecole", "trabalhei", "leciono",
        "universidade", "formei", "j", "l", "dell",
    ])
    func plainWords(word: String) {
        #expect(Vocabulary.explains(word), "\(word)")
    }

    @Test("A descriptive word, a name or a place is not explained: it stops a clause from backing an entry",
          arguments: [
            "nurse", "nurses", "teacher", "teachers", "hospital", "department", "cardiology", "intensive", "certificate", "certifications",
            "stayed", "caring", "dedicated", "busy", "pupils", "experience", "healthcare", "python", "beta", "acme", "globex", "jane", "smith",
            "infermiera", "insegnanti", "alunni", "esperienza", "krankenschwester", "lehrkrafte", "erfahrung", "enfermeras", "maestros",
            "infirmieres", "enseignants", "creche", "professores", "alunos",
          ])
    func descriptiveWordsAreNot(word: String) {
        #expect(!Vocabulary.explains(word), "\(word)")
    }

    @Test("A form the lists do not give is not explained, and a lemma never turns it into one: the future and the conditional of a CV verb are no listed form",
          arguments: ["reworked", "lavorero", "lavorera", "lavorerei", "trabajare", "trabajaria", "travaillerai", "travaillerais", "trabalharei", "trabalharia", "werde", "wird"])
    func formsThatAreNotListed(word: String) {
        #expect(!Vocabulary.explains(word), "\(word)")
    }

    @Test("The CV verbs are listed in their present and past forms", arguments: [
        "work", "works", "worked", "working", "lavoro", "lavora", "lavorato", "lavoravo", "lavorai", "arbeite", "arbeitet", "arbeitete", "gearbeitet",
        "trabajo", "trabaje", "trabajado", "trabajaba", "travaille", "travaillais", "trabalho", "trabalhei", "trabalhava",
    ])
    func presentAndPastForms(word: String) {
        #expect(Vocabulary.explains(word), "\(word)")
    }

    @Test("A word of negation, doubt or degree, wish or intention, future or condition is in no list of the vocabulary",
          arguments: [
            "not", "never", "barely", "almost", "nearly", "partly", "want", "hope", "plan", "would", "will", "shall", "can", "may", "if", "unless",
            "non", "mai", "appena", "malapena", "quasi", "voglio", "vorrei", "sara", "se", "si",
            "nicht", "kaum", "fast", "wenn", "werde", "wird", "moechte", "kann",
            "apenas", "casi", "quiero", "gustaria", "sera",
            "peine", "presque", "veux", "voudrais", "serai",
            "mal", "quase", "quero", "gostaria", "serei",
          ])
    func modalityIsOutsideTheVocabulary(word: String) {
        #expect(!Vocabulary.explains(word), "\(word)")
    }

    @Test("A clause is read for its words of negation, doubt, wish, future and condition, in the six languages")
    func modality() {
        #expect(Vocabulary.modality(in: Word.words(in: "I have barely managed a school")) == ["barely"])
        #expect(Vocabulary.modality(in: Word.words(in: "I would like to work at Acme")) == ["would"])
        #expect(Vocabulary.modality(in: Word.words(in: "If Acme hires me, I will work there")) == ["if", "will"])
        #expect(Vocabulary.modality(in: Word.words(in: "Ho gestito a malapena una scuola")) == ["malapena"])
        #expect(Vocabulary.modality(in: Word.words(in: "Se Acme mi assume vorrei restare")) == ["se", "vorrei"])
        #expect(Vocabulary.modality(in: Word.words(in: "Ich werde bei Acme arbeiten, wenn ich kaum Zeit habe")) == ["werde", "wenn", "kaum"])
        #expect(Vocabulary.modality(in: Word.words(in: "Apenas he dirigido una escuela")) == ["apenas"])
        #expect(Vocabulary.modality(in: Word.words(in: "J'ai à peine dirigé une école")) == ["peine"])
        #expect(Vocabulary.modality(in: Word.words(in: "Mal dirigi uma escola")) == ["mal"])
        #expect(Vocabulary.modality(in: Word.words(in: "I worked at Acme in 2012")).isEmpty)
    }

    @Test("A time phrase is made of years and of prepositions and adverbs of time, and the conjunctions that join them",
          arguments: ["from", "to", "since", "until", "and", "currently", "in", "dal", "al", "fino", "oggi", "seit", "bis", "von", "desde", "hasta", "depuis", "jusqu", "ate", "em"])
    func timePhraseWords(word: String) {
        #expect(Vocabulary.isTimePhrase(word), "\(word)")
    }

    @Test("The rest of the vocabulary is not in the time-phrase list: a word of it can be a name",
          arguments: ["at", "next", "for", "with", "the", "worked", "nurse", "years", "march", "presso", "ora", "bei", "heute", "hoy", "chez", "demain", "na", "hoje", "per", "da"])
    func wordsOutsideTheTimePhraseList(word: String) {
        #expect(!Vocabulary.isTimePhrase(word), "\(word)")
    }

    @Test("The words of graduating, and the words that go with them", arguments: [
        "graduated", "laureata", "laureato", "abschluss", "abgeschlossen", "diplome", "diplomee", "gradue", "graduada", "formei", "formado",
    ])
    func graduatingWords(word: String) {
        #expect(Vocabulary.isGraduating(word), "\(word)")
    }

    @Test("Obtained, made and the pronouns only go with the words of graduating, and are no word of graduating", arguments: ["obtenu", "gemacht", "mi", "sono", "mon", "meinen", "me"])
    func graduationFrameWords(word: String) {
        #expect(Vocabulary.isGraduationFrame(word), "\(word)")
        #expect(!Vocabulary.isGraduating(word), "\(word)")
    }

    @Test("Words that deny are read in a clause, and Portuguese no is in the")
    func denials() {
        #expect(Vocabulary.modality(in: Word.words(in: "I have never managed a school")) == ["never"])
        #expect(Vocabulary.modality(in: Word.words(in: "I don't manage a school")) == ["n't"])
        #expect(Vocabulary.modality(in: Word.words(in: "Je n'ai jamais dirigé une école")) == ["n", "jamais"])
        #expect(Vocabulary.modality(in: Word.words(in: "Non ho mai gestito una scuola")) == ["non", "mai"])
        #expect(Vocabulary.modality(in: Word.words(in: "Ich habe eine Schule geleitet")).isEmpty)
        #expect(Vocabulary.modality(in: Word.words(in: "No he dirigido una escuela")) == ["no"])
        #expect(Vocabulary.modality(in: Word.words(in: "Trabalho no hospital"), language: .portuguese).isEmpty, "no is in the, in Portuguese")
    }

    @Test("A word of negation, doubt or condition of one language is another word in the description's language, and states nothing there",
          arguments: [
            ("I worked at Acme in a fast team", Vocabulary.Language.english, "fast"), ("I worked at the Sioux Falls clinic", .english, "falls"),
            ("Diseñé un plan de formación", .spanish, "plan"), ("J'ai écrit un plan de soins", .french, "plan"),
            ("J'ai écrit des plans de soins", .french, "plans"), ("Ho gestito casi complessi", .italian, "casi"),
            ("Lavoro la sera presso Acme", .italian, "sera"), ("Se me asignó la formación", .spanish, "se"),
            ("Une équipe qui se forme", .french, "se"), ("Mi si è affidato un reparto", .italian, "si"), ("Trabalho para si", .portuguese, "si"),
          ])
    func modalityOfAnotherLanguage(text: String, language: Vocabulary.Language, word: String) {
        #expect(!Vocabulary.modality(in: Word.words(in: text), language: language).contains(word), "\(word) in \(language)")
        #expect(Vocabulary.modality(in: Word.words(in: text)).contains(word), "\(word), in a description of no known language")
    }

    @Test("The same word still states negation, doubt or condition in its own language", arguments: [
        ("Ich habe fast 3 Jahre gearbeitet", Vocabulary.Language.german, "fast"), ("Falls Acme mich einstellt", .german, "falls"),
        ("I plan to work at Acme", .english, "plan"), ("Casi tres años", .spanish, "casi"), ("Je sera", .french, "sera"),
        ("Si Acme me contrata", .spanish, "si"), ("Si Acme m'embauche", .french, "si"), ("Se Acme mi assume", .italian, "se"),
        ("Se a Acme me contratar", .portuguese, "se"),
    ])
    func modalityOfItsLanguage(text: String, language: Vocabulary.Language, word: String) {
        #expect(Vocabulary.modality(in: Word.words(in: text), language: language).contains(word), "\(word) in \(language)")
    }

    @Test("A hedge of one language is another word in the description's language: a month, or in the")
    func hedgesOfAnotherLanguage() {
        #expect(!DescriptionText.hedgesOrNegates("seit mai 2016 arbeite ich bei acme", language: .german))
        #expect(!DescriptionText.hedgesOrNegates("je travaille chez acme depuis mai 2016", language: .french))
        #expect(!DescriptionText.hedgesOrNegates("desde 2016 trabalho no hospital", language: .portuguese))
        #expect(!DescriptionText.hedgesOrNegates("ho gestito casi complessi", language: .italian))
        #expect(DescriptionText.hedgesOrNegates("seit mai 2016 arbeite ich bei acme"), "with no language, mai is the Italian never")
        #expect(DescriptionText.hedgesOrNegates("non ho mai lavorato presso acme", language: .italian))
        #expect(DescriptionText.hedgesOrNegates("no he trabajado en acme", language: .spanish))
        #expect(DescriptionText.hedgesOrNegates("casi tres anos", language: .spanish))
    }

    @Test("A verb of a CV is known in its inflected forms, by the language of the verb", arguments: [
        "trained", "teach", "taught", "formato", "lavoro", "gearbeitet", "unterrichte", "forme", "travaille", "trabalhei",
    ])
    func verbs(word: String) {
        #expect(Vocabulary.isVerb(word), "\(word)")
    }

    @Test("A verb is one of the language of the description: Spanish \"di\" (I gave) is Italian \"of\"")
    func verbsBelongToTheirLanguage() {
        #expect(Vocabulary.isVerb("di", in: .spanish))
        #expect(!Vocabulary.isVerb("di", in: .italian))
        #expect(Vocabulary.isVerb("di"), "With no language, a form of any language is one")
    }

    @Test("The pronouns of the third person are no word of the vocabulary", arguments: [
        "she", "they", "him", "her", "them", "lei", "lui", "loro", "er", "ihn", "ella", "ellos", "elle", "elles", "ils", "ela", "eles",
    ])
    func noThirdPerson(pronoun: String) {
        #expect(!Vocabulary.explains(pronoun), "\(pronoun)")
    }

    @Test("A verb form of another person is told in the languages that drop the pronoun, and \"era\" is the first person too")
    func otherPersons() {
        #expect(Vocabulary.isOtherPerson("ha", in: .italian))
        #expect(Vocabulary.isOtherPerson("lavor\u{f2}", in: .italian))
        #expect(!Vocabulary.isOtherPerson("lavoro", in: .italian))
        #expect(Vocabulary.isOtherPerson("trabaj\u{f3}", in: .spanish))
        #expect(!Vocabulary.isOtherPerson("trabaj\u{e9}", in: .spanish))
        #expect(!Vocabulary.isOtherPerson("era", in: .spanish))
        #expect(Vocabulary.isOtherPerson("trabalhou", in: .portuguese))
        #expect(!Vocabulary.isOtherPerson("trabalhei", in: .portuguese))
        #expect(!Vocabulary.isOtherPerson("era", in: .portuguese))
        #expect(!Vocabulary.isOtherPerson("ha", in: .french), "French needs its pronoun")
        #expect(!Vocabulary.isOtherPerson("ha", in: nil))
    }

    @Test("A noun can be the subject of a form of the third person only, in the languages that drop the pronoun")
    func nounSubjects() {
        #expect(Vocabulary.canTakeANounSubject("lavora", in: .italian))
        #expect(Vocabulary.canTakeANounSubject("ha", in: .italian))
        #expect(Vocabulary.canTakeANounSubject("sono", in: .italian), "\"sono\" is the third person plural too")
        #expect(!Vocabulary.canTakeANounSubject("lavori", in: .italian), "\"direzione lavori\" is a list item, not a noun with its verb")
        #expect(!Vocabulary.canTakeANounSubject("lavoro", in: .italian))
        #expect(Vocabulary.canTakeANounSubject("trabaj\u{f3}", in: .spanish))
        #expect(!Vocabulary.canTakeANounSubject("trabajas", in: .spanish))
        #expect(Vocabulary.canTakeANounSubject("trabalhou", in: .portuguese))
        #expect(!Vocabulary.canTakeANounSubject("trabalhas", in: .portuguese))
        #expect(Vocabulary.canTakeANounSubject("ama", in: .italian), "an everyday verb in the third person")
        #expect(Vocabulary.canTakeANounSubject("vive", in: .spanish))
        #expect(Vocabulary.canTakeANounSubject("mora", in: .portuguese))
        #expect(Vocabulary.canTakeANounSubject("travaille", in: .french), "French has its pronoun: any verb can")
        #expect(Vocabulary.canTakeANounSubject("worked", in: .english))
        #expect(Vocabulary.canTakeANounSubject("lavori", in: nil))
    }

    @Test("The third person of an everyday verb is told in its language, and a CV verb is none")
    func everydayVerbs() {
        #expect(Vocabulary.isEverydayVerb("lives", in: .english))
        #expect(Vocabulary.isEverydayVerb("ama", in: .italian))
        #expect(Vocabulary.isEverydayVerb("joue", in: .french))
        #expect(!Vocabulary.isEverydayVerb("ama", in: .english))
        #expect(!Vocabulary.isEverydayVerb("amo", in: .italian), "the first person is the person's")
        #expect(!Vocabulary.isEverydayVerb("lavora", in: .italian), "a CV verb is listed, not an everyday verb")
        #expect(!Vocabulary.isEverydayVerb("ama", in: nil))
    }

    @Test("A neutral word is no noun and no name: a function word, a word of time or of modality, in the language of the description")
    func neutralWords() {
        for word in ["the", "since", "currently", "not", "want", "i"] { #expect(Vocabulary.isNeutral(word, in: .english), "\(word)") }
        for word in ["school", "degree", "fluent", "manager", "worked", "nurse"] { #expect(!Vocabulary.isNeutral(word, in: .english), "\(word)") }
        #expect(Vocabulary.isNeutral("no", in: .spanish), "no is a negation in Spanish")
        #expect(Vocabulary.isNeutral("marco", in: .portuguese), "\"março\" is March")
        #expect(!Vocabulary.isNeutral("marco", in: .italian), "Marco is a name in Italian")
        #expect(Vocabulary.isNeutral("marco", in: nil), "With no language, a word of any language is neutral")
    }

    @Test("A word of level is told in its language")
    func levelWords() {
        #expect(Vocabulary.isLevel("advanced", in: .english))
        #expect(Vocabulary.isLevel("fortgeschritten", in: .german))
        #expect(!Vocabulary.isLevel("fortgeschritten", in: .english))
        #expect(!Vocabulary.isLevel("school", in: .english))
        #expect(Vocabulary.isLevel("fortgeschritten", in: nil))
    }

    @Test("An infinitive is no listed present or past: it explains nothing and says nothing done", arguments: [
        "formare", "trabajar", "travailler", "trabalhar", "arbeiten", "gehen",
    ])
    func infinitives(infinitive: String) {
        #expect(!Vocabulary.isVerb(infinitive), "\(infinitive)")
        #expect(!Vocabulary.explains(infinitive), "\(infinitive)")
    }

    @Test("The present and past of to be and the auxiliaries are written with their accents, and belong to their language")
    func beFormsAndAuxiliaries() {
        #expect(Vocabulary.isBeForm("m", in: .english))
        #expect(Vocabulary.isBeForm("e\u{300}", in: .italian))
        #expect(Vocabulary.isBeForm("\u{e9}", in: .portuguese))
        #expect(!Vocabulary.isBeForm("e", in: .portuguese), "e is and, é is is")
        #expect(!Vocabulary.isBeForm("sono", in: .english))
        #expect(Vocabulary.isBeForm("sono"), "With no language, a form of any language is one")
        #expect(Vocabulary.isAuxiliary("have", in: .english))
        #expect(Vocabulary.isAuxiliary("a", in: .french), "a is has")
        #expect(!Vocabulary.isAuxiliary("\u{e0}", in: .french), "à is at")
        #expect(!Vocabulary.isAuxiliary("a", in: .spanish))
        #expect(!Vocabulary.isAuxiliary("a", in: nil), "With no language, no word is an auxiliary")
    }

    @Test("A noun or a name is no verb of a CV", arguments: ["nurse", "acme", "teachers", "school", "beta", "3"])
    func nounsAreNotVerbs(word: String) {
        #expect(!Vocabulary.isVerb(word), "\(word)")
    }

    @Test("The prepositions that introduce an employer are the ones of the ADR, in the six languages", arguments: [
        "at", "for", "with", "da", "presso", "per", "bei", "fur", "en", "para", "chez", "pour", "em", "na", "no",
    ])
    func employerPrepositions(word: String) {
        #expect(Vocabulary.employerPrepositions.contains(word), "\(word)")
    }

    @Test("A preposition of time or of a manner is no employer's: a quote of the clause after the comma may hold it", arguments: [
        "a", "in", "of", "to", "de", "since", "until",
    ])
    func otherPrepositions(word: String) {
        #expect(!Vocabulary.employerPrepositions.contains(word), "\(word)")
    }

    @Test("An employer preposition of another language is another word in the description's language, and introduces no employer there",
          arguments: [
            ("ai", Vocabulary.Language.french), ("per", .english), ("all", .english), ("am", .english), ("alle", .german), ("da", .german),
            ("da", .spanish), ("da", .portuguese), ("nos", .spanish), ("nos", .french),
          ])
    func employerPrepositionsThatAreAnotherWord(word: String, language: Vocabulary.Language) {
        #expect(!Vocabulary.isEmployerPreposition(word, in: language), "\(word) in \(language)")
        #expect(Vocabulary.isEmployerPreposition(word, in: nil), "\(word), in a description of no known language")
    }

    @Test("An employer preposition introduces an employer in its own language, and in one that has no such word",
          arguments: [
            ("ai", Vocabulary.Language.italian), ("per", .italian), ("da", .italian), ("am", .german), ("nos", .portuguese),
            ("chez", .english), ("at", .italian), ("presso", .french),
          ])
    func employerPrepositionsOfTheDescription(word: String, language: Vocabulary.Language) {
        #expect(Vocabulary.isEmployerPreposition(word, in: language), "\(word) in \(language)")
    }

    @Test("A verb of a CV, a word of level, of studying and of time are explained, so that they may stand in a clause that backs an entry",
          arguments: ["worked", "taught", "managed", "native", "fluent", "school", "degree", "students", "lavorato", "laurea", "gearbeitet", "abschluss", "trabajado", "diplome", "formei", "fundamental", "years", "now", "march", "anni", "jahre", "anos", "today", "currently"])
    func explainedWords(word: String) {
        #expect(Vocabulary.explains(word), "\(word)")
    }

    @Test("A language is read from a BCP 47 tag, whatever its region")
    func languageFromATag() {
        #expect(Vocabulary.Language(tag: "pt-BR") == .portuguese)
        #expect(Vocabulary.Language(tag: "PT") == .portuguese)
        #expect(Vocabulary.Language(tag: "de-AT") == .german)
        #expect(Vocabulary.Language(tag: "ja") == nil)
    }
}

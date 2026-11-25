import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

@Suite("Reading skills, interests, languages and certifications")
struct ListReaderTests {

    private func read(_ text: String) -> Findings {
        let (document, sections) = pasted(text)
        var findings = Findings(document: document)
        for section in sections {
            switch section.kind {
            case .skills: ListReader.readSkills(section, into: &findings)
            case .interests: ListReader.readInterests(section, into: &findings)
            case .languages: LanguageReader.read(section, into: &findings)
            case .certifications: CertificationReader.read(section, into: &findings)
            default: break
            }
        }
        return findings
    }

    @Test("Skills split at commas and bullets; a group's label is left out, prose stays visible")
    func skills() {
        let found = read("""
        Skills
        - Programming languages: Swift, Kotlin, TypeScript
        - Tools: Xcode; Git; CI/CD
        - I enjoy mentoring junior developers and leading code reviews across several teams
        """)
        #expect(found.cv.skills.map(\.value) == ["Swift", "Kotlin", "TypeScript", "Xcode", "Git", "CI/CD"])
        #expect(found.leftOut.map(\.reason) == [.categoryLabel, .categoryLabel])
        #expect(found.unplaced.map(\.text) == ["I enjoy mentoring junior developers and leading code reviews across several teams"])
    }

    @Test("A table of skills keeps the skill; a level in words stays visible, never turned into stars")
    func skillTable() {
        let found = read("""
        ## Competenze
        | Competenza | Livello |
        |---|---|
        | Swift | Esperto |
        | Kotlin | ★★★☆☆ |
        """)
        #expect(found.cv.skills.map(\.value) == ["Swift", "Kotlin"])
        #expect(found.unplaced.map(\.text) == ["Esperto"])
    }

    @Test("A list's last item loses the word that joins it, in each language", arguments: [
        ("Skills", "Order picking, packing, and shipping", ["Order picking", "packing", "shipping"]),
        ("Kenntnisse", "Kommissionieren, Verpacken, und Versand", ["Kommissionieren", "Verpacken", "Versand"]),
        ("Competenze", "Magazzino, imballaggio, e spedizioni", ["Magazzino", "imballaggio", "spedizioni"]),
        ("Habilidades", "Almacén, embalaje, y envíos", ["Almacén", "embalaje", "envíos"]),
        ("Compétences", "Entrepôt, emballage, et expédition", ["Entrepôt", "emballage", "expédition"]),
        ("Competências", "Armazém, embalagem, e expedição", ["Armazém", "embalagem", "expedição"]),
    ])
    func joiningWord(heading: String, line: String, expected: [String]) {
        #expect(read("\(heading)\n\(line)").cv.skills.map(\.value) == expected)
    }

    @Test("A list of multi-word items that ends with a full stop loses its joining word and is not read as a sentence", arguments: [
        ("Skills", "Project management, customer service, and team leadership.",
         ["Project management", "customer service", "team leadership."]),
        ("Kenntnisse", "Strategische Planung, digitale Kommunikation, und freundliche Beratung.",
         ["Strategische Planung", "digitale Kommunikation", "freundliche Beratung."]),
        ("Competenze", "Servizio clienti, gestione magazzino, e controllo qualit\u{e0}.",
         ["Servizio clienti", "gestione magazzino", "controllo qualit\u{e0}."]),
        ("Habilidades", "Servicio cliente, gesti\u{f3}n log\u{ed}stica, y planificaci\u{f3}n estrat\u{e9}gica.",
         ["Servicio cliente", "gesti\u{f3}n log\u{ed}stica", "planificaci\u{f3}n estrat\u{e9}gica."]),
        ("Comp\u{e9}tences", "Service client, gestion logistique, et planification strat\u{e9}gique.",
         ["Service client", "gestion logistique", "planification strat\u{e9}gique."]),
        ("Compet\u{ea}ncias", "Atendimento cliente, gest\u{e3}o log\u{ed}stica, e planeamento estrat\u{e9}gico.",
         ["Atendimento cliente", "gest\u{e3}o log\u{ed}stica", "planeamento estrat\u{e9}gico."]),
    ])
    func joiningWordInAPunctuatedList(heading: String, line: String, expected: [String]) {
        let found = read("\(heading)\n\(line)")
        #expect(found.cv.skills.map(\.value) == expected)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A skill that starts with a joining word's letters is kept as written")
    func joiningLookAlike() {
        let found = read("Skills\nSwift, E-commerce, Yoga, Anderson tooling")
        #expect(found.cv.skills.map(\.value) == ["Swift", "E-commerce", "Yoga", "Anderson tooling"])
    }

    @Test("A plain comma list and a conjunction inside the last item still split as before")
    func plainCommaList() {
        let found = read("Skills\nSwift, Kotlin, TypeScript\nForklift, pallet jack and reach truck")
        #expect(found.cv.skills.map(\.value) == ["Swift", "Kotlin", "TypeScript", "Forklift", "pallet jack and reach truck"])
    }

    @Test("A sentence under a skills heading is kept whole as text not imported, not cut at its commas")
    func sentenceStaysWhole() {
        let found = read("Skills\nI pack orders, check stock, and label parcels.")
        #expect(found.cv.skills.isEmpty)
        #expect(found.unplaced.map(\.text) == ["I pack orders, check stock, and label parcels."])
    }

    @Test("A list of noun phrases that ends with a full stop splits, with or without a preposition inside a phrase", arguments: [
        ("Skills", "Python, machine learning models, SQL databases, cloud computing.",
         ["Python", "machine learning models", "SQL databases", "cloud computing."]),
        ("Kenntnisse", "Python, Machine Learning Modelle, SQL Datenbanken, Cloud Computing Dienste.",
         ["Python", "Machine Learning Modelle", "SQL Datenbanken", "Cloud Computing Dienste."]),
        ("Competenze", "Python, gestione dei progetti, analisi dei dati, controllo di qualit\u{e0}.",
         ["Python", "gestione dei progetti", "analisi dei dati", "controllo di qualit\u{e0}."]),
        ("Habilidades", "Python, gesti\u{f3}n de proyectos, an\u{e1}lisis de datos, control de calidad.",
         ["Python", "gesti\u{f3}n de proyectos", "an\u{e1}lisis de datos", "control de calidad."]),
        ("Comp\u{e9}tences", "Python, gestion de projets, analyse de donn\u{e9}es, contr\u{f4}le qualit\u{e9}.",
         ["Python", "gestion de projets", "analyse de donn\u{e9}es", "contr\u{f4}le qualit\u{e9}."]),
        ("Compet\u{ea}ncias", "Python, gest\u{e3}o de projetos, an\u{e1}lise de dados, controlo de qualidade.",
         ["Python", "gest\u{e3}o de projetos", "an\u{e1}lise de dados", "controlo de qualidade."]),
    ])
    func nounPhraseListWithAFullStop(heading: String, line: String, expected: [String]) {
        let found = read("\(heading)\n\(line)")
        #expect(found.cv.skills.map(\.value) == expected)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A sentence with a subject stays whole as text not imported, in each language", arguments: [
        ("Skills", "I led teams, wrote reports and trained staff."),
        ("Kenntnisse", "Ich leitete Teams, schrieb Berichte und schulte Mitarbeiter."),
        ("Competenze", "Io gestivo i team, scrivevo report e formavo il personale."),
        ("Habilidades", "Yo dirig\u{ed} equipos, escrib\u{ed} informes y form\u{e9} al personal."),
        ("Comp\u{e9}tences", "Je dirigeais des \u{e9}quipes, r\u{e9}digeais des rapports et formais le personnel."),
        ("Compet\u{ea}ncias", "Eu liderei equipas, escrevi relat\u{f3}rios e formei o pessoal."),
    ])
    func sentenceWithASubject(heading: String, line: String) {
        let found = read("\(heading)\n\(line)")
        #expect(found.cv.skills.isEmpty)
        #expect(found.unplaced.map(\.text) == [line])
    }

    @Test("A sentence whose verb is a capitalised brand stays whole", arguments: [
        "I Google suppliers, compare quotes and negotiate contracts.",
        "We Slack clients, track orders and close tickets.",
    ])
    func sentenceWithABrandVerb(line: String) {
        let found = read("Skills\n\(line)")
        #expect(found.cv.skills.isEmpty)
        #expect(found.unplaced.map(\.text) == [line])
    }

    @Test("A list whose first item starts like a pronoun is still a list", arguments: [
        ("EU project management, grant writing, budget planning.",
         ["EU project management", "grant writing", "budget planning."]),
        ("EU grant writing, Vendor onboarding, budget planning.",
         ["EU grant writing", "Vendor onboarding", "budget planning."]),
        ("I Ching practice, tea ceremony, calligraphy tools.",
         ["I Ching practice", "tea ceremony", "calligraphy tools."]),
        ("I Corinthians study, choir singing, church archives.",
         ["I Corinthians study", "choir singing", "church archives."]),
    ])
    func pronounLookalikes(line: String, expected: [String]) {
        let found = read("Skills\n\(line)")
        #expect(found.cv.skills.map(\.value) == expected)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A plain list that ends with a full stop is still a list, with each separator", arguments: [
        "Excel, Word, PowerPoint, Outlook, Teams, SharePoint, Access.",
        "Excel; Word; PowerPoint; Outlook; Teams; SharePoint; Access.",
        "Excel \u{2022} Word \u{2022} PowerPoint \u{2022} Outlook \u{2022} Teams \u{2022} SharePoint \u{2022} Access.",
        "Excel | Word | PowerPoint | Outlook | Teams | SharePoint | Access.",
    ])
    func punctuatedList(line: String) {
        let found = read("Skills\n\(line)")
        #expect(found.cv.skills.map(\.value) == ["Excel", "Word", "PowerPoint", "Outlook", "Teams", "SharePoint", "Access."])
        #expect(found.unplaced.isEmpty)
    }

    @Test("A list of interests that ends with a full stop is not one combined interest")
    func punctuatedInterests() {
        let found = read("Hobbys\nKlettern, Fotografie, Gitarre, Laufen, Kochen, Reisen, Lesen.")
        #expect(found.cv.interests.map(\.value) == ["Klettern", "Fotografie", "Gitarre", "Laufen", "Kochen", "Reisen", "Lesen."])
    }

    @Test("An item that starts with a joining word's letters is kept, in any position and with any separator")
    func joiningWordNames() {
        #expect(read("Skills\nSwift, E Commerce, Y Combinator").cv.skills.map(\.value) == ["Swift", "E Commerce", "Y Combinator"])
        #expect(read("Skills\nSwift; E Commerce").cv.skills.map(\.value) == ["Swift", "E Commerce"])
        #expect(read("Skills\nSwift, e commerce").cv.skills.map(\.value) == ["Swift", "e commerce"])
        #expect(read("Skills\nSwift, Kotlin, E Commerce").cv.skills.map(\.value) == ["Swift", "Kotlin", "E Commerce"])
        #expect(read("Skills\nSwift, Kotlin; and shipping").cv.skills.map(\.value) == ["Swift", "Kotlin", "and shipping"])
        #expect(read("Skills\nand shipping, Swift, Kotlin").cv.skills.map(\.value) == ["and shipping", "Swift", "Kotlin"])
        #expect(read("Hobbys\nKlettern, E Commerce, Y Combinator").cv.interests.map(\.value) == ["Klettern", "E Commerce", "Y Combinator"])
    }

    @Test("A one-letter joining word of another language than the heading's is a name's first word, in skills and interests", arguments: [
        ("Skills", "Marketing, sales, e commerce", ["Marketing", "sales", "e commerce"]),
        ("Skills", "Strategy, sales, y combinator", ["Strategy", "sales", "y combinator"]),
        ("Competenze", "Marketing, vendite, y combinator", ["Marketing", "vendite", "y combinator"]),
        ("Conocimientos informáticos", "Marketing, ventas, e commerce", ["Marketing", "ventas", "e commerce"]),
        ("Kenntnisse", "Marketing, Vertrieb, e commerce", ["Marketing", "Vertrieb", "e commerce"]),
    ])
    func joiningLetterOfAnotherLanguage(heading: String, line: String, expected: [String]) {
        #expect(read("\(heading)\n\(line)").cv.skills.map(\.value) == expected)
    }

    @Test("A joining word of the heading's language is dropped in the interests too, and another language's is kept")
    func joiningWordInInterests() {
        #expect(read("Interests\nHiking, cooking, e commerce").cv.interests.map(\.value) == ["Hiking", "cooking", "e commerce"])
        #expect(read("Interests\nHiking, cooking, and travel").cv.interests.map(\.value) == ["Hiking", "cooking", "travel"])
        #expect(read("Interessi\nEscursioni, cucina, e viaggi").cv.interests.map(\.value) == ["Escursioni", "cucina", "viaggi"])
        #expect(read("Hobbys\nKlettern, Kochen, e commerce").cv.interests.map(\.value) == ["Klettern", "Kochen", "e commerce"])
    }

    @Test("An electronic-prefix term written with a space keeps its e under a heading whose joining word is e, in skills and interests", arguments: [
        ("Competenze", "Marketing, vendite, e commerce", ["Marketing", "vendite", "e commerce"]),
        ("Competenze", "Marketing, vendite, e learning", ["Marketing", "vendite", "e learning"]),
        ("Competenze", "Marketing, vendite, e mail", ["Marketing", "vendite", "e mail"]),
        ("Compet\u{ea}ncias", "Marketing, vendas, e commerce", ["Marketing", "vendas", "e commerce"]),
        ("Compet\u{ea}ncias", "Marketing, vendas, e business", ["Marketing", "vendas", "e business"]),
        ("Compet\u{ea}ncias", "Marketing, vendas, e government", ["Marketing", "vendas", "e government"]),
    ])
    func electronicPrefixKeepsItsE(heading: String, line: String, expected: [String]) {
        #expect(read("\(heading)\n\(line)").cv.skills.map(\.value) == expected)
    }

    @Test("An electronic-prefix term in the interests keeps its e, and a real joiner is still removed", arguments: [
        ("Interessi", "Escursioni, cucina, e commerce", ["Escursioni", "cucina", "e commerce"]),
        ("Interessi", "Escursioni, cucina, e learning", ["Escursioni", "cucina", "e learning"]),
        ("Interessi", "Escursioni, cucina, e viaggi", ["Escursioni", "cucina", "viaggi"]),
        ("Interesses", "Caminhadas, culin\u{e1}ria, e commerce", ["Caminhadas", "culin\u{e1}ria", "e commerce"]),
        ("Interesses", "Caminhadas, culin\u{e1}ria, e viagens", ["Caminhadas", "culin\u{e1}ria", "viagens"]),
    ])
    func electronicPrefixInInterests(heading: String, line: String, expected: [String]) {
        #expect(read("\(heading)\n\(line)").cv.interests.map(\.value) == expected)
    }

    @Test("A real joiner before a word that is not an electronic term is still removed", arguments: [
        ("Competenze", "Java, Python, e Swift", ["Java", "Python", "Swift"]),
        ("Compet\u{ea}ncias", "Java, Python, e Swift", ["Java", "Python", "Swift"]),
    ])
    func realJoinerStillRemoved(heading: String, line: String, expected: [String]) {
        #expect(read("\(heading)\n\(line)").cv.skills.map(\.value) == expected)
    }

    @Test("A sentence with a contracted subject stays whole as text not imported, in the languages that have one", arguments: [
        ("Skills", "I've led teams, written reports and trained staff."),
        ("Skills", "I\u{2019}ve led teams, written reports and trained staff."),
        ("Skills", "I'm leading teams, writing reports and training staff."),
        ("Skills", "We've led teams, written reports and trained staff."),
        ("Skills", "We're leading teams, writing reports and training staff."),
        ("Skills", "I'd led teams, written reports and trained staff."),
        ("Comp\u{e9}tences", "J'ai dirig\u{e9} des \u{e9}quipes, r\u{e9}dig\u{e9} des rapports et form\u{e9} le personnel."),
        ("Comp\u{e9}tences", "J\u{2019}ai dirig\u{e9} des \u{e9}quipes, r\u{e9}dig\u{e9} des rapports et form\u{e9} le personnel."),
        ("Compet\u{ea}ncias", "N\u{f3}s lideramos equipas, escrevemos relat\u{f3}rios e formamos colegas."),
    ])
    func sentenceWithAContractedSubject(heading: String, line: String) throws {
        let result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText("\(heading)\n\(line)")
        #expect(result.cv.skills.isEmpty)
        #expect(result.unplaced.map(\.text) == [line])
    }

    @Test("A list that a source cut short with dots is still a list")
    func cutShortList() {
        let found = read("Compétences\nPrise de commandes, gestion des stocks, service à la clientèle...")
        #expect(found.cv.skills.map(\.value) == ["Prise de commandes", "gestion des stocks", "service à la clientèle..."])
    }

    @Test("Interests split like skills")
    func interests() {
        let found = read("Hobbys\nKlettern, Fotografie · Gitarre")
        #expect(found.cv.interests.map(\.value) == ["Klettern", "Fotografie", "Gitarre"])
    }

    @Test("Languages with CEFR levels and native ones, in each language's words", arguments: [
        ("Inglese – C1", "Inglese", LanguageProficiency.c1), ("Deutsch: Muttersprache", "Deutsch", .native),
        ("Englisch (B2)", "Englisch", .b2), ("Español – lengua materna", "Español", .native), ("Anglais : niveau B1", "Anglais", .b1),
        ("Português (nativo)", "Português", .native), ("English – Native or bilingual", "English", .native),
        ("Italiano madrelingua", "Italiano", .native), ("C1 English", "English", .c1),
    ])
    func levels(text: String, name: String, level: LanguageProficiency) throws {
        let found = read("Languages\n\(text)")
        let language = try #require(found.cv.languages.first)
        #expect(language.name.value == name)
        #expect(language.level?.value == level)
        #expect(language.level?.reading == .languageLevel)
    }

    @Test("A level in words is kept as words, with no level, and flagged")
    func wordsLevel() throws {
        let found = read("Sprachen\nEnglisch – verhandlungssicher\nSpanisch")
        #expect(found.cv.languages.map(\.name.value) == ["Englisch", "Spanisch"])
        #expect(found.cv.languages[0].level == nil)
        #expect(found.cv.languages[0].levelWords?.value == "verhandlungssicher")
        #expect(found.cv.languages[0].levelWords?.check == .levelNotCEFR)
        #expect(found.cv.languages[1].levelWords == nil)
    }

    @Test("Several languages in one line")
    func severalInALine() {
        let found = read("Lingue\nItaliano (madrelingua), Inglese (C1), Francese (B1)")
        #expect(found.cv.languages.map(\.name.value) == ["Italiano", "Inglese", "Francese"])
        #expect(found.cv.languages.map { $0.level?.value } == [.native, .c1, .b1])
    }

    @Test("The Europass rows: the mother tongue, and the grid of the other languages")
    func europass() {
        let found = read("""
        CAPACITÀ E COMPETENZE PERSONALI
        MADRELINGUA\tItaliano
        ALTRE LINGUE\tInglese
        \tB2 B2 B1 B1 B2
        \tFrancese
        \tA2 A2 A2 A2 A2
        """)
        #expect(found.cv.languages.map(\.name.value) == ["Italiano", "Inglese", "Francese"])
        #expect(found.cv.languages.map { $0.level?.value } == [.native, nil, .a2])
        #expect(found.cv.languages[1].levelWords?.check == .levelsDiffer)
    }

    @Test("Certifications: the name, the issuer and the year")
    func certifications() throws {
        let found = read("""
        Certificazioni
        - BLSD – Croce Rossa Italiana (2021)
        - AWS Certified Developer, Amazon Web Services, 2022
        - Corso di primo soccorso
        """)
        try #require(found.cv.certifications.count == 3)
        #expect(found.cv.certifications.map(\.name.value) == ["BLSD", "AWS Certified Developer", "Corso di primo soccorso"])
        #expect(found.cv.certifications.map { $0.issuer?.value } == ["Croce Rossa Italiana", "Amazon Web Services", nil])
        #expect(found.cv.certifications.map { $0.year?.value } == [2021, 2022, nil])
        #expect(found.cv.certifications[0].year?.reading == .year)
    }
}

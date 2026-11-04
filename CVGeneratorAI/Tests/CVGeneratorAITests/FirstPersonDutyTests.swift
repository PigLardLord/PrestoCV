import Testing
@testable import CVGeneratorAI

/// ADR 0031: a duty the person said with a gerund is written in the first person of the job's other duties, so a job's text keeps
/// one form. The dictionary is `TableWordList`, which knows every word but the invented names.
@Suite("A duty said with a gerund, in the job's first person (ADR 0031)")
struct FirstPersonDutyTests {
    private let words = TableWordList()

    @Test("An English gerund duty of a past job is written after I was")
    func englishPastGerund() {
        let duty = FirstPersonDuty.written(
            "setting up the PA systems and mixing the support acts.", current: false, language: .english, wordList: words
        )
        #expect(duty == "I was setting up the PA systems and mixing the support acts.")
    }

    @Test("An English gerund duty of the current job is written after I am")
    func englishCurrentGerund() {
        let duty = FirstPersonDuty.written("training the junior technicians.", current: true, language: .english, wordList: words)
        #expect(duty == "I am training the junior technicians.")
    }

    @Test("An English word in -ing that is no gerund keeps the duty as it is")
    func englishNotGerund() {
        #expect(FirstPersonDuty.written("bring the cables to the stage.", current: false, language: .english, wordList: words)
            == "Bring the cables to the stage.")
    }

    @Test("Each Italian gerund that opens a part is written in the imperfect for a past job")
    func italianPastGerunds() {
        let duty = FirstPersonDuty.written(
            "controllando i quadri elettrici e programmando la manutenzione preventiva.", current: false, language: .italian, wordList: words
        )
        #expect(duty == "Controllavo i quadri elettrici e programmavo la manutenzione preventiva.")
    }

    @Test("Each Italian gerund is written in the present for the current job")
    func italianPresentGerunds() {
        let duty = FirstPersonDuty.written("controllando i quadri, programmando i turni.", current: true, language: .italian, wordList: words)
        #expect(duty == "Controllo i quadri, programmo i turni.")
    }

    @Test("A word that ends as a gerund after an article keeps its form")
    func italianNounKept() {
        let duty = FirstPersonDuty.written("usando il comando del quadro.", current: false, language: .italian, wordList: words)
        #expect(duty == "Usavo il comando del quadro.")
    }

    @Test("A duty that opens with a Portuguese infinitive in -ar or an Italian one in -are is written in the job's first person, each part; another infinitive, a Spanish one, an exception or one the word list does not know keeps the duty (#354, round 10)")
    func infinitiveDuty() {
        #expect(FirstPersonDuty.written("criar um sistema para os pedidos das lojas.", current: true, language: .portuguese, wordList: words)
            == "Crio um sistema para os pedidos das lojas.")
        #expect(FirstPersonDuty.written("revisar as notas e organizar o arquivo.", current: false, language: .portuguese, wordList: words)
            == "Revisava as notas e organizava o arquivo.")
        #expect(FirstPersonDuty.written("revisar las facturas del taller.", current: true, language: .spanish, wordList: words)
            == "Revisar las facturas del taller.")
        #expect(FirstPersonDuty.written("preparare le bolle di consegna.", current: false, language: .italian, wordList: words)
            == "Preparavo le bolle di consegna.")
        #expect(FirstPersonDuty.written("manter os equipamentos da loja.", current: true, language: .portuguese, wordList: words)
            == "Manter os equipamentos da loja.")
        #expect(FirstPersonDuty.written("estar com os clientes da loja.", current: true, language: .portuguese, wordList: words)
            == "Estar com os clientes da loja.")
        #expect(FirstPersonDuty.written("revisar as notas e manter o arquivo.", current: true, language: .portuguese, wordList: words)
            == "Revisar as notas e manter o arquivo.")
        #expect(FirstPersonDuty.written(
            "criar um sistema para os pedidos.", current: true, language: .portuguese, wordList: TableWordList(names: ["crio"])
        ) == "Criar um sistema para os pedidos.")
    }

    @Test("An Italian infinitive in -ere or -ire is written in the imperfect of an ended job; in the current job, whose present often changes the stem, and for an exception, it keeps the duty (#354, round 14)")
    func italianPastOfEveryInfinitive() {
        #expect(FirstPersonDuty.written("seguire i turni del magazzino.", current: false, language: .italian, wordList: words)
            == "Seguivo i turni del magazzino.")
        #expect(FirstPersonDuty.written("leggere le bolle e smistare i resi.", current: false, language: .italian, wordList: words)
            == "Leggevo le bolle e smistavo i resi.")
        #expect(FirstPersonDuty.written("tenere i conti del negozio.", current: true, language: .italian, wordList: words)
            == "Tenere i conti del negozio.")
        #expect(FirstPersonDuty.written("essere il referente del turno.", current: false, language: .italian, wordList: words)
            == "Essere il referente del turno.")
        #expect(FirstPersonDuty.written(
            "seguire i turni del magazzino.", current: false, language: .italian, wordList: TableWordList(names: ["seguivo"])
        ) == "Seguire i turni del magazzino.")
    }

    @Test("An imperfect duty takes the compound past in Italian and the perfect in Portuguese when the job's earlier duties use it; any other duty, or a form the word list does not know, keeps its words (#354, round 12)")
    func pastOfTheHeldDuties() {
        #expect(FirstPersonDuty.inThePast(of: ["Ho riparato le pompe."], "Preparavo le bolle e controllavo i carichi.", language: .italian, wordList: words)
            == "Ho preparato le bolle e controllato i carichi.")
        #expect(FirstPersonDuty.inThePast(of: ["Riparavo le pompe."], "Preparavo le bolle.", language: .italian, wordList: words)
            == "Preparavo le bolle.")
        #expect(FirstPersonDuty.inThePast(of: ["Reparei as bombas."], "Revisava as notas e organizava o arquivo.", language: .portuguese, wordList: words)
            == "Revisei as notas e organizei o arquivo.")
        #expect(FirstPersonDuty.inThePast(of: ["Ho riparato le pompe."], "Leggevo i contatori.", language: .italian, wordList: words)
            == "Leggevo i contatori.")
        #expect(FirstPersonDuty.inThePast(
            of: ["Ho riparato le pompe."], "Preparavo le bolle.", language: .italian, wordList: TableWordList(names: ["preparato"])
        ) == "Preparavo le bolle.")
    }

    @Test("A duty in the first person only gets its capital letter")
    func firstPersonKept() {
        #expect(FirstPersonDuty.written("gestisco le fatture dei fornitori.", current: true, language: .italian, wordList: words)
            == "Gestisco le fatture dei fornitori.")
        #expect(FirstPersonDuty.written("I rigged the lights.", current: false, language: .english, wordList: words) == "I rigged the lights.")
    }

    @Test("A gerund whose first person the word list does not know keeps the duty as the person said it")
    func unknownFormKept() {
        let list = TableWordList(names: ["controllavo"])
        let duty = FirstPersonDuty.written("controllando i quadri elettrici.", current: false, language: .italian, wordList: list)
        #expect(duty == "Controllando i quadri elettrici.")
    }

    // MARK: A first person in -endo that opens a duty (#362)

    @Test("A duty that opens with a first person in -endo (\"prendo\", \"vendo\", \"atendo\") keeps its words, in the current job and in an ended one (#362)",
          arguments: [
              ("Prendo le ordinazioni ai tavoli.", true, Vocabulary.Language.italian),
              ("Prendo le ordinazioni ai tavoli.", false, .italian),
              ("Vendo polizze ai clienti.", true, .italian),
              ("Vendo polizze ai clienti.", false, .italian),
              ("Vendo os produtos da loja.", true, .portuguese),
              ("Vendo os produtos da loja.", false, .portuguese),
              ("Atendo os clientes da loja.", true, .portuguese),
              ("Atendo os clientes da loja.", false, .portuguese),
          ] as [(String, Bool, Vocabulary.Language)])
    func firstPersonInEndoKept(duty: String, current: Bool, language: Vocabulary.Language) {
        #expect(FirstPersonDuty.written(duty, current: current, language: language, wordList: words) == duty)
    }

    @Test("A gerund that opens a duty is still written in the job's first person, and a first person in -endo after it keeps its words (#362)")
    func openingGerundWritten() {
        let list = Self.knowingNoVerb(of: ["programmando"])

        #expect(FirstPersonDuty.written("Programmando la manutenzione.", current: false, language: .italian, wordList: list)
            == "Programmavo la manutenzione.")
        #expect(FirstPersonDuty.written("Programmando la manutenzione e prendo le ordinazioni.", current: true, language: .italian, wordList: list)
            == "Programmo la manutenzione e prendo le ordinazioni.")
    }

    // MARK: A gerund in a later part of a duty in the first person (#362)

    /// A word list that knows no verb whose first person ends as one of `gerunds` ("programmandare"), as no dictionary does, and
    /// none of `others`.
    private static func knowingNoVerb(of gerunds: [String], nor others: Set<String> = []) -> TableWordList {
        let verbs: [String] = gerunds.flatMap { gerund in ["are", "ere", "ire", "ar", "er", "ir"].map { String(gerund.dropLast()) + $0 } }
        return TableWordList(names: TableWordList.inventedNames.union(verbs).union(others))
    }

    @Test("A gerund that opens a later part of a duty in the first person, or after an infinitive, is written in the job's first person (#362)")
    func laterGerundWritten() {
        let list = Self.knowingNoVerb(of: ["programmando", "revisando"])

        #expect(FirstPersonDuty.written("Controllavo i quadri e programmando la manutenzione.", current: false, language: .italian, wordList: list)
            == "Controllavo i quadri e programmavo la manutenzione.")
        #expect(FirstPersonDuty.written("controllo i quadri, programmando i turni.", current: true, language: .italian, wordList: list)
            == "Controllo i quadri, programmo i turni.")
        #expect(FirstPersonDuty.written("Organizo los turnos y revisando las facturas.", current: true, language: .spanish, wordList: list)
            == "Organizo los turnos y reviso las facturas.")
        #expect(FirstPersonDuty.written("Organizava as prateleiras e revisando as notas.", current: false, language: .portuguese, wordList: list)
            == "Organizava as prateleiras e revisava as notas.")
        #expect(FirstPersonDuty.written("controlar os quadros e revisando as notas.", current: false, language: .portuguese, wordList: list)
            == "Controlava os quadros e revisava as notas.")
    }

    @Test("A later part that opens with a first person in -ndo, a word of no verb, or a gerund of an unknown first person keeps the duty (#362)")
    func laterPartKept() {
        #expect(FirstPersonDuty.written("Controllo i quadri e prendo in carico i guasti.", current: true, language: .italian, wordList: words)
            == "Controllo i quadri e prendo in carico i guasti.")
        #expect(FirstPersonDuty.written("Organizo as prateleiras e atendo os clientes.", current: true, language: .portuguese, wordList: words)
            == "Organizo as prateleiras e atendo os clientes.")
        #expect(FirstPersonDuty.written(
            "Controllo i quadri e quando serve cambio i fusibili.", current: true, language: .italian,
            wordList: Self.knowingNoVerb(of: ["quando"], nor: ["quare"])
        ) == "Controllo i quadri e quando serve cambio i fusibili.")
        #expect(FirstPersonDuty.written(
            "Controllavo i quadri e programmando la manutenzione.", current: false, language: .italian,
            wordList: Self.knowingNoVerb(of: ["programmando"], nor: ["programmavo"])
        ) == "Controllavo i quadri e programmando la manutenzione.")
    }
}

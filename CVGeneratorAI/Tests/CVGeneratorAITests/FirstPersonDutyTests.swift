import Testing
@testable import CVGeneratorAI

/// ADR 0031: a duty the person said with a gerund is written in the first person of the job's other duties, so a job's text keeps
/// one form. The dictionary is `TableWordList`, which knows every word but the invented names.
@Suite("A duty said with a gerund, in the job's first person (ADR 0031)")
struct FirstPersonDutyTests {
    private let words = TableWordList()

    /// A dictionary with no verb for the gerunds of the Italian tests below ("controllando", "programmando", "usando"), as none has.
    private let gerunds = TableWordList.knowingNoVerb(of: ["controllando", "programmando", "usando"])

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
            "controllando i quadri elettrici e programmando la manutenzione preventiva.", current: false, language: .italian, wordList: gerunds
        )
        #expect(duty == "Controllavo i quadri elettrici e programmavo la manutenzione preventiva.")
    }

    @Test("Each Italian gerund is written in the present for the current job")
    func italianPresentGerunds() {
        let duty = FirstPersonDuty.written("controllando i quadri, programmando i turni.", current: true, language: .italian, wordList: gerunds)
        #expect(duty == "Controllo i quadri, programmo i turni.")
    }

    @Test("A word that ends as a gerund after an article keeps its form")
    func italianNounKept() {
        let duty = FirstPersonDuty.written("usando il comando del quadro.", current: false, language: .italian, wordList: gerunds)
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
        let list = TableWordList.knowingNoVerb(of: ["controllando"], nor: ["controllavo"])
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
        let list = TableWordList.knowingNoVerb(of: ["programmando"])

        #expect(FirstPersonDuty.written("Programmando la manutenzione.", current: false, language: .italian, wordList: list)
            == "Programmavo la manutenzione.")
        #expect(FirstPersonDuty.written("Programmando la manutenzione e prendo le ordinazioni.", current: true, language: .italian, wordList: list)
            == "Programmo la manutenzione e prendo le ordinazioni.")
    }

    // MARK: A gerund in a later part of a duty in the first person (#362)

    @Test("A gerund that opens a later part of a duty in the first person, after a joiner, or after an infinitive, is written in the job's first person (#362)")
    func laterGerundWritten() {
        let list = TableWordList.knowingNoVerb(of: ["programmando", "revisando"])

        #expect(FirstPersonDuty.written("Controllavo i quadri e programmando la manutenzione.", current: false, language: .italian, wordList: list)
            == "Controllavo i quadri e programmavo la manutenzione.")
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
            wordList: TableWordList.knowingNoVerb(of: ["quando"], nor: ["quare"])
        ) == "Controllo i quadri e quando serve cambio i fusibili.")
        #expect(FirstPersonDuty.written(
            "Controllavo i quadri e programmando la manutenzione.", current: false, language: .italian,
            wordList: TableWordList.knowingNoVerb(of: ["programmando"], nor: ["programmavo"])
        ) == "Controllavo i quadri e programmando la manutenzione.")
    }

    // MARK: A gerund whose verb the word list cannot find from the gerund (#362)

    /// A gerund of a verb whose stem the gerund does not keep ("facendo" is of "fare", "sirviendo" of "servir"), with the first
    /// person of the imperfect and of the present, and what the duty goes on with.
    struct IrregularGerund: Sendable, CustomTestStringConvertible {
        let language: Vocabulary.Language
        /// The gerund's stem: the word list knows no verb that is this stem and an infinitive ending ("facere"), as no dictionary does.
        let stem: String
        let gerund: String
        let past: String
        let present: String
        let object: String

        var testDescription: String { gerund }

        /// A word list that knows no verb of the gerund, neither one that makes it ("facere") nor one that it ends as the first person of.
        var words: TableWordList {
            TableWordList.knowingNoVerb(of: [gerund], nor: Set(["are", "ere", "ire", "ar", "er", "ir"].map { stem + $0 }))
        }

        static let all: [IrregularGerund] = [
            italian("fac", "facendo", "facevo", "faccio"),
            italian("dic", "dicendo", "dicevo", "dico"),
            italian("traduc", "traducendo", "traducevo", "traduco"),
            italian("propon", "proponendo", "proponevo", "propongo"),
            italian("conduc", "conducendo", "conducevo", "conduco"),
            italian("produc", "producendo", "producevo", "produco"),
            italian("manten", "mantenendo", "mantenevo", "mantengo"),
            italian("otten", "ottenendo", "ottenevo", "ottengo"),
            spanish("sirv", "sirviendo", "servía", "sirvo"),
            spanish("pid", "pidiendo", "pedía", "pido"),
            spanish("durm", "durmiendo", "dormía", "duermo"),
            spanish("dic", "diciendo", "decía", "digo"),
            spanish("hac", "haciendo", "hacía", "hago"),
            spanish("sig", "siguiendo", "seguía", "sigo"),
            spanish("ten", "teniendo", "tenía", "tengo"),
            portuguese("faz", "fazendo", "fazia", "faço"),
            portuguese("diz", "dizendo", "dizia", "digo"),
            portuguese("traz", "trazendo", "trazia", "trago"),
            portuguese("mant", "mantendo", "mantinha", "mantenho"),
            portuguese("ped", "pedindo", "pedia", "peço"),
        ]

        private static func italian(_ stem: String, _ gerund: String, _ past: String, _ present: String) -> IrregularGerund {
            IrregularGerund(language: .italian, stem: stem, gerund: gerund, past: past, present: present, object: "i documenti del reparto")
        }

        private static func spanish(_ stem: String, _ gerund: String, _ past: String, _ present: String) -> IrregularGerund {
            IrregularGerund(language: .spanish, stem: stem, gerund: gerund, past: past, present: present, object: "los documentos del taller")
        }

        private static func portuguese(_ stem: String, _ gerund: String, _ past: String, _ present: String) -> IrregularGerund {
            IrregularGerund(language: .portuguese, stem: stem, gerund: gerund, past: past, present: present, object: "os documentos da loja")
        }
    }

    @Test("A duty that opens with the gerund of an irregular verb is written in the imperfect of an ended job and in the present of the current one, though the word list has no verb that the gerund makes (#362)",
          arguments: IrregularGerund.all)
    func irregularGerundWritten(row: IrregularGerund) {
        let said = row.gerund.prefix(1).uppercased() + row.gerund.dropFirst() + " " + row.object + "."
        func written(_ form: String) -> String { form.prefix(1).uppercased() + form.dropFirst() + " " + row.object + "." }

        #expect(FirstPersonDuty.written(said, current: false, language: row.language, wordList: row.words) == written(row.past))
        #expect(FirstPersonDuty.written(said, current: true, language: row.language, wordList: row.words) == written(row.present))
    }

    @Test("A gerund of an irregular verb that follows a joiner is written in the job's first person, after a gerund or a verb in the first person (#362)")
    func irregularGerundAfterAJoiner() {
        let fare = TableWordList.knowingNoVerb(of: ["controllando", "facendo", "dicendo"], nor: ["facere", "facire", "dicere", "dicire"])
        let servir = TableWordList.knowingNoVerb(of: ["sirviendo"], nor: ["sirvir", "sirver"])

        #expect(FirstPersonDuty.written(
            "Controllando i quadri elettrici e facendo la manutenzione preventiva.", current: false, language: .italian, wordList: fare
        ) == "Controllavo i quadri elettrici e facevo la manutenzione preventiva.")
        #expect(FirstPersonDuty.written("Gestivo gli ordini e facendo l'inventario.", current: false, language: .italian, wordList: fare)
            == "Gestivo gli ordini e facevo l'inventario.")
        #expect(FirstPersonDuty.written(
            "Dicendo ai clienti i tempi di consegna e controllando i preventivi.", current: true, language: .italian, wordList: fare
        ) == "Dico ai clienti i tempi di consegna e controllo i preventivi.")
        #expect(FirstPersonDuty.written("Organizo los turnos y sirviendo a los clientes.", current: true, language: .spanish, wordList: servir)
            == "Organizo los turnos y sirvo a los clientes.")
    }

    @Test("An irregular gerund whose first person the word list does not know keeps the duty as the person said it, and the duty check sees the gerund it joins to a verb (#362)")
    func irregularGerundOfAnUnknownFormKept() {
        let list = TableWordList.knowingNoVerb(of: ["facendo"], nor: ["facere", "facire", "facevo"])

        #expect(FirstPersonDuty.written("Facendo la manutenzione preventiva.", current: false, language: .italian, wordList: list)
            == "Facendo la manutenzione preventiva.")
        #expect(FirstPersonDuty.written("Gestivo gli ordini e facendo l'inventario.", current: false, language: .italian, wordList: list)
            == "Gestivo gli ordini e facendo l'inventario.")
        #expect(FirstPersonDuty.joinsAGerund("Gestivo gli ordini e facendo l'inventario.", language: .italian, wordList: list))
    }

    // MARK: A gerund after a comma is an adjunct (#362)

    @Test("A gerund after a comma is the adjunct of a verb in the first person (\"by coordinating the suppliers\"), so it keeps its words, and the duty check does not take it for a mixed form (#362)",
          arguments: [
              ("Gestivo gli ordini, coordinando i fornitori.", false, Vocabulary.Language.italian, "coordinando"),
              ("Gestisco gli ordini, coordinando i fornitori.", true, .italian, "coordinando"),
              ("Gestiono los pedidos, coordinando a los proveedores.", true, .spanish, "coordinando"),
              ("Gerenciava os pedidos, coordenando os fornecedores.", false, .portuguese, "coordenando"),
          ] as [(String, Bool, Vocabulary.Language, String)])
    func gerundAfterACommaKept(duty: String, current: Bool, language: Vocabulary.Language, gerund: String) {
        let list = TableWordList.knowingNoVerb(of: [gerund])

        #expect(FirstPersonDuty.written(duty, current: current, language: language, wordList: list) == duty)
        #expect(!FirstPersonDuty.joinsAGerund(duty, language: language, wordList: list))
    }

    @Test("A gerund after a comma keeps its words when a part before it is no gerund of the list, or the duty opens with an infinitive; after a joiner it is still written (#362)")
    func gerundAfterACommaOutsideAList() {
        let list = TableWordList.knowingNoVerb(of: ["controllando", "programmando", "revisando"])

        #expect(FirstPersonDuty.written(
            "Controllando i quadri e prendo le misure, programmando i turni.", current: true, language: .italian, wordList: list
        ) == "Controllo i quadri e prendo le misure, programmando i turni.")
        #expect(FirstPersonDuty.written("Controlar os quadros, revisando as notas.", current: false, language: .portuguese, wordList: list)
            == "Controlava os quadros, revisando as notas.")
        #expect(FirstPersonDuty.written("Controlar os quadros, revisando as notas e revisando os turnos.", current: false, language: .portuguese, wordList: list)
            == "Controlava os quadros, revisando as notas e revisava os turnos.")
    }
}

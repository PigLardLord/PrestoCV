import Testing
@testable import CVGeneratorAI

/// The draft of iOS 27's model (`DraftDepth`; #354, probe rounds 3 and 4): more duties, tools and summary sentences, a summary slot
/// for the tools, and rules that ask for the tools by name. iOS 26's model keeps the plain draft, which the other suites pin. Every
/// name and trade is invented.
@MainActor
@Suite("A rich draft, of iOS 27's model (probe rounds 3 and 4)", .richDraft)
struct RichDraftTests {
    private static let brief = DraftBrief(
        language: "English", headline: "head of sound",
        roles: [
            .init(title: "stagehand", hasEnded: true), .init(title: "sound technician", hasEnded: true),
            .init(title: "head of sound", hasEnded: false),
        ],
        studies: [], namedSkills: []
    )
    private static let duties = [["I rigged the lights."], [], ["I train the junior technicians.", "I plan the rehearsals.", "I mix the shows."]]
    private static let tools = ["Pro Tools", "DiGiCo SD7", "in-ear monitors", "XLR cables", "Dante"]

    // MARK: The amounts

    @Test("Each job gets 5 to 6 duties, the person's first, at least one typical one below 6; the tools, the tokens and the summary sentences grow with them")
    func amounts() {
        #expect(DraftBrief.Role.leastDuties == 5)
        #expect(DraftBrief.Role.mostDuties == 6)
        #expect([0, 1, 4, 5, 6, 8].map(DraftBrief.Role.adding(said:)) == [5, 4, 1, 1, 0, 0])
        #expect(DraftBrief.Role(title: "stagehand", hasEnded: true).adding == 5)
        // Probe round 13: capped at 8 and 5, the draft kept 8 of the 10 or more technologies its requests wrote.
        #expect(SectionDraft.technologies == 12)
        #expect(SectionDraft.softSkills == 6)
        #expect(InferredSkills.caps == [.technology: 12, .softSkill: 6])
        #expect([false, true].map(SectionDraft.fewestTools(sparse:)) == [10, 6])
        #expect([false, true].map(SectionDraft.fewestQualities(sparse:)) == [4, 3])
        #expect(SectionPrompts.softSkillsInstructions.contains("You name 4 to 6 personal qualities at work"))
        #expect(FoundationModelsService.jobTokens == 340)
        #expect(FoundationModelsService.jobRepairTokens == 280)
        #expect(FoundationModelsService.jobRepairDuties == 5)
        #expect(SectionDraft.summaryRequests == 10)
        #expect(SectionDraft.summaryEnough.sentences == 4)
        #expect(SectionDraft.summaryEnough.characters == 450)
    }

    // MARK: The summary's slots

    @Test("The summary's slots: the role, the first work, three tools, the next work with two qualities, the latest ended job, then the rest of the tools and qualities for a summary still short (probe rounds 15 and 17)")
    func summaryTopics() {
        let topics = SectionDraft.summaryTopics(
            of: Self.brief, duties: Self.duties, typical: [[], [], []], qualities: ["teamwork", "calm", "care"], field: "live sound",
            order: [2, 1, 0], tools: Self.tools
        )

        // The field goes: the job has a title.
        #expect(topics == [
            SummaryTopic(title: "head of sound", hasEnded: false),
            SummaryTopic(title: "head of sound", work: ["the junior technicians", "the rehearsals"], hasEnded: false),
            SummaryTopic(title: "head of sound", tools: ["Pro Tools", "DiGiCo SD7", "in-ear monitors"], hasEnded: false),
            SummaryTopic(title: "head of sound", work: ["the shows"], qualities: ["teamwork", "calm"], hasEnded: false),
            SummaryTopic(title: "stagehand", work: ["the lights"], hasEnded: true),
            SummaryTopic(title: "head of sound", tools: ["XLR cables", "Dante"], hasEnded: false),
            SummaryTopic(title: "head of sound", qualities: ["care"], hasEnded: false),
        ])
        // The opening says the title: the role slot comes last, for a summary still short (probe round 17).
        let opened = SectionDraft.summaryTopics(
            of: Self.brief, duties: Self.duties, typical: [[], [], []], qualities: ["teamwork", "calm", "care"], field: "live sound",
            order: [2, 1, 0], tools: Self.tools, hasOpening: true
        )
        #expect(opened == Array(topics.dropFirst()) + [topics[0]])
    }

    @Test("The first qualities slot says them with the second pair of work, and that work gets no slot of its own (probe rounds 10 and 15)")
    func qualitiesWithWork() {
        let duties = [[], [], [
            "I train the junior technicians.", "I plan the rehearsals.", "I mix the shows.", "I tune the rooms.", "I patch the stage boxes.",
        ]]
        let topics = SectionDraft.summaryTopics(
            of: Self.brief, duties: duties, typical: [[], [], []], qualities: ["teamwork", "calm", "care"], field: nil,
            order: [2, 1, 0], tools: Array(Self.tools.prefix(3)), hasOpening: true
        )

        #expect(topics == [
            SummaryTopic(title: "head of sound", work: ["the junior technicians", "the rehearsals"], hasEnded: false),
            SummaryTopic(title: "head of sound", tools: ["Pro Tools", "DiGiCo SD7", "in-ear monitors"], hasEnded: false),
            SummaryTopic(title: "head of sound", work: ["the shows", "the rooms"], qualities: ["teamwork", "calm"], hasEnded: false),
            SummaryTopic(title: "head of sound", work: ["the stage boxes"], hasEnded: false),
            SummaryTopic(title: "head of sound", qualities: ["care"], hasEnded: false),
            SummaryTopic(title: "head of sound", hasEnded: false),
        ])
        // With no qualities the second pair keeps its own slot, and the third comes last before the role.
        #expect(SectionDraft.summaryTopics(
            of: Self.brief, duties: duties, typical: [[], [], []], qualities: [], field: nil, order: [2, 1, 0], hasOpening: true
        ).dropLast().last == SummaryTopic(title: "head of sound", work: ["the stage boxes"], hasEnded: false))
    }

    @Test("An ended job's slot asks a topic of its work no earlier slot asks, the job's work no slot asks gets a slot, and with no second pair the first qualities slot asks it (probe rounds 14 and 15)")
    func spareWork() {
        let typical = [[], [], [
            "I train the junior technicians and plan the rehearsals.", "I mix the shows.", "I tune the rooms.", "I patch the stage boxes.",
        ]]
        let duties = [["I trained the junior technicians and rigged the lights."], [], Self.duties[2]]

        let topics = SectionDraft.summaryTopics(
            of: Self.brief, duties: duties, typical: typical, qualities: ["teamwork", "calm"], field: nil, order: [2, 1, 0], hasOpening: true
        )

        #expect(topics == [
            SummaryTopic(title: "head of sound", work: ["the junior technicians", "the rehearsals"], hasEnded: false),
            SummaryTopic(title: "head of sound", work: ["the rooms", "the stage boxes"], qualities: ["teamwork", "calm"], hasEnded: false),
            SummaryTopic(title: "stagehand", work: ["the lights"], hasEnded: true),
            SummaryTopic(title: "head of sound", work: ["the shows"], hasEnded: false),
            SummaryTopic(title: "head of sound", hasEnded: false),
        ])
        // Two typical duties make one pair: the qualities slot asks the work it leaves.
        let short = SectionDraft.summaryTopics(
            of: Self.brief, duties: [[], [], []], typical: [[], [], Array(typical[2].prefix(2))], qualities: ["teamwork", "calm"], field: nil,
            order: [2, 1, 0], hasOpening: true
        )
        #expect(short == [
            SummaryTopic(title: "head of sound", work: ["the junior technicians", "the rehearsals"], hasEnded: false),
            SummaryTopic(title: "head of sound", work: ["the shows"], qualities: ["teamwork", "calm"], hasEnded: false),
            SummaryTopic(title: "head of sound", hasEnded: false),
        ])
        #expect(SectionDraft.unused(["delle comunicazioni ufficiali", "i verbali"], besides: ["le comunicazioni ufficiali"]) == ["i verbali"])
    }

    @Test("A job with no title reads the headline, and its field comes first, or last after an opening; a field that reads as a clause goes")
    func summaryField() {
        let brief = DraftBrief(
            language: "English", headline: "head of sound", roles: [.init(title: "", hasEnded: false)], studies: [], namedSkills: []
        )
        let role = SummaryTopic(title: "head of sound", field: "live sound", hasEnded: false)
        let calm = SummaryTopic(title: "head of sound", qualities: ["calm"], hasEnded: false)
        let topics = { (field: String, hasOpening: Bool) in
            SectionDraft.summaryTopics(
                of: brief, duties: [[]], typical: [[]], qualities: ["calm"], field: field, order: [0], hasOpening: hasOpening
            )
        }

        #expect(topics("live sound", false) == [role, calm])
        #expect(topics("live sound", true) == [calm, role])
        #expect(topics("I know my way around a mixing desk", false) == [SummaryTopic(title: "head of sound", hasEnded: false), calm])
        #expect(topics("I know my way around a mixing desk", true) == [calm, SummaryTopic(title: "head of sound", hasEnded: false)])
        #expect(SectionDraft.cleanField("live sound") == "live sound")
        #expect(SectionDraft.cleanField("front-of-house sound") == "front-of-house sound")
        #expect(SectionDraft.cleanField("Ich kenne mich mit KNX aus") == nil)
        #expect(SectionDraft.cleanField("sound, light") == nil)
        #expect(SectionDraft.cleanField(" ") == nil)
        #expect(SectionDraft.cleanField(nil) == nil)
    }

    @Test("The work slots read the current job's kept duties two at a time, up to three pairs")
    func workTopics() {
        let topics = SectionDraft.workTopics(of: Self.brief, current: 2, duties: Self.duties, typical: [[], [], []])

        #expect(topics.map(\.work) == [["the junior technicians", "the rehearsals"], ["the shows"]])
    }

    // MARK: The tools slots (probe round 13)

    @Test("The tools slots read the products, standards and systems first, then the tools in capitals, the others, and last the fields of the work (probe round 13)")
    func specificFirst() {
        let tools = ["contabilità", "Facturación", "matita", "Excel", "HACCP", "Wartung", "manutenzione", "Balance sheets"]

        #expect(SectionDraft.specificFirst(tools, language: "it")
                == ["HACCP", "Excel", "Balance sheets", "matita", "contabilità", "Facturación", "Wartung", "manutenzione"])
        // German nouns all have a capital: a capital says nothing there.
        #expect(SectionDraft.specificFirst(["Wartung", "Werkzeugkoffer", "SPS-Steuerung", "Messgerät"], language: "de")
                == ["SPS-Steuerung", "Werkzeugkoffer", "Messgerät", "Wartung"])
    }

    @Test("A tools slot asks the tools the summary does not name yet, as many as it holds, and none when it names them all; other slots stay (probe round 13)")
    func unsaidTools() {
        let tools = ["Pro Tools", "DiGiCo SD7", "in-ear monitors", "XLR cables", "Dante"]
        let slot = SummaryTopic(title: "head of sound", tools: ["Pro Tools", "DiGiCo SD7", "in-ear monitors"], hasEnded: false)
        let written = ["I work as head of sound.", "I mix the shows on the digico sd7 and edit them in Pro Tools."]

        #expect(SectionDraft.unsaid(slot, tools: tools, written: written)
                == SummaryTopic(title: "head of sound", tools: ["in-ear monitors", "XLR cables", "Dante"], hasEnded: false))
        #expect(SectionDraft.unsaid(slot, tools: tools, written: []) == slot)
        let said = written + ["I fit the in-ear monitors, run the XLR cables and route the stage over Dante."]
        #expect(SectionDraft.unsaid(slot, tools: tools, written: said) == nil)
        // "Pro" alone is not the tool "Pro Tools".
        let short = SummaryTopic(title: "head of sound", tools: ["Pro Tools"], hasEnded: false)
        #expect(SectionDraft.unsaid(short, tools: tools, written: ["I am a pro at mixing."]) == short)
        let work = SummaryTopic(title: "head of sound", work: ["the shows"], hasEnded: false)
        let qualities = SummaryTopic(title: "head of sound", qualities: ["calm"], hasEnded: false)
        #expect(SectionDraft.unsaid(work, tools: tools, written: said) == work)
        #expect(SectionDraft.unsaid(qualities, tools: tools, written: said) == qualities)
    }

    // MARK: The summary's repeats (probe round 14)

    @Test("A summary sentence repeats an earlier one when it shares most of its content words and adds fewer than two past the kept qualities (probe round 14)")
    func repeatsAnEarlierSentence() {
        #expect(CVDataSanitizer.repeats(
            "Agisco come capoturno della manutenzione.", earlier: ["Lavoro come capoturno della manutenzione."], besides: []
        ))
        #expect(!CVDataSanitizer.repeats(
            "Genero los informes mensuales y mantengo los registros de inventario con Balance y Cuentas.",
            earlier: ["Controlo el inventario y los registros con Balance y Cuentas."], besides: []
        ))
        let sentence = "Sono precisa e puntuale mentre gestisco le comunicazioni ufficiali."
        let earlier = ["Gestisco le comunicazioni ufficiali."]
        #expect(CVDataSanitizer.repeats(sentence, earlier: earlier, besides: ["precisa", "puntuale"]))
        #expect(!CVDataSanitizer.repeats(sentence, earlier: earlier, besides: []))
    }

    @Test("A summary sentence that ends as an earlier one stays when it adds three content words or more to it, and goes with fewer (probe round 14)",
          arguments: [
              // Not after "with": a tail of tools said before is cut instead (`withoutARepeatedTail`, probe round 15).
              ("I check every invoice before it is paid and record it in a ledger and an invoicing program.", true),
              ("I check it with a ledger and an invoicing program.", false),
          ])
    func summaryEndingAsAnEarlierOne(second: String, stays: Bool) throws {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Experience(title: "accountant", company: "Brembo Furniture", startDate: "2017", endDate: nil, current: true)])
        let description = "I live in Lecco. Since 2017 I work as an accountant at Brembo Furniture, where I keep the books and check the invoices."
        // Not with the opening's verb ("I work as…"): a summary of one sentence gets the opening, and a sentence with its verb goes.
        let first = "I keep the books as an accountant with a ledger and an invoicing program."

        let verdict = try english.summaryCheck(of: facts, summary: first + " " + second, field: nil, against: description)

        #expect(verdict.kept == (stays ? [first, second] : [first]), "\(verdict.rejected)")
        #expect(verdict.rejected.contains { $0.sentence == second && $0.reason == CVDataSanitizer.endsAsAnEarlierOne } == !stays)
        // A plain draft keeps the rule as it was: the sentence goes.
        DraftDepth.$pinned.withValue(false) {
            let plain = try? english.summaryCheck(of: facts, summary: first + " " + second, field: nil, against: description)
            #expect(plain?.kept == [first], "\(plain?.rejected ?? [])")
        }
    }

    // MARK: probe round 15

    @Test("A rich summary keeps up to 6 sentences, a plain one 4 (probe rounds 15 and 17)")
    func summaryMost() {
        #expect(CVDataSanitizer.summaryMost == 6)
        #expect(SectionDraft.summarySentences == 6)
        DraftDepth.$pinned.withValue(false) {
            #expect(CVDataSanitizer.summaryMost == 4)
            #expect(SectionDraft.summarySentences == 4)
            #expect(SectionDraft.summaryEnough.sentences == 2)
            #expect(SectionDraft.summaryEnough.characters == 120)
        }
    }

    @Test("A closing phrase that says again what the earlier sentences say goes, and one that adds two content words stays (probe round 15)",
          arguments: [
              ("de", "Ich warte die Kältetechnik der Gebäude, indem ich die Heizungsanlage und die Lüftungsanlage prüfe.",
               ["Ich prüfe die Heizungsanlage und die Lüftungsanlage."], "Ich warte die Kältetechnik der Gebäude."),
              ("pt", "Mantenho o código limpo e testado, usando o Swift e o Xcode.",
               ["Desenvolvo aplicações móveis com Swift e Xcode."], "Mantenho o código limpo e testado."),
              ("it", "Coordino la squadra dei tecnici con il sistema di controllo.",
               ["Gestisco il sistema di controllo degli accessi."], "Coordino la squadra dei tecnici."),
              ("en", "I close the accounts each month, keeping them in Excel and Datev.",
               ["I keep the books in Excel and Datev."], "I close the accounts each month."),
              ("it", "Cuocio le torte con il forno a legna e la planetaria.", ["Uso il forno ogni mattina."], nil),
              ("de", "Ich plane die Wartung, um Ausfälle der Kühlräume zu vermeiden.", ["Ich prüfe die Heizungsanlage."], nil),
              ("it", "Coordino la squadra dei tecnici con il sistema di controllo.", [], nil),
          ] as [(String, String, [String], String?)])
    func repeatedTail(language: String, sentence: String, earlier: [String], kept: String?) {
        let tail = CVDataSanitizer.withoutARepeatedTail(
            of: sentence, earlier: earlier, besides: [], tools: [], language: Vocabulary.Language(rawValue: language)
        )

        #expect(tail == kept)
    }

    @Test("A rich summary keeps a sentence without its tail of tools said before, and a plain one drops it (probe round 15)")
    func summaryWithoutARepeatedTail() throws {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Experience(title: "accountant", company: "Brembo Furniture", startDate: "2017", endDate: nil, current: true)])
        let description = "I live in Lecco. Since 2017 I work as an accountant at Brembo Furniture, where I keep the books and check the invoices."
        let first = "I keep the books as an accountant with a ledger and an invoicing program."
        let second = "I check every invoice before it is paid with the help of a ledger and an invoicing program."

        let verdict = try english.summaryCheck(of: facts, summary: first + " " + second, field: nil, against: description)

        #expect(verdict.kept == [first, "I check every invoice before it is paid."], "\(verdict.rejected)")
        DraftDepth.$pinned.withValue(false) {
            let plain = try? english.summaryCheck(of: facts, summary: first + " " + second, field: nil, against: description)
            #expect(plain?.kept == [first], "\(plain?.rejected ?? [])")
        }
    }

    @Test("A verb of the person after \"o que\", \"lo que\" or \"ciò che\" speaks as the person in a rich draft, and a plural does not (probe round 15)",
          arguments: [
              ("pt", "contabilista", "Móveis Cávado",
               "Moro em Braga. Desde 2017 trabalho como contabilista na Móveis Cávado, onde faço a contabilidade e analiso os movimentos de caixa.",
               "Manter as faturas em ordem é o que faço.", true),
              ("es", "contable", "Muebles Albarracín",
               "Vivo en Teruel. Desde 2017 trabajo como contable en Muebles Albarracín, donde llevo la contabilidad y reviso las facturas.",
               "Revisar cada factura es lo que hago.", true),
              ("it", "contabile", "Mobili Brembo",
               "Vivo a Lecco. Dal 2017 lavoro come contabile da Mobili Brembo, dove tengo la contabilità e controllo le fatture.",
               "Tenere i conti in ordine è ciò che fanno.", false),
          ] as [(String, String, String, String, String, Bool)])
    func verbAfterARelative(language: String, title: String, company: String, description: String, sentence: String, stays: Bool) throws {
        let checker = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Experience(title: title, company: company, startDate: "2017", endDate: nil, current: true)])

        let verdict = try checker.summaryCheck(of: facts, summary: sentence, field: nil, against: description)

        #expect(verdict.rejected.map(\.reason).contains(CVDataSanitizer.hasNoVerbOfThePerson) == !stays, "\(verdict.rejected)")
        // A plain draft keeps the rule as it was: no verb of the person.
        DraftDepth.$pinned.withValue(false) {
            let plain = try? checker.summaryCheck(of: facts, summary: sentence, field: nil, against: description)
            #expect(plain?.rejected.map(\.reason).contains(CVDataSanitizer.hasNoVerbOfThePerson) == true, "\(plain?.rejected ?? [])")
        }
    }

    // MARK: probe round 16

    @Test("A closing clause of time or purpose that says again an earlier sentence goes, a tail of three repeats goes against two added, and a tail of tools said before goes with what they are for (probe round 16)",
          arguments: [
              ("it", "Uso il registro elettronico per annotare le presenze mentre correggo i compiti degli alunni.",
               ["Correggo i compiti degli alunni ogni settimana."], [], "Uso il registro elettronico per annotare le presenze."),
              ("en", "I log the deliveries in the stock system while I check the orders of the week.",
               ["I check the orders of the week every morning."], [], "I log the deliveries in the stock system."),
              ("it", "Accolgo i clienti al banco con il nuovo registratore di cassa e la grande macchina del caffè.",
               ["Uso il registratore di cassa e la macchina del caffè ogni mattina."], [], "Accolgo i clienti al banco."),
              ("it", "Accolgo i clienti al banco con il nuovo registratore di cassa e la grande macchina.",
               ["Uso il registratore di cassa e la macchina ogni mattina."], [], nil),
              ("pt", "Crio aplicativos para lojas, usando o IDE para escrever código e o SQL para buscar informações.",
               ["Utilizo o IDE para desenvolver código e o SQL para consultar bancos de dados."], [["ide"], ["sql"]], "Crio aplicativos para lojas."),
              ("pt", "Crio aplicativos para lojas, usando o IDE para escrever código e o SQL para buscar informações.",
               ["Utilizo o IDE para desenvolver código e o SQL para consultar bancos de dados."], [], nil),
              ("pt", "Crio aplicativos para lojas, usando o IDE para escrever código e o SQL para buscar informações.",
               ["Utilizo o Eclipse para desenvolver código."], [["ide"], ["sql"]], nil),
          ] as [(String, String, [String], [[String]], String?)])
    func repeatedTailRound16(language: String, sentence: String, earlier: [String], tools: [[String]], kept: String?) {
        let tail = CVDataSanitizer.withoutARepeatedTail(
            of: sentence, earlier: earlier, besides: [], tools: tools, language: Vocabulary.Language(rawValue: language)
        )

        #expect(tail == kept)
    }

    @Test("A first word in the imperfect of a verb in \"-ar\" speaks as the person in a rich draft, and not in a plain one (probe round 16)",
          arguments: [
              ("pt", "contabilista", "Móveis Cávado",
               "Moro em Braga. Desde 2017 trabalho como contabilista na Móveis Cávado, onde faço a contabilidade e analiso os movimentos de caixa.",
               "Organizava os arquivos das faturas de cada cliente."),
              ("es", "contable", "Muebles Albarracín",
               "Vivo en Teruel. Desde 2017 trabajo como contable en Muebles Albarracín, donde llevo la contabilidad y reviso las facturas.",
               "Gestionaba los pedidos de los clientes cada semana."),
          ] as [(String, String, String, String, String)])
    func imperfectOfThePerson(language: String, title: String, company: String, description: String, sentence: String) throws {
        let checker = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Experience(title: title, company: company, startDate: "2017", endDate: nil, current: true)])

        let verdict = try checker.summaryCheck(of: facts, summary: sentence, field: nil, against: description)

        #expect(!verdict.rejected.map(\.reason).contains(CVDataSanitizer.hasNoVerbOfThePerson), "\(verdict.rejected)")
        // A plain draft keeps the rule as it was: no verb of the person.
        DraftDepth.$pinned.withValue(false) {
            let plain = try? checker.summaryCheck(of: facts, summary: sentence, field: nil, against: description)
            #expect(plain?.rejected.map(\.reason).contains(CVDataSanitizer.hasNoVerbOfThePerson) == true, "\(plain?.rejected ?? [])")
        }
    }

    @Test("A rich summary keeps the head of a sentence whose closing phrase holds a name, and a plain one drops it (probe round 16)")
    func headBeforeAName() throws {
        let portuguese = CVDataSanitizer(languageOfText: { _ in "pt" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Experience(title: "programador", company: "Lojas Minho", startDate: "2017", endDate: nil, current: true)])
        let description = "Moro em Braga. Desde 2017 trabalho como programador na Lojas Minho, onde crio interfaces para os clientes e automatizo tarefas."
        let sentence = "Crio interfaces para os clientes e automatizo tarefas repetitivas com código usando o Visual Studio Code."
        let head = "Crio interfaces para os clientes e automatizo tarefas repetitivas com código."

        let verdict = try portuguese.summaryCheck(of: facts, summary: sentence, field: nil, against: description)

        #expect(verdict.kept.contains(head), "\(verdict.kept) \(verdict.rejected)")
        DraftDepth.$pinned.withValue(false) {
            let plain = try? portuguese.summaryCheck(of: facts, summary: sentence, field: nil, against: description)
            #expect(plain?.kept.contains { $0.hasPrefix("Crio") } == false, "\(plain?.kept ?? [])")
            #expect(plain?.rejected.contains { $0.sentence == sentence && $0.reason.contains("reads as a name") } == true, "\(plain?.rejected ?? [])")
        }
    }

    @Test("A rich summary keeps an acronym the person's work writes, and a plain one reads it as a name (probe round 16)")
    func acronymOfTheWork() throws {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Experience(title: "sound technician", company: "Teatro Lario", startDate: "2017", endDate: nil, current: true)])
        let description = "I live in Como. Since 2017 I work as a sound technician at Teatro Lario, where I set up the sound for the concerts."
        let sentence = "I manage the PA systems of the theatre for every show."
        let work = ["I was setting up the PA systems for the concerts."]

        let verdict = try english.summaryCheck(of: facts, summary: sentence, field: nil, work: work, against: description)

        #expect(verdict.kept.contains(sentence), "\(verdict.kept) \(verdict.rejected)")
        DraftDepth.$pinned.withValue(false) {
            let plain = try? english.summaryCheck(of: facts, summary: sentence, field: nil, work: work, against: description)
            #expect(plain?.rejected.contains { $0.sentence == sentence && $0.reason == "the word \"PA\" reads as a name" } == true, "\(plain?.rejected ?? [])")
        }
    }

    // MARK: probe round 17

    @Test("A rich draft asks the tools a job ad of the title asks, by the names of the trade, and no person or role; a plain one keeps its request (probe round 17)")
    func toolsOfAJobAd() {
        let rich = SectionPrompts.toolsInstructions(count: 4...5)

        #expect(rich.contains("4 or 5 software, equipment, machines or instruments that a job ad for the job's title asks a candidate to use"))
        #expect(rich.contains("equipment by the words that tell it from what a home or any office has"))
        #expect(rich.contains("an activity, task or field of the work"))
        #expect(rich.contains("a person or a role"))
        DraftDepth.$pinned.withValue(false) {
            let plain = SectionPrompts.toolsInstructions(count: 4...5)
            #expect(!plain.contains("a job ad"))
            #expect(!plain.contains("a person or a role"))
            #expect(plain.contains("that a person with the job's title uses at work, each of another kind, as a CV of that trade names them"))
        }
    }

    @Test("The final pass keeps a rich summary sentence with an acronym of a kept duty, as the summary check does, and a plain one drops it (probe round 17)")
    func acronymOfAKeptDuty() throws {
        let french = CVDataSanitizer(languageOfText: { _ in "fr" })
        let description = """
            J'habite à Rouen. Depuis 2017, je travaille comme technicien du son au Théâtre Lario, où je règle les systèmes PA des \
            concerts.
            """
        let cv = CVData(experience: [Experience(title: "technicien du son", company: "Théâtre Lario", startDate: "2017", current: true)])
        let summary = "Je gère les systèmes PA du théâtre pour chaque spectacle."
        let writing = DraftWriting(
            summary: summary, roleDescriptions: ["Je règle les systèmes PA des concerts."], technologies: [], softSkills: []
        )

        let draft = try french.sanitize(cv, writing: writing, against: description)

        #expect(draft.experience.first?.description?.contains("PA") == true, "\(draft.experience)")
        #expect(draft.summary == summary)
        let plain = try DraftDepth.$pinned.withValue(false) { try french.sanitize(cv, writing: writing, against: description) }
        #expect(plain.summary?.contains("PA") != true, "\(plain.summary ?? "")")
    }

    // MARK: The summary's request

    @Test("A summary sentence's request reads the tools of its slot and the first verbs said, and its rules ask for the tools by name and for concrete work")
    func summarySentencePrompt() {
        let topic = SummaryTopic(title: "head of sound", tools: ["Pro Tools", "DiGiCo SD7"], hasEnded: false)
        let written = ["I work as head of sound.", "I train the junior technicians.", "I work through every show calmly."]

        let prompt = SectionPrompts.summarySentence(for: Self.brief, topic: topic, written: written)

        #expect(prompt.text == """
            Language: English
            Write in English.
            Job: head of sound; write in the present
            Tools: Pro Tools; DiGiCo SD7
            Summary so far:
            - I work as head of sound.
            - I train the junior technicians.
            - I work through every show calmly.
            Do not start with: work; train
            """)
        for instructions in [SectionPrompts.summarySentenceInstructions, SectionPrompts.summarySentenceRepairInstructions] {
            #expect(instructions.contains(
                "with tools, say what the person does with one or two of them, by name, each for the work it is made for"
            ))
            #expect(instructions.contains("Name a tool only when a Tools line is given."))
            #expect(instructions.contains(
                "concrete: no bare \"tools\", \"software\", \"systems\", \"equipment\", \"techniques\" or \"methods\""
            ))
            #expect(instructions.contains("Typical duties of the job are fine, in your own words"))
            #expect(instructions.contains("never guarantee a result"))
        }
        // iOS 26's model keeps the plain request: no list of verbs, no rule on the tools.
        DraftDepth.$pinned.withValue(false) {
            #expect(!SectionPrompts.summarySentence(for: Self.brief, topic: topic, written: written).text.contains("Do not start with:"))
            #expect(!SectionPrompts.summarySentenceInstructions.contains("by name"))
            #expect(SectionPrompts.summarySentenceInstructions.contains("Typical duties and tools of the job are fine, in your own words."))
        }
    }
}

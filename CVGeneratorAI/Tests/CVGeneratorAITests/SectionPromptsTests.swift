import Testing
@testable import CVGeneratorAI

/// The prompts of a draft written a section at a time (ADR 0031, "A request per section"): a request per job that reads the job's own
/// clauses, a request for the tools of each job and one for the soft skills, then the summary from what the checks kept, and the
/// repairs that read what a check rejected and why. Every name, trade and date is invented.
@Suite("The prompts of a draft written a section at a time (ADR 0031)")
struct SectionPromptsTests {
    private static let brief: DraftBrief = {
        var brief = DraftBrief(
            language: "Italian", headline: nil,
            roles: [
                .init(
                    title: "manutentore elettromeccanico", employer: "Pastificio Cerreto", hasEnded: true,
                    clauses: ["poi ho fatto il manutentore elettromeccanico al Pastificio Cerreto dal 2014 al 2018", "controllando i quadri elettrici"]
                ),
                .init(title: "capoturno della manutenzione", employer: "Birrificio Valtrigno", hasEnded: false, clauses: ["dove coordino tre tecnici"]),
            ],
            studies: ["Perito elettrotecnico"], namedSkills: ["PLC"]
        )
        brief.roles[0].avoid = ["Valtrigno", "capoturno"]
        return brief
    }()

    // MARK: A job

    @Test("A job's request reads its title, employer and end, its own clauses as sentences and the words to avoid, and no other job")
    func jobPrompt() {
        let prompt = SectionPrompts.job(number: 0, of: Self.brief)

        #expect(prompt.instructions == SectionPrompts.jobInstructions)
        #expect(prompt.text == """
            Language: Italian
            Scrivi in italiano.
            Job: manutentore elettromeccanico; employer: Pastificio Cerreto; ended
            What the person said about this job:
            - Poi ho fatto il manutentore elettromeccanico al Pastificio Cerreto dal 2014 al 2018.
            - Controllando i quadri elettrici.
            Words to avoid: Valtrigno, capoturno
            Write exactly 3 duties: first the duties the person said above, then typical ones of this job.
            """)
        #expect(!prompt.text.contains("tre tecnici"))
    }

    @Test("o1: a job's request asks for exactly the typical duties the job needs after the person's, to reach three (#354, rounds 10 and 13)",
          arguments: [
              (4, 0, "Write only the duties the person said, and add none."),
              (1, 2, "Write exactly 2 more duties typical of this job, after the duty the person said."),
              (3, 1, "Write exactly 1 more duty typical of this job, after the duties the person said."),
              (0, 3, "Write exactly 3 duties: first the duties the person said above, then typical ones of this job."),
          ])
    func jobAsksForTheDutiesItNeeds(said: Int, adding: Int, line: String) {
        var brief = Self.brief
        brief.roles[0].said = said
        brief.roles[0].adding = adding

        let text = SectionPrompts.job(number: 0, of: brief).text

        #expect(text.hasSuffix("\n" + line))
        #expect(SectionPrompts.jobInstructions.contains("then exactly as many more as the request asks"))
        #expect(SectionPrompts.jobInstructions.contains("a concrete task of that trade, never one that fits any job"))
        #expect(!SectionPrompts.jobInstructions.contains("2 to 4"))
    }

    @Test("A job whose clauses pin no duty asks first for what the person said, and only a job that said nothing asks for typical duties alone (#354, round 10)")
    func jobWithClausesThatPinNoDuty() {
        let said = DraftBrief(
            language: "French", headline: nil,
            roles: [.init(title: "boulangère", employer: "Fournil Delaunay", hasEnded: false, clauses: ["je pétris le pain au Fournil Delaunay depuis 2019"])],
            studies: [], namedSkills: []
        )
        let silent = DraftBrief(
            language: "French", headline: nil, roles: [.init(title: "boulangère", employer: "Fournil Delaunay", hasEnded: false)],
            studies: [], namedSkills: []
        )

        #expect(SectionPrompts.job(number: 0, of: said).text.hasSuffix(
            "\nWrite exactly 3 duties: first the duties the person said above, then typical ones of this job."
        ))
        #expect(SectionPrompts.job(number: 0, of: silent).text.hasSuffix("\nWrite exactly 3 duties typical of this job."))
    }

    @Test("A job whose clauses only say where the person worked asks for typical duties alone: asked for what the person said first, the model wrote that they worked there (#354, round 11)")
    func jobWithClausesThatNameNoWork() {
        var brief = DraftBrief(
            language: "Italian", headline: nil,
            roles: [.init(
                title: "", employer: "Studio Contabile Merlini", hasEnded: true,
                clauses: ["Prima, dal 2013 al 2017, ho lavorato allo Studio Contabile Merlini."]
            )],
            studies: [], namedSkills: []
        )
        brief.roles[0].clausesNameWork = false

        #expect(SectionPrompts.job(number: 0, of: brief).text.hasSuffix("\nWrite exactly 3 duties typical of this job."))
    }

    @Test("A job's request reads its employer masked, and a name of its own masked in its clauses: the duties of an accountant at a haulier were about transport (#354, round 11)")
    func jobWithItsEmployerMasked() {
        var brief = DraftBrief(
            language: "Spanish", headline: nil,
            roles: [.init(
                title: "contable", employer: "Transportes Ebro Norte", hasEnded: false,
                clauses: ["Desde 2018 trabajo en Transportes Ebro Norte, donde llevo la contabilidad de la empresa"]
            )],
            studies: [], namedSkills: []
        )
        brief.names = ["Transportes Ebro Norte", "gestoría Aranda y Molina", "Universidad del Moncayo", "Diego Salcedo"]

        let text = SectionPrompts.job(number: 0, of: brief).text

        #expect(!text.contains("Transportes") && !text.contains("Ebro"))
        #expect(text.split(separator: "\n").contains("Job: contable; employer: la empresa"))
        #expect(text.contains("- Desde 2018 trabajo en la empresa, donde llevo la contabilidad de la empresa."))
        #expect(SectionPrompts.jobInstructions.contains("typical of its title, each"))
        #expect(!SectionPrompts.jobInstructions.contains("employer"))
    }

    @Test("A job's clauses keep an employer whose name opens with a word of the trade, as the person said it (#354, round 11)")
    func jobWithAnEmployerOfTheTrade() {
        var brief = DraftBrief(
            language: "French", headline: nil,
            roles: [
                .init(
                    title: "institutrice", employer: "école Don Milani", hasEnded: false,
                    clauses: ["Depuis 2016, j'enseigne à l'école Don Milani, où j'ai formé 3 nouveaux enseignants"]
                ),
                .init(
                    title: "assistante", employer: "crèche", hasEnded: true,
                    clauses: ["Avant, de 2012 à 2016, j'ai travaillé comme assistante dans une crèche"]
                ),
            ],
            studies: [], namedSkills: []
        )
        brief.names = ["école Don Milani", "crèche", "université de Bologne", "Maria Rossi"]

        let first = SectionPrompts.job(number: 0, of: brief).text.split(separator: "\n")
        let second = SectionPrompts.job(number: 1, of: brief).text.split(separator: "\n")

        #expect(first.contains("- Depuis 2016, j'enseigne à l'école Don Milani, où j'ai formé 3 nouveaux enseignants."))
        #expect(first.contains("Job: institutrice; employer: l'entreprise"))
        #expect(second.contains("- Avant, de 2012 à 2016, j'ai travaillé comme assistante dans une crèche."))
    }

    @Test("A job with no title is written from the headline title")
    func jobWithNoTitle() {
        let brief = DraftBrief(
            language: "English", headline: "sound technician", roles: [.init(title: "", employer: "Brightwater Events", hasEnded: true)],
            studies: [], namedSkills: []
        )

        let lines = SectionPrompts.job(number: 0, of: brief).text.split(separator: "\n")

        #expect(lines.contains("Headline title: sound technician"))
        #expect(lines.contains("Job: no title given; employer: Brightwater Events; ended"))
    }

    @Test("In the skills requests a job with no title reads the headline title, so its tools are of the person's trade (#354)")
    func skillsOfAJobWithNoTitle() {
        let brief = DraftBrief(
            language: "Portuguese", headline: "programador",
            roles: [
                .init(title: "", employer: "Estúdio Ventania", hasEnded: true, clauses: ["trabalhei no estúdio Ventania"]),
                .init(title: "analista de testes", employer: "Lumen Dados", hasEnded: false),
            ],
            studies: [], namedSkills: []
        )
        let noHeadline = DraftBrief(
            language: "Portuguese", headline: nil, roles: [.init(title: "", employer: "Estúdio Ventania", hasEnded: true)],
            studies: [], namedSkills: []
        )

        for text in [SectionPrompts.softSkills(for: brief).text,
                     SectionPrompts.moreQualities(for: brief, count: 1, listed: [], rejected: []).text] {
            #expect(text.contains("Jobs:\n1. programador; ended"))
            #expect(text.contains("\n2. analista de testes"))
        }
        let titleLine = { (brief: DraftBrief, role: Int) in
            SectionPrompts.tools(for: brief, roles: [role], count: 2...3).text.split(separator: "\n").first { $0.hasPrefix("Job title: ") }
        }
        #expect(titleLine(brief, 0) == "Job title: programador")
        #expect(titleLine(brief, 1) == "Job title: analista de testes")
        #expect(titleLine(noHeadline, 0) == "Job title: no title given")
        #expect(SectionPrompts.job(number: 0, of: brief).text.contains("Job: no title given; employer: Estúdio Ventania; ended"))
    }

    @Test("A job's instructions ask for the years the person said, the whole duties the request asks for and no fact of their own")
    func jobInstructions() {
        let instructions = SectionPrompts.jobInstructions

        #expect(instructions.contains("The years: only those the person said for this job."))
        #expect(instructions.contains("The duties the request asks for, each one whole sentence"))
        #expect(instructions.contains("No number, date, name of a company, place or person."))
        #expect(instructions.contains("Never add a job, study, certification, achievement or result."))
    }

    @Test("o1: a job's repair reads the duties kept, each rejected sentence with its reason, and asks for exactly the duties missing to reach three (#354, round 13)")
    func jobRepair() {
        let prompt = SectionPrompts.jobRepair(
            number: 1, of: Self.brief, kept: ["Coordino tre tecnici."],
            rejected: ["\"Controllavo i quadri.\": it is written in another form: write it in the present, as the person"]
        )

        #expect(prompt.instructions == SectionPrompts.jobRepairInstructions)
        #expect(prompt.text == """
            Language: Italian
            Scrivi in italiano.
            Job: capoturno della manutenzione; employer: Birrificio Valtrigno
            What the person said about this job:
            - Coordino tre tecnici.
            Duties kept:
            - Coordino tre tecnici.
            Sentences rejected, with the reason:
            - "Controllavo i quadri.": it is written in another form: write it in the present, as the person
            Add exactly 2 more duties typical of this job.
            """)
        #expect(SectionPrompts.jobRepairInstructions.contains("Add exactly as many more duties typical of the job as the request asks."))
        let two = SectionPrompts.jobRepair(number: 1, of: Self.brief, kept: ["Coordino tre tecnici.", "Pianifico i turni."], rejected: [])
        #expect(two.text.hasSuffix("\nAdd exactly 1 more duty typical of this job."))
    }

    @Test("o1: a job gets typical duties to reach three, at least one, and none from four duties of its own (#354, round 13)",
          arguments: [(0, 3), (1, 2), (2, 1), (3, 1), (4, 0), (6, 0)])
    func typicalDutiesAJobNeeds(said: Int, adding: Int) {
        #expect(DraftBrief.Role.adding(said: said) == adding)
        #expect(DraftBrief.Role(title: "", hasEnded: false).adding == DraftBrief.Role.leastDuties)
    }

    // MARK: The skills

    @Test("A tools request reads one job: its title, its own lines, what its work is done on as no tool, and the skills the person named (#354, round 6)")
    func toolsPrompt() {
        let prompt = SectionPrompts.tools(for: Self.brief, roles: [0], count: 2...3)

        #expect(prompt.instructions == SectionPrompts.toolsInstructions(count: 2...3))
        #expect(prompt.text == """
            Language: Italian
            Scrivi in italiano.
            Job title: manutentore elettromeccanico
            What the person said about this job:
            - Poi ho fatto il manutentore elettromeccanico al Pastificio Cerreto dal 2014 al 2018.
            - Controllando i quadri elettrici.
            What the work is done on, which is no tool: i quadri elettrici
            Skills already listed: PLC
            """)
        // The "where" that ties a line to its employer is no work.
        #expect(SectionPrompts.tools(for: Self.brief, roles: [1], count: 2...3).text.contains("What the work is done on, which is no tool: tre tecnici\n"))
    }

    @Test("The jobs that share a title ask for their tools once, with the lines of each, each line once (#354, round 6)")
    func toolsOfJobsThatShareATitle() {
        let brief = DraftBrief(
            language: "English", headline: nil,
            roles: [
                .init(title: "sound technician", employer: "Brightwater Events", hasEnded: true, clauses: ["setting up the PA systems"]),
                .init(title: "sound technician", employer: "Copperfield Arena", hasEnded: true, clauses: [
                    "setting up the PA systems", "I was also helping the lighting crew with the follow spots",
                ]),
            ],
            studies: [], namedSkills: []
        )

        let text = SectionPrompts.tools(for: brief, roles: [0, 1], count: 2...3).text

        #expect(text.contains("""
            Job title: sound technician
            What the person said about this job:
            - Setting up the PA systems.
            - I was also helping the lighting crew with the follow spots.
            """))
        // An acronym names a tool or a name: the work is done on the crew, not on the PA systems.
        #expect(text.hasSuffix("What the work is done on, which is no tool: helping the lighting crew with the follow spots"))
    }

    @Test("o1: the tools request defines a tool in a short positive way, a product name too, asks the headline's title 6 to 8 and another title at most 1, and lists no kind of non-tool, which the check drops (#354, round 13)")
    func toolsOfEachJob() {
        let rules = SectionPrompts.toolsInstructions(count: 6...8)

        #expect(rules.contains("You name the tools of one job for a CV: 6 to 8 tools that a person with the job's title works with"))
        #expect(SectionPrompts.toolsInstructions(count: 0...1).contains("You name the tools of one job for a CV: at most 1 tool that"))
        #expect(rules.contains(
            "A tool is software or an app, a device or a machine, or an instrument or a hand tool of the job's trade; a product name is fine."
        ))
        #expect(rules.contains("First the tools the job's own lines name, as written;"))
        #expect(rules.contains("none of the skills already listed"))
        #expect(SectionPrompts.tools(for: Self.brief, roles: [0], count: 6...8).instructions == rules)
        // The long list of what is no tool read as a list of tools to name; the check drops those (#354, round 13).
        #expect(!rules.contains("Not a tool"))
        #expect(!rules.contains("stationery"))
        #expect(!rules.contains("technique"))
        #expect(!SectionPrompts.moreQualitiesInstructions.contains("technique"))
    }

    @Test("The tools request reads the names of the CV as \"the company\", whole or by a word of theirs (#354, round 7)")
    func toolsWithoutNames() {
        var brief = DraftBrief(
            language: "English", headline: nil,
            roles: [.init(title: "warehouse operative", employer: "Kestrel Logistics", hasEnded: false, clauses: [
                "I drive a reach truck at Kestrel Logistics", "I train new Kestrel staff for Dana Whitcombe",
            ])],
            studies: [], namedSkills: []
        )
        brief.own = ["At Kestrel I keep the stock tidy."]
        brief.names = ["Kestrel Logistics", "Dana Whitcombe"]

        let text = SectionPrompts.tools(for: brief, roles: [0], count: 4...5).text

        #expect(!text.contains("Kestrel"), "\(text)")
        #expect(!text.contains("Dana"))
        #expect(!text.contains("Whitcombe"))
        #expect(text.contains("I drive a reach truck at the company."))
        #expect(text.contains("At the company I keep the stock tidy."))
    }

    @Test("The soft skills request lists the jobs, and asks for qualities, never a tool")
    func softSkillsPrompt() {
        let prompt = SectionPrompts.softSkills(for: Self.brief)

        #expect(prompt.instructions == SectionPrompts.softSkillsInstructions)
        #expect(prompt.text.contains("Jobs:\n1. manutentore elettromeccanico; ended"))
        #expect(SectionPrompts.softSkillsInstructions.contains("3 to 5 personal qualities at work"))
        #expect(SectionPrompts.softSkillsInstructions.contains("No tool, no technique, no level."))
    }

    @Test("o1: a request for tools of one kind reads the headline's title, the kind, the tools kept and those dropped with why, and allows none (#354, round 13)")
    func toolsOfAKindPrompt() {
        let prompt = SectionPrompts.toolsOfAKind(
            for: Self.brief, roles: [1], kind: .device, listed: ["PLC"], rejected: ["\"manutenzione preventiva\": an activity, not a tool"]
        )

        #expect(prompt.instructions == SectionPrompts.toolsOfAKindInstructions)
        #expect(prompt.text == """
            Language: Italian
            Scrivi in italiano.
            Job title: capoturno della manutenzione
            Kind: devices or machines
            Tools listed, do not repeat: PLC
            Rejected, with the reason; write none of them again:
            - "manutenzione preventiva": an activity, not a tool
            """)
        #expect(ToolKind.allCases.map(\.words) == ["software or apps", "devices or machines", "instruments or hand tools"])
        #expect(SectionPrompts.toolsOfAKindInstructions.contains("Name up to 2 tools of the kind given"))
        #expect(SectionPrompts.toolsOfAKindInstructions.contains("None when the trade works with none of that kind."))
        #expect(SectionPrompts.toolsOfAKindInstructions.contains("a product name is fine"))
    }

    @Test("The request for more qualities asks the count given in the CV's language, none of those kept and none of those rejected, with the reason, and no tool (#354, rounds 4 and 13)")
    func moreQualitiesPrompt() {
        let text = SectionPrompts.moreQualities(
            for: Self.brief, count: 2, listed: ["precisione"], rejected: ["\"PLC\": a tool, not a quality"]
        ).text

        // Asked for qualities with no language, the request wrote an Italian CV English ones (#354, round 4).
        #expect(text.contains("Name 2 more personal qualities at work that fit these jobs, as nouns in the language named on the first line."))
        #expect(text.contains("Qualities listed, do not repeat: precisione"))
        #expect(text.contains("Rejected, with the reason; write none of them again:\n- \"PLC\": a tool, not a quality"))
        #expect(!text.contains("Tools listed"))
        #expect(!SectionPrompts.moreQualities(for: Self.brief, count: 1, listed: [], rejected: []).text.contains("Rejected"))
    }

    @Test("The skills requests read what the person says of their work with no job, and put the person's own tools and qualities first (#354, round 1)")
    func ownSentencesInTheSkillsRequests() {
        var brief = Self.brief
        brief.own = ["Leggo gli schemi elettrici e uso i PLC per trovare i guasti.", "Sono preciso e mi piace lavorare in squadra."]
        let said = """
            What the person says of their work, with no job:
            - Leggo gli schemi elettrici e uso i PLC per trovare i guasti.
            - Sono preciso e mi piace lavorare in squadra.
            """

        for text in [SectionPrompts.tools(for: brief, roles: [0], count: 2...3).text, SectionPrompts.softSkills(for: brief).text,
                     SectionPrompts.moreQualities(for: brief, count: 1, listed: [], rejected: []).text] {
            #expect(text.contains(said), "\(text)")
        }
        #expect(!SectionPrompts.tools(for: Self.brief, roles: [0], count: 2...3).text.contains("with no job"))
        #expect(SectionPrompts.toolsInstructions(count: 2...3).contains("then the tools the person names in what they say of their work with no job"))
        #expect(SectionPrompts.softSkillsInstructions.contains("First the qualities the person says of themselves"))
        #expect(SectionPrompts.moreQualitiesInstructions.contains("First those the person says of themselves"))
    }

    @Test("No rule of the skills quotes a word: the model copies a quoted example into drafts of other trades (#354)")
    func skillRulesQuoteNoWord() {
        for instructions in [
            SectionPrompts.toolsInstructions(count: 6...8), SectionPrompts.softSkillsInstructions, SectionPrompts.moreQualitiesInstructions,
            SectionPrompts.toolsOfAKindInstructions,
        ] {
            #expect(!instructions.contains("\""), "\(instructions)")
        }
    }

    // MARK: The summary

    @Test("A summary sentence's request reads the job's title and its tense, past when it ended and present otherwise (a current job's sentence came in the past), its slot (the field, the topics or the qualities) and the summary so far, and no employer (#354, round 13)")
    func summarySentencePrompt() {
        let topic = SummaryTopic(
            title: "capoturno della manutenzione", field: "manutenzione industriale", work: ["i turni", "i quadri elettrici"],
            qualities: ["precisione"], hasEnded: false
        )

        let prompt = SectionPrompts.summarySentence(for: Self.brief, topic: topic, written: ["Lavoro come capoturno della manutenzione."])

        #expect(prompt.instructions == SectionPrompts.summarySentenceInstructions)
        #expect(prompt.text == """
            Language: Italian
            Scrivi in italiano.
            Job: capoturno della manutenzione; write in the present
            Field: manutenzione industriale
            Topics: i turni; i quadri elettrici
            Qualities: precisione
            Summary so far:
            - Lavoro come capoturno della manutenzione.
            """)
        #expect(!prompt.text.contains("Valtrigno"))
        let ended = SummaryTopic(title: "manutentore elettromeccanico", work: ["i quadri elettrici"], hasEnded: true)
        #expect(SectionPrompts.summarySentence(for: Self.brief, topic: ended, written: []).text.hasSuffix("""
            Job: manutentore elettromeccanico; ended, write in the past
            Topics: i quadri elettrici
            """))
        let untitled = SummaryTopic(title: nil, qualities: ["precisione"], hasEnded: false)
        #expect(SectionPrompts.summarySentence(for: Self.brief, topic: untitled, written: []).text.hasSuffix("""
            Job: no title given; write in the present
            Qualities: precisione
            """))
    }

    @Test("A summary sentence's repair reads the request, then the rejected sentence and why it went")
    func summarySentenceRepair() {
        let topic = SummaryTopic(title: "capoturno della manutenzione", work: ["tre tecnici"], hasEnded: false)
        let rejected = "\"Lui coordina tre tecnici.\": it speaks of the person in the third person"

        let prompt = SectionPrompts.summarySentenceRepair(for: Self.brief, topic: topic, written: [], rejected: rejected)

        #expect(prompt.instructions == SectionPrompts.summarySentenceRepairInstructions)
        #expect(prompt.text == SectionPrompts.summarySentence(for: Self.brief, topic: topic, written: []).text
            + "\nRejected, with the reason: " + rejected)
    }

    @Test("A summary sentence is one sentence as the person on its topic alone, with no fact of its own (#354, round 13)")
    func summaryInstructions() {
        for instructions in [SectionPrompts.summarySentenceInstructions, SectionPrompts.summarySentenceRepairInstructions] {
            #expect(instructions.contains("exactly 1 sentence") || instructions.contains("Exactly 1 sentence"))
            #expect(instructions.contains("in the first person, never \"he\", \"she\" or \"the person\""))
            #expect(instructions.contains("in the past when the job ended"))
            #expect(instructions.contains("Do not start with the first verb of a sentence of the summary so far."))
            // O1: typical duties and tools are draft content; facts never are (#354, round 13).
            #expect(instructions.contains("Typical duties and tools of the job are fine, in your own words."))
            #expect(instructions.contains(
                "Never add a number, company, customer, product, school, place, person, language, study, certification or achievement"
            ))
            #expect(instructions.contains("never guarantee a result"))
            // Asked for a quality in each sentence, the summary closed each with the person's own praise (#354, round 10).
            #expect(!instructions.contains("quality of the lists"))
        }
    }

    // MARK: A clause as a sentence

    @Test("A clause reads as a whole sentence: a capital first letter and a full stop, its joining punctuation gone")
    func clauseAsSentence() {
        #expect(SectionPrompts.asSentence(", dove coordino tre tecnici;") == "Dove coordino tre tecnici.")
        #expect(SectionPrompts.asSentence("I train the juniors!") == "I train the juniors!")
        #expect(SectionPrompts.asSentence(" ") == "")
    }

    @Test("A clause a job request reads as a duty also loses the relative word that tied it to the employer (#354, round 12)")
    func clauseAsDuty() {
        #expect(SectionPrompts.asDuty(", dove coordino tre tecnici;") == "Coordino tre tecnici.")
        #expect(SectionPrompts.asDuty("où je range 12 rayons de livres") == "Je range 12 rayons de livres.")
        #expect(SectionPrompts.asDuty("where needed, I mend the nets") == "Where needed, I mend the nets.")
        #expect(SectionPrompts.asDuty("wo ich die Netze flicke") == "Wo ich die Netze flicke.")
        #expect(SectionPrompts.asDuty("I train the juniors!") == "I train the juniors!")
    }

    @Test("The skills requests read a clause as the person said it, its relative word kept: they copy no clause, and the word dropped there changed the tools of three drafts (#354, round 12)")
    func skillsReadTheClauseAsSaid() {
        #expect(SectionPrompts.tools(for: Self.brief, roles: [1], count: 2...3).text.contains("- Dove coordino tre tecnici.\n"))
        #expect(SectionPrompts.softSkills(for: Self.brief).text.contains("Dove coordino tre tecnici."))
    }
}

import Testing
@testable import CVGeneratorAI

/// The prompts of a draft written a section at a time (ADR 0031, "A request per section"): a request per job that reads the job's own
/// clauses, a request for the tools of each job and one for the soft skills, then the summary from what the checks kept, and the
/// repairs that read what a check rejected and why. Every name, trade and date is invented.
@Suite("The prompts of a draft written a section at a time (ADR 0031)", .plainDraft)
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

    @Test("o1: a job's request asks for exactly the typical duties the job needs after the person's, to reach three (#354)",
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

    @Test("A job whose clauses pin no duty asks first for what the person said, and only a job that said nothing asks for typical duties alone (#354)")
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

    @Test("A job whose clauses only say where the person worked asks for typical duties alone: asked for what the person said first, the model wrote that they worked there (#354)")
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

    @Test("A job's request reads its employer masked, and a name of its own masked in its clauses: the duties of an accountant at a haulier were about transport (#354)")
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

    @Test("A job's clauses keep an employer whose name opens with a word of the trade, as the person said it (#354)")
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
                     SectionPrompts.moreSkills(for: brief, title: nil, tools: 1, qualities: 1, listedTools: [], listedQualities: [], rejected: []).text] {
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

    @Test("o1: a job's repair reads the duties kept, each rejected sentence with its reason, and asks for exactly the duties missing to reach three (#354)")
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

    @Test("o1: a job gets typical duties to reach three, at least one, and none from four duties of its own (#354)",
          arguments: [(0, 3), (1, 2), (2, 1), (3, 1), (4, 0), (6, 0)])
    func typicalDutiesAJobNeeds(said: Int, adding: Int) {
        #expect(DraftBrief.Role.adding(said: said) == adding)
        #expect(DraftBrief.Role(title: "", hasEnded: false).adding == DraftBrief.Role.leastDuties)
    }

    // MARK: The skills

    @Test("A tools request reads one job: its title, its own lines, what its work is done on as no tool, and the skills the person named (#354)")
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

    @Test("The jobs that share a title ask for their tools once, with the lines of each, each line once (#354)")
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

    @Test("The tools request puts the equipment of a job's own lines first, asks 2 or 3 for every job, and asks for no activity (#354)")
    func toolsOfEachJob() {
        let rules = SectionPrompts.toolsInstructions(count: 2...3)

        #expect(rules.contains("First the equipment, machines and software the job's own lines name, as written;"))
        #expect(rules.contains("only when they fit the job's title and the tools the person names"))
        // Allowed none, a job with no lines of its own got none, and the next request filled it with roles (#354).
        #expect(!rules.contains("none fits"))
        #expect(rules.contains("Not a tool: what the work is done on; an activity or task, also when written as a noun; a document;"))
        // Asked for pieces of equipment, the request named a pen and a truck load (#354).
        #expect(rules.contains("2 or 3 software, equipment, machines or instruments that a person with the job's title uses at work"))
        // One title asked 2 or 3, and the request for those missing named activities and bare kinds (#354).
        #expect(SectionPrompts.toolsInstructions(count: 4...5).contains("4 or 5 software, equipment, machines or instruments"))
        #expect(SectionPrompts.tools(for: Self.brief, roles: [0], count: 4...5).instructions == SectionPrompts.toolsInstructions(count: 4...5))
        #expect(rules.contains("stationery, furniture or protective wear; an everyday object a person of any trade uses"))
        // Asked for objects only, the request named household objects and rooms ("frigorifero", "classe"); asked for methods and
        // fields of knowledge too, it named fields instead of products: a standard or method counts by its own name.
        #expect(rules.contains("an everyday object a person of any trade uses, a household appliance or a room;"))
        #expect(rules.contains("as a CV of that trade names them; a standard or method of the trade known by its own name counts as one."))
        #expect(!rules.contains("field of knowledge"))
        // A bare kind is no tool; with a word of its trade it is one (#354).
        #expect(rules.contains("A kind of tool with a word of its trade is a tool; a bare kind, with no word of its trade, is not."))
        #expect(!rules.contains("pieces of equipment"))
        #expect(!rules.contains("technique"))
        #expect(!SectionPrompts.moreSkillsInstructions.contains("technique"))
    }

    @Test("The tools request reads the names of the CV as \"the company\", whole or by a word of theirs (#354)")
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

    @Test("The request for more skills asks for the counts given, tools of the trade of the tools listed for the headline title, each new, in the CV's language, none of the skills kept, and none of those rejected, with the reason")
    func moreSkillsPrompt() {
        let both = SectionPrompts.moreSkills(
            for: Self.brief, title: "manutentore elettromeccanico", tools: 2, qualities: 1, listedTools: ["PLC"],
            listedQualities: ["precisione"], rejected: ["\"manutenzione preventiva\": an activity, not a tool"]
        ).text
        let toolsOnly = SectionPrompts.moreSkills(
            for: Self.brief, title: nil, tools: 1, qualities: 0, listedTools: [], listedQualities: [], rejected: []
        ).text

        // Asked for the tools of the jobs, the request wrote the tools of a trade the person left (#354); asked for "named
        // software products, named devices", it wrote devices of any trade ("scanner portable", "Tableta táctil"); asked "each of
        // another kind", it wrote kinds an office has none of ("Termostatos"); asked for methods and fields of
        // knowledge, it wrote fields instead of products: only a standard or method with its own name, after them.
        #expect(both.contains(
            "The CV lists too few tools for a person working as manutentore elettromeccanico: name 2 more tools that a CV of a "
                + "person working as manutentore elettromeccanico typically lists, the most common first: the software, as a kind "
                + "with a word of the trade or a widely used product of the trade of the tools listed, then the equipment, machines "
                + "or instruments, when the trade uses any, then a standard or method of the trade known by its own name; none of "
                + "the tools listed or rejected; each a different tool, not another name of one listed."
        ))
        #expect(toolsOnly.contains(
            "The CV lists too few tools for a person with these jobs: name 1 more tools that a CV of a person with these jobs "
                + "typically lists, the most common first: the software, as a kind with a word of the trade or a widely used product "
                + "of the trade, then the equipment, machines or instruments, when the trade uses any, then a standard or method of "
                + "the trade known by its own name; each a different tool."
        ))
        #expect(!both.contains("of another kind"))
        #expect(!both.contains("named devices"))
        #expect(!both.contains("material"))
        #expect(!both.contains("pieces of equipment"))
        #expect(!SectionPrompts.toolsInstructions(count: 2...3).contains("materials or"))
        // Asked for qualities with no language, the request wrote an Italian CV English ones (#354).
        #expect(both.contains("Name 1 more personal qualities at work that fit these jobs, as nouns in the language named on the first line."))
        #expect(both.contains("Tools listed, do not repeat: PLC"))
        #expect(both.contains("Qualities listed, do not repeat: precisione"))
        #expect(!toolsOnly.contains("personal qualities"))
        #expect(!toolsOnly.contains("listed, do not repeat"))
        #expect(both.contains("Rejected, with the reason; write none of them again:\n- \"manutenzione preventiva\": an activity, not a tool"))
        #expect(!toolsOnly.contains("Rejected"))
    }

    @Test("The skills requests read what the person says of their work with no job, and put the person's own tools and qualities first (#354)")
    func ownSentencesInTheSkillsRequests() {
        var brief = Self.brief
        brief.own = ["Leggo gli schemi elettrici e uso i PLC per trovare i guasti.", "Sono preciso e mi piace lavorare in squadra."]
        let said = """
            What the person says of their work, with no job:
            - Leggo gli schemi elettrici e uso i PLC per trovare i guasti.
            - Sono preciso e mi piace lavorare in squadra.
            """

        for text in [SectionPrompts.tools(for: brief, roles: [0], count: 2...3).text, SectionPrompts.softSkills(for: brief).text,
                     SectionPrompts.moreSkills(for: brief, title: nil, tools: 1, qualities: 1, listedTools: [], listedQualities: [], rejected: []).text] {
            #expect(text.contains(said), "\(text)")
        }
        #expect(!SectionPrompts.tools(for: Self.brief, roles: [0], count: 2...3).text.contains("with no job"))
        #expect(SectionPrompts.toolsInstructions(count: 2...3).contains("then the tools the person names in what they say of their work with no job"))
        #expect(SectionPrompts.softSkillsInstructions.contains("First the qualities the person says of themselves"))
        #expect(SectionPrompts.moreSkillsInstructions.contains("First those the person names"))
    }

    @Test("No rule of the skills quotes a word: the model copies a quoted example into drafts of other trades (#354)")
    func skillRulesQuoteNoWord() {
        for instructions in [SectionPrompts.toolsInstructions(count: 2...3), SectionPrompts.softSkillsInstructions, SectionPrompts.moreSkillsInstructions] {
            #expect(!instructions.contains("\""), "\(instructions)")
        }
    }

    // MARK: The summary

    @Test("A summary sentence's request reads the job's title and its tense, past when it ended and present otherwise (a current job's sentence came in the past), its slot (the field, the topics or the qualities) and the summary so far, and no employer (#354)")
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

    @Test("A summary sentence is one sentence as the person on its topic alone, with no fact of its own (#354)")
    func summaryInstructions() {
        for instructions in [SectionPrompts.summarySentenceInstructions, SectionPrompts.summarySentenceRepairInstructions] {
            #expect(instructions.contains("exactly 1 sentence") || instructions.contains("Exactly 1 sentence"))
            #expect(instructions.contains("in the first person, never \"he\", \"she\" or \"the person\""))
            #expect(instructions.contains("in the past when the job ended"))
            #expect(instructions.contains("Do not start with the first verb of a sentence of the summary so far."))
            // O1: typical duties and tools are draft content; facts never are (#354).
            #expect(instructions.contains("Typical duties and tools of the job are fine, in your own words."))
            #expect(instructions.contains(
                "Never add a number, company, customer, product, school, place, person, language, study, certification or achievement"
            ))
            #expect(instructions.contains("never guarantee a result"))
            // Asked for a quality in each sentence, the summary closed each with the person's own praise (#354).
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

    @Test("A clause a job request reads as a duty also loses the relative word that tied it to the employer (#354)")
    func clauseAsDuty() {
        #expect(SectionPrompts.asDuty(", dove coordino tre tecnici;") == "Coordino tre tecnici.")
        #expect(SectionPrompts.asDuty("où je range 12 rayons de livres") == "Je range 12 rayons de livres.")
        #expect(SectionPrompts.asDuty("where needed, I mend the nets") == "Where needed, I mend the nets.")
        #expect(SectionPrompts.asDuty("wo ich die Netze flicke") == "Wo ich die Netze flicke.")
        #expect(SectionPrompts.asDuty("I train the juniors!") == "I train the juniors!")
    }

    @Test("The skills requests read a clause as the person said it, its relative word kept: they copy no clause, and the word dropped there changed the tools of three drafts (#354)")
    func skillsReadTheClauseAsSaid() {
        #expect(SectionPrompts.tools(for: Self.brief, roles: [1], count: 2...3).text.contains("- Dove coordino tre tecnici.\n"))
        #expect(SectionPrompts.softSkills(for: Self.brief).text.contains("Dove coordino tre tecnici."))
    }
}

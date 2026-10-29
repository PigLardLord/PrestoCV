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
            Write exactly 2 duties typical of this job.
            """)
        #expect(!prompt.text.contains("tre tecnici"))
    }

    @Test("A job's request asks for exactly the typical duties the job needs after the person's: none for a described job, one after one short duty, two for a job with none (#354, rounds 1 and 10)",
          arguments: [
              (1, 0, "Write only the duty the person said, and add none."),
              (2, 0, "Write only the duties the person said, and add none."),
              (1, 1, "Write the duty the person said, then exactly 1 more duty typical of this job."),
              (0, 2, "Write exactly 2 duties typical of this job."),
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
                     SectionPrompts.moreSkills(for: brief, tools: 1, qualities: 1, listedTools: [], listedQualities: [], rejected: []).text] {
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

    @Test("A job's repair reads the duties kept, each rejected sentence with its reason, and asks for one more duty")
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
            - Dove coordino tre tecnici.
            Duties kept:
            - Coordino tre tecnici.
            Sentences rejected, with the reason:
            - "Controllavo i quadri.": it is written in another form: write it in the present, as the person
            Add one more duty typical of this job.
            """)
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

    @Test("The tools request puts the equipment of a job's own lines first, asks 2 or 3 for every job, and asks for no activity (#354, rounds 1 and 5)")
    func toolsOfEachJob() {
        let rules = SectionPrompts.toolsInstructions(count: 2...3)

        #expect(rules.contains("First the equipment, machines and software the job's own lines name, as written;"))
        #expect(rules.contains("only when they fit the job's title and the tools the person names"))
        // Allowed none, a job with no lines of its own got none, and the next request filled it with roles (#354, round 5).
        #expect(!rules.contains("none fits"))
        #expect(rules.contains("Not a tool: what the work is done on; an activity or task, also when written as a noun; a document;"))
        // Asked for pieces of equipment, the request named a pen and a truck load (#354, round 4).
        #expect(rules.contains("2 or 3 software, equipment, machines or instruments that a person with the job's title uses at work"))
        // One title asked 2 or 3, and the request for those missing named activities and bare kinds (#354, round 6).
        #expect(SectionPrompts.toolsInstructions(count: 4...5).contains("4 or 5 software, equipment, machines or instruments"))
        #expect(SectionPrompts.tools(for: Self.brief, roles: [0], count: 4...5).instructions == SectionPrompts.toolsInstructions(count: 4...5))
        #expect(rules.contains("stationery, furniture or protective wear; an everyday object a person of any trade uses"))
        // A bare kind is no tool; with a word of its trade it is one (#354, round 4).
        #expect(rules.contains("A kind of tool with a word of its trade is a tool; a bare kind, with no word of its trade, is not."))
        #expect(!rules.contains("pieces of equipment"))
        #expect(!rules.contains("technique"))
        #expect(!SectionPrompts.moreSkillsInstructions.contains("technique"))
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

    @Test("The request for more skills asks for the counts given, of the trade of the tools kept or of the jobs, in the CV's language, none of the skills kept, and none of those rejected, with the reason")
    func moreSkillsPrompt() {
        let both = SectionPrompts.moreSkills(
            for: Self.brief, tools: 2, qualities: 1, listedTools: ["PLC"], listedQualities: ["precisione"],
            rejected: ["\"manutenzione preventiva\": an activity, not a tool"]
        ).text
        let toolsOnly = SectionPrompts.moreSkills(for: Self.brief, tools: 1, qualities: 0, listedTools: [], listedQualities: [], rejected: []).text

        // With every tool of the jobs dropped, "of the trade of those listed" named no trade, and the request wrote a programmer a
        // codec and a sensor (#354, round 4).
        #expect(both.contains(
            "The CV lists too few tools for its trade: name 2 more software, systems, machines or instruments of the trade of the "
                + "tools listed, that a person with these jobs uses, each of another kind than those listed."
        ))
        #expect(toolsOnly.contains(
            "The CV lists too few tools for its trade: name 1 more software, systems, machines or instruments of the trade of the "
                + "jobs above, that a person with these jobs uses, each of another kind."
        ))
        #expect(!both.contains("material"))
        #expect(!both.contains("pieces of equipment"))
        #expect(!SectionPrompts.toolsInstructions(count: 2...3).contains("materials or"))
        // Asked for qualities with no language, the request wrote an Italian CV English ones (#354, round 4).
        #expect(both.contains("Name 1 more personal qualities at work that fit these jobs, as nouns in the language named on the first line."))
        #expect(both.contains("Tools listed, do not repeat: PLC"))
        #expect(both.contains("Qualities listed, do not repeat: precisione"))
        #expect(!toolsOnly.contains("personal qualities"))
        #expect(!toolsOnly.contains("listed, do not repeat"))
        #expect(both.contains("Rejected, with the reason; write none of them again:\n- \"manutenzione preventiva\": an activity, not a tool"))
        #expect(!toolsOnly.contains("Rejected"))
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
                     SectionPrompts.moreSkills(for: brief, tools: 1, qualities: 1, listedTools: [], listedQualities: [], rejected: []).text] {
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

    @Test("The summary request reads the opening code wrote, each job's title and its work one topic a line, the studies, the kept tools and qualities, and no employer (#354, round 3)")
    func summaryPrompt() {
        var brief = Self.brief
        brief.roles[1].work = ["i turni dei tecnici", "le linee di imbottigliamento"]
        brief.opening = "Lavoro come capoturno della manutenzione."

        let prompt = SectionPrompts.summary(for: brief, tools: ["PLC", "inverter"], qualities: ["precisione"])

        #expect(prompt.instructions == SectionPrompts.summaryInstructions)
        #expect(prompt.text == """
            Language: Italian
            Scrivi in italiano.
            Roles:
            - manutentore elettromeccanico; ended
            - capoturno della manutenzione, work:
              - i turni dei tecnici
              - le linee di imbottigliamento
            Studies: Perito elettrotecnico
            Tools: PLC; inverter
            Qualities: precisione
            Opening, already written: Lavoro come capoturno della manutenzione.
            """)
        #expect(!prompt.text.contains("Cerreto"))
        #expect(SectionPrompts.summary(for: Self.brief, tools: [], qualities: []).text.hasSuffix("Studies: Perito elettrotecnico"))
    }

    @Test("The summary repair reads the summary request, the sentences kept, those rejected with their reasons and what it misses")
    func summaryRepair() {
        let prompt = SectionPrompts.summaryRepair(
            for: Self.brief, tools: [], qualities: [], kept: ["Lavoro come capoturno della manutenzione."],
            rejected: ["\"Lui è un tecnico.\": it speaks of the person in the third person"], problems: ["it is shorter than 120 characters"]
        )

        #expect(prompt.instructions == SectionPrompts.summaryRepairInstructions)
        #expect(prompt.text.hasPrefix(SectionPrompts.summary(for: Self.brief, tools: [], qualities: []).text))
        #expect(prompt.text.hasSuffix("""
            Summary sentences kept:
            - Lavoro come capoturno della manutenzione.
            Summary sentences rejected, with the reason:
            - "Lui è un tecnico.": it speaks of the person in the third person
            What the summary misses: it is shorter than 120 characters
            """))
    }

    @Test("The summary is written as the person, 2 to 3 sentences of at least 120 characters, with no fact of its own")
    func summaryInstructions() {
        for instructions in [SectionPrompts.summaryInstructions, SectionPrompts.summaryRepairInstructions] {
            #expect(instructions.contains("2 to 3 sentences, at least 120 characters in all"))
            #expect(instructions.contains("write as the person, never \"he\", \"she\" or \"the person\""))
            #expect(instructions.contains("No number, date, company, school, place or person's name"))
            #expect(instructions.contains("Never add a language, job, study, certification, hobby, achievement or result."))
            #expect(instructions.contains("after the opening, which is written"))
            #expect(instructions.contains("no list of tools or qualities"))
        }
    }

    // MARK: A clause as a sentence

    @Test("A clause reads as a whole sentence: a capital first letter and a full stop, its joining punctuation gone")
    func clauseAsSentence() {
        #expect(SectionPrompts.asSentence(", dove coordino tre tecnici;") == "Dove coordino tre tecnici.")
        #expect(SectionPrompts.asSentence("I train the juniors!") == "I train the juniors!")
        #expect(SectionPrompts.asSentence(" ") == "")
    }
}

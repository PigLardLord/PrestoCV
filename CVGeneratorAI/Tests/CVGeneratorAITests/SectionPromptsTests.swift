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
            """)
        #expect(!prompt.text.contains("tre tecnici"))
    }

    @Test("d6: a job whose stated duties run to 40 characters asks for no typical duty; the instructions ask for typical duties only otherwise, and none vague (#354, round 1)")
    func describedJobAsksForNoTypicalDuty() {
        var brief = Self.brief
        brief.roles[0].described = true

        let described = SectionPrompts.job(number: 0, of: brief).text
        let short = SectionPrompts.job(number: 0, of: Self.brief).text

        #expect(described.contains("\nThe person said enough of this job: write only the duties they said, and add none."))
        #expect(!short.contains("add none"))
        #expect(SectionPrompts.jobInstructions.contains("unless the request says to add none"))
        #expect(SectionPrompts.jobInstructions.contains("a concrete task of that trade, never one that fits any job"))
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

        for text in [SectionPrompts.tools(for: brief).text, SectionPrompts.softSkills(for: brief).text,
                     SectionPrompts.moreSkills(for: brief, tools: 1, qualities: 1, excluding: [], rejected: []).text] {
            #expect(text.contains("Jobs:\n1. programador; ended"))
            #expect(text.contains("\n2. analista de testes"))
        }
        #expect(SectionPrompts.tools(for: noHeadline).text.contains("1. no title given; ended"))
        #expect(SectionPrompts.job(number: 0, of: brief).text.contains("Job: no title given; employer: Estúdio Ventania; ended"))
    }

    @Test("A job's instructions ask for the years the person said, 2 to 4 whole duties and no fact of their own")
    func jobInstructions() {
        let instructions = SectionPrompts.jobInstructions

        #expect(instructions.contains("The years: only those the person said for this job."))
        #expect(instructions.contains("2 to 4 duties, each one whole sentence"))
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

    @Test("The tools request lists each job in order, with its clauses, and the skills the person named")
    func toolsPrompt() {
        let prompt = SectionPrompts.tools(for: Self.brief)

        #expect(prompt.instructions == SectionPrompts.toolsInstructions)
        #expect(prompt.text == """
            Language: Italian
            Scrivi in italiano.
            Jobs:
            1. manutentore elettromeccanico; ended
               Poi ho fatto il manutentore elettromeccanico al Pastificio Cerreto dal 2014 al 2018. Controllando i quadri elettrici.
            2. capoturno della manutenzione
               Dove coordino tre tecnici.
            Skills already listed: PLC
            """)
    }

    @Test("The tools request puts the equipment of a job's own lines first, allows none for a job, and asks for no activity (#354, round 1)")
    func toolsOfEachJob() {
        let rules = SectionPrompts.toolsInstructions

        #expect(rules.contains("First the equipment, machines and software the job's own lines name, as written;"))
        #expect(rules.contains("only when they fit the job's title and the tools the person names"))
        #expect(rules.contains("Name none for a job when none fits."))
        #expect(rules.contains("no activity or task, also when written as a noun"))
        #expect(!rules.contains("technique"))
        #expect(!SectionPrompts.moreSkillsInstructions.contains("technique"))
    }

    @Test("The soft skills request lists the jobs, and asks for qualities, never a tool")
    func softSkillsPrompt() {
        let prompt = SectionPrompts.softSkills(for: Self.brief)

        #expect(prompt.instructions == SectionPrompts.softSkillsInstructions)
        #expect(prompt.text.contains("Jobs:\n1. manutentore elettromeccanico; ended"))
        #expect(SectionPrompts.softSkillsInstructions.contains("3 to 5 personal qualities at work"))
        #expect(SectionPrompts.softSkillsInstructions.contains("No tool, no technique, no level."))
    }

    @Test("The request for more skills asks for the counts given, none of the skills kept, and none of those rejected, with the reason")
    func moreSkillsPrompt() {
        let both = SectionPrompts.moreSkills(
            for: Self.brief, tools: 2, qualities: 1, excluding: ["PLC", "precisione"],
            rejected: ["\"manutenzione preventiva\": an activity, not a tool"]
        ).text
        let toolsOnly = SectionPrompts.moreSkills(for: Self.brief, tools: 1, qualities: 0, excluding: [], rejected: []).text

        #expect(both.contains(
            "The CV lists too few tools for its trade: name 2 more pieces of equipment, machines or software that a person with these "
                + "job titles uses, of the trade of those listed, each of another kind than those listed."
        ))
        #expect(!both.contains("material"))
        #expect(!SectionPrompts.toolsInstructions.contains("materials or"))
        #expect(both.contains("Name 1 more personal qualities at work."))
        #expect(both.contains("Already listed, do not repeat: PLC; precisione"))
        #expect(!toolsOnly.contains("personal qualities"))
        #expect(!toolsOnly.contains("Already listed"))
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

        for text in [SectionPrompts.tools(for: brief).text, SectionPrompts.softSkills(for: brief).text,
                     SectionPrompts.moreSkills(for: brief, tools: 1, qualities: 1, excluding: [], rejected: []).text] {
            #expect(text.contains(said), "\(text)")
        }
        #expect(!SectionPrompts.tools(for: Self.brief).text.contains("with no job"))
        #expect(SectionPrompts.toolsInstructions.contains("then the tools the person names in what they say of their work with no job"))
        #expect(SectionPrompts.softSkillsInstructions.contains("First the qualities the person says of themselves"))
        #expect(SectionPrompts.moreSkillsInstructions.contains("First those the person names"))
    }

    @Test("No rule of the skills quotes a word: the model copies a quoted example into drafts of other trades (#354)")
    func skillRulesQuoteNoWord() {
        for instructions in [SectionPrompts.toolsInstructions, SectionPrompts.softSkillsInstructions, SectionPrompts.moreSkillsInstructions] {
            #expect(!instructions.contains("\""), "\(instructions)")
        }
    }

    // MARK: The summary

    @Test("The summary request reads the opening code wrote, each job's title and work, the studies, the kept tools and qualities, and no employer (#354, round 3)")
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
            - capoturno della manutenzione
              work: i turni dei tecnici; le linee di imbottigliamento
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

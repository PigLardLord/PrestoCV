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
                     SectionPrompts.moreSkills(for: brief, tools: 1, qualities: 1, excluding: []).text] {
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

    @Test("The soft skills request lists the jobs, and asks for qualities, never a tool")
    func softSkillsPrompt() {
        let prompt = SectionPrompts.softSkills(for: Self.brief)

        #expect(prompt.instructions == SectionPrompts.softSkillsInstructions)
        #expect(prompt.text.contains("Jobs:\n1. manutentore elettromeccanico; ended"))
        #expect(SectionPrompts.softSkillsInstructions.contains("3 to 5 personal qualities at work"))
        #expect(SectionPrompts.softSkillsInstructions.contains("No tool, no technique, no level."))
    }

    @Test("The request for more skills asks for the counts missing, and none of the skills kept")
    func moreSkillsPrompt() {
        let both = SectionPrompts.moreSkills(for: Self.brief, tools: 2, qualities: 1, excluding: ["PLC", "precisione"]).text
        let toolsOnly = SectionPrompts.moreSkills(for: Self.brief, tools: 1, qualities: 0, excluding: []).text

        #expect(both.contains("Name 2 more tools, machines, software or techniques of the trade, each of another kind than those listed."))
        #expect(!both.contains("material"))
        #expect(!SectionPrompts.toolsInstructions.contains("materials or"))
        #expect(both.contains("Name 1 more personal qualities at work."))
        #expect(both.contains("Already listed, do not repeat: PLC; precisione"))
        #expect(!toolsOnly.contains("personal qualities"))
        #expect(!toolsOnly.contains("Already listed"))
    }

    @Test("No rule of the skills quotes a word: the model copies a quoted example into drafts of other trades (#354)")
    func skillRulesQuoteNoWord() {
        for instructions in [SectionPrompts.toolsInstructions, SectionPrompts.softSkillsInstructions, SectionPrompts.moreSkillsInstructions] {
            #expect(!instructions.contains("\""), "\(instructions)")
        }
    }

    // MARK: The summary

    @Test("The summary request reads each job with its kept duties, without its employer, the studies and the kept skills")
    func summaryPrompt() {
        let prompt = SectionPrompts.summary(for: Self.brief, duties: ["Controllavo i quadri elettrici.", nil], skills: ["PLC", "precisione"])

        #expect(prompt.instructions == SectionPrompts.summaryInstructions)
        #expect(prompt.text == """
            Language: Italian
            Scrivi in italiano.
            Roles:
            - manutentore elettromeccanico; ended
              Controllavo i quadri elettrici.
            - capoturno della manutenzione
            Studies: Perito elettrotecnico
            Skills: PLC; precisione
            """)
        #expect(!prompt.text.contains("Cerreto"))
    }

    @Test("The summary repair reads the summary request, the sentences kept, those rejected with their reasons and what it misses")
    func summaryRepair() {
        let prompt = SectionPrompts.summaryRepair(
            for: Self.brief, duties: [nil, nil], skills: [], kept: ["Lavoro come capoturno della manutenzione."],
            rejected: ["\"Lui è un tecnico.\": it speaks of the person in the third person"], problems: ["it is shorter than 120 characters"]
        )

        #expect(prompt.instructions == SectionPrompts.summaryRepairInstructions)
        #expect(prompt.text.hasPrefix(SectionPrompts.summary(for: Self.brief, duties: [nil, nil], skills: []).text))
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

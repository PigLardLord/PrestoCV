import Testing
@testable import CVGeneratorAI

/// The checks of a draft written a section at a time (ADR 0031, "A request per section"): each job's duties, the skills and the
/// summary are read sentence by sentence, as the final check reads them, with the reason a repair request reads for each sentence
/// that goes. The descriptions are Italian, and their language is given, so the checks read the same on every platform; every name,
/// trade and date is invented.
@Suite("The checks of a draft written a section at a time (ADR 0031)")
struct SectionChecksTests {
    private let sanitizer = Self.italian(ForcedLexicalTagger([:]), wordList: TableWordList())

    /// A sanitizer that reads every text as Italian: without it, the language of a description is the device's guess, which some
    /// platforms do not make.
    private static func italian(_ tagger: ForcedLexicalTagger, wordList: any WordList) -> CVDataSanitizer {
        CVDataSanitizer(languageOfText: { _ in "it" }, lexicalClasses: tagger, wordList: wordList)
    }

    private static func job(_ title: String, _ company: String, from start: String, to end: String? = nil) -> Experience {
        Experience(title: title, company: company, startDate: start, endDate: end, current: end == nil)
    }

    private static let italianJobs = CVData(experience: [
        job("operaio manutentore", "Conserve Albarella", from: "2010", to: "2014"),
        job("manutentore elettromeccanico", "Pastificio Cerreto", from: "2014", to: "2018"),
        job("manutentore elettromeccanico", "Molino Fontebasso", from: "2018", to: "2020"),
        job("capoturno della manutenzione", "Birrificio Valtrigno", from: "2020"),
    ])

    // MARK: The form of a duty

    @Test("A duty's form is the way it starts: I, a verb in -ing or another verb in English; the first person, a gerund or an infinitive in Italian")
    func formOfADuty() {
        #expect(CVDataSanitizer.form("I plan the menus.", language: .english) == .withI)
        #expect(CVDataSanitizer.form("Planning the menus.", language: .english) == .ing)
        #expect(CVDataSanitizer.form("Plans the menus.", language: .english) == .verb)
        #expect(CVDataSanitizer.form("Controllavo i quadri.", language: .italian) == .firstPerson)
        #expect(CVDataSanitizer.form("Controllando i quadri.", language: .italian) == .gerund)
        #expect(CVDataSanitizer.form("Controllare i quadri.", language: .italian) == .infinitive)
        #expect(CVDataSanitizer.form("Ich plane die Menüs.", language: .german) == nil)
    }

    // MARK: The duties of a job

    @Test("A job's written duties keep the duties the person said in front, and drop a repeat, another job's name, another form and a fragment, each with its reason")
    func dutiesOfAJob() throws {
        let written = """
            Controllavo i quadri elettrici. Coordinavo i turni al Birrificio Valtrigno. Eseguivo la lubrificazione dei macchinari. \
            Sostituire i cuscinetti usurati. Riparavo i motori e
            """

        let verdicts = try sanitizer.dutyCheck(of: Self.italianJobs, job: 1, duties: written, against: JobClausesTests.italian)

        #expect(verdicts.pinned == ["Controllavo i quadri elettrici e programmavo la manutenzione preventiva."])
        #expect(verdicts.kept == ["Eseguivo la lubrificazione dei macchinari."])
        let reasons = Dictionary(uniqueKeysWithValues: verdicts.rejected.map { ($0.sentence, $0.reason) })
        #expect(reasons["Controllavo i quadri elettrici."] == "it repeats a duty already written")
        #expect(reasons["Coordinavo i turni al Birrificio Valtrigno."] != nil)
        #expect(reasons["Sostituire i cuscinetti usurati."]?.hasPrefix("it is written in another form") == true)
        #expect(reasons["Riparavo i motori e"] == "it is not a whole sentence")
        #expect(verdicts.avoid.contains("Valtrigno") || verdicts.avoid.contains("valtrigno"))
    }

    @Test("A repair's duties are checked against the duties kept before it, and the duties of a job past the draft's are none")
    func repairAgainstEarlier() throws {
        let verdicts = try sanitizer.dutyCheck(
            of: Self.italianJobs, job: 1, duties: "Eseguivo la lubrificazione dei macchinari.",
            keeping: ["Eseguivo la lubrificazione dei macchinari."], against: JobClausesTests.italian
        )
        let none = try sanitizer.dutyCheck(of: Self.italianJobs, job: 9, duties: "Riparavo i motori.", against: JobClausesTests.italian)

        #expect(verdicts.kept.isEmpty)
        #expect(verdicts.rejected.map(\.reason) == ["it repeats a duty already written"])
        #expect(none.kept.isEmpty && none.pinned.isEmpty && none.rejected.isEmpty)
    }

    // MARK: The context of each job

    @Test("Each job the facts keep gets the clauses of the description that belong to it, in the order of the facts, and the field the person states")
    func contextOfEachJob() throws {
        let context = try sanitizer.draftContext(of: Self.italianJobs, against: JobClausesTests.italian)
        let facts = try sanitizer.sanitize(Self.italianJobs, against: JobClausesTests.italian)

        #expect(context.jobs.count == facts.experience.count)
        #expect(context.jobs.map(\.job) == [0, 1, 2, 3])
        #expect(context.jobs[0].clauses.contains { $0.contains("nastri trasportatori") })
        #expect(!context.jobs[0].clauses.contains { $0.contains("Birrificio") })
        #expect(context.jobs[3].clauses.contains { $0.contains("coordino tre tecnici") })
    }

    // MARK: The skills

    @Test("A quality listed as a tool is a soft skill, and a tool named by an activity goes, even when the tagger reads its first word as a verb")
    func skillsCleaned() {
        let tagging = Self.italian(ForcedLexicalTagger([.italian: .words(["software"])]), wordList: TableWordList())
        let description = "Dal 2020 lavoro al Birrificio Valtrigno, dove uso i PLC e gestisco i fermi impianto."

        let verdict = tagging.skillCheck(
            technologies: ["PLC", "precisione", "software di gestione fermi", "PLC"], softSkills: ["lavoro di squadra"], against: description
        )

        #expect(verdict.technologies == ["PLC"])
        #expect(verdict.softSkills == ["precisione", "lavoro di squadra"])
        #expect(verdict.dropped.map(\.reason) == ["activity"])
    }

    @Test("A skill whose words are all of English, in a description of another language, goes")
    func skillInAnotherLanguage() {
        let englishOnly = Self.italian(ForcedLexicalTagger([:]), wordList: EnglishOnly())

        let verdict = englishOnly.skillCheck(
            technologies: ["preventive maintenance"], softSkills: [], against: JobClausesTests.italian
        )

        #expect(verdict.technologies.isEmpty)
        #expect(verdict.dropped.map(\.reason) == ["another language"])
    }

    @Test("Of two technologies of one kind, by their head noun, the second goes; tools of other kinds, and a short last word, stay (#354)")
    func toolsOfOneKind() {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let french = CVDataSanitizer(languageOfText: { _ in "fr" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let sound = english.skillCheck(
            technologies: ["studio monitors", "digital mixing desk", "nearfield monitor", "Shure microphones", "Logic Pro", "Premiere Pro"],
            softSkills: [], against: "I mix the sound for a small theatre in Hull."
        )
        let wiring = french.skillCheck(
            technologies: ["pince à dénuder", "multimètre", "pinces coupantes", "l'oscilloscope"], softSkills: [],
            against: "Je câble des tableaux électriques à Rouen."
        )

        #expect(sound.technologies == ["studio monitors", "digital mixing desk", "Shure microphones", "Logic Pro", "Premiere Pro"])
        #expect(sound.dropped.map(\.reason) == ["same kind as an earlier tool"])
        #expect(wiring.technologies == ["pince à dénuder", "multimètre", "l'oscilloscope"])
        #expect(wiring.dropped.map(\.sentence) == ["pinces coupantes"])
    }

    @Test("A fragment and a lone verb go from the skills")
    func fragmentsGo() {
        let verdict = sanitizer.skillCheck(
            technologies: ["manutenzione di", "uso dei PLC: base"], softSkills: [], against: JobClausesTests.italian
        )

        #expect(verdict.technologies.isEmpty)
        #expect(verdict.dropped.map(\.reason) == ["fragment", "fragment"])
    }

    // MARK: The summary

    @Test("A summary sentence about the person in the third person goes, and a short summary with no title gets an opening from the facts")
    func summaryChecked() throws {
        // The current job's sentence names its employer alone, so that the facts keep the job current.
        let description = JobClausesTests.italian.replacingOccurrences(
            of: "Birrificio Valtrigno di Campobasso, dove coordino tre tecnici.", with: "Birrificio Valtrigno."
        )

        let verdict = try sanitizer.summaryCheck(
            of: Self.italianJobs, summary: "Lui è un tecnico esperto. Mi occupo degli impianti con cura.", field: nil, against: description
        )

        #expect(verdict.rejected.map(\.reason) == ["it speaks of the person in the third person: write it as the person, with no subject"])
        #expect(verdict.kept == ["Mi occupo degli impianti con cura."])
        #expect(verdict.problems.contains("it keeps fewer than 2 sentences"))
        #expect(verdict.problems.contains("it is shorter than 120 characters"))
        #expect(verdict.opening == "Lavoro come capoturno della manutenzione.")
    }

    @Test("The opening says the current job's title in the present, else the last one's in the past, in the description's language")
    func openings() {
        let teacher = CVData(experience: [Self.job("institutrice", "École Lamartine", from: "2015")])
        let electrician = CVData(experience: [
            Self.job("apprentice", "Brook Lane Works", from: "2009", to: "2012"),
            Self.job("electrician", "Harlow Fittings", from: "2012", to: "2019"),
        ])

        #expect(CVDataSanitizer.opening(of: teacher, language: .french) == "Je travaille comme institutrice.")
        #expect(CVDataSanitizer.opening(of: electrician, language: .english) == "I worked as an electrician.")
        #expect(CVDataSanitizer.opening(of: electrician, language: .german) == "Ich habe als electrician gearbeitet.")
        #expect(CVDataSanitizer.opening(of: CVData(), language: .english) == nil)
        #expect(CVDataSanitizer.opening(of: teacher, language: nil) == nil)
    }
}

/// A dictionary that knows every word in English and none in any other language.
private struct EnglishOnly: WordList {
    func knows(_ word: String, inLanguage language: String) -> Bool? { language == "en" }
}

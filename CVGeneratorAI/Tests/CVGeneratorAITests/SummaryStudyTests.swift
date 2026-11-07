import Testing
@testable import CVGeneratorAI

/// A rich summary does not say a school or a course taught the person's languages (#359, P3): the model joined "I studied at the
/// school" and "I speak French and English" of two sentences of the description into one that said the school taught them. The
/// sentence goes whole, unless the description says it; each sentence on its own stays. The descriptions are the evaluation's, and
/// every name and trade in them is invented.
@Suite("A summary does not say a school or a course taught the person's languages (#359, P3)", .richDraft)
struct SummaryStudyTests {
    private static func sanitizer(_ language: String) -> CVDataSanitizer {
        CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
    }

    private static func description(of id: String) throws -> String {
        try #require(DraftingInputs.all().first { $0.id == id }).description
    }

    /// The facts of each input and the opening sentence its summary starts with.
    private static let inputs: [String: (cv: CVData, opening: String)] = [
        "de-traps": (
            CVData(
                personalInfo: PersonalInfo(name: "Lena Hoffmeister", title: "Physiotherapeutin"),
                experience: [
                    Experience(title: "Physiotherapeutin", company: "Praxis Sonnenhof", startDate: "2019", current: true),
                    Experience(title: "Physiotherapeutin", company: "Reha-Klinik Waldblick", startDate: "2016", endDate: "2019"),
                ],
                education: [Education(degree: "Ausbildung", institution: "Fachschule für Physiotherapie Kassel")],
                languages: [Language(name: "Deutsch"), Language(name: "Englisch")]
            ),
            "Ich arbeite als Physiotherapeutin."
        ),
        "fr-plain": (
            CVData(
                personalInfo: PersonalInfo(name: "Camille Durand", title: "boulangère"),
                experience: [
                    Experience(title: "boulangère", company: "Boulangerie des Tilleuls", startDate: "2019", current: true),
                    Experience(title: "vendeuse", company: "Pâtisserie Bellevue", startDate: "2015", endDate: "2019"),
                ],
                education: [Education(degree: "CAP", institution: "lycée professionnel Les Mauves")],
                languages: [Language(name: "français"), Language(name: "anglais")]
            ),
            "Je travaille comme boulangère."
        ),
        "example-fr": (
            CVData(
                personalInfo: PersonalInfo(name: "Maria Rossi", title: "institutrice"),
                experience: [Experience(title: "institutrice", company: "école Don Milani", startDate: "2016", current: true)],
                education: [Education(degree: "sciences de l'éducation", institution: "université de Bologne")],
                languages: [Language(name: "italien", proficiency: .native), Language(name: "anglais", proficiency: .b2)]
            ),
            "Je travaille comme institutrice."
        ),
        "pt-plain": (
            CVData(
                personalInfo: PersonalInfo(name: "Beatriz Moura", title: "enfermeira"),
                experience: [
                    Experience(title: "enfermeira", company: "Hospital da Ribeira", startDate: "2018", current: true),
                    Experience(title: "enfermeira", company: "Centro de Saúde de Vale Verde", startDate: "2014", endDate: "2018"),
                ],
                education: [Education(degree: "curso", institution: "Escola Superior de Saúde do Mondego")],
                languages: [Language(name: "português"), Language(name: "inglês")]
            ),
            "Trabalho como enfermeira."
        ),
    ]

    private static func check(_ id: String, _ sentence: String) throws -> CVDataSanitizer.SummaryVerdict {
        let input = try #require(inputs[id])
        let language = try #require(DraftingInputs.all().first { $0.id == id }).language
        return try sanitizer(language).summaryCheck(
            of: input.cv, summary: sentence, field: nil, work: [], duties: [], qualities: [], against: try description(of: id)
        )
    }

    private static func finalSummary(_ id: String, _ sentence: String) throws -> String? {
        let input = try #require(inputs[id])
        let language = try #require(DraftingInputs.all().first { $0.id == id }).language
        let writing = DraftWriting(
            summary: input.opening + " " + sentence, roleDescriptions: input.cv.experience.map { _ in nil }, technologies: [], softSkills: []
        )
        return try sanitizer(language).sanitize(input.cv, writing: writing, against: try description(of: id)).summary
    }

    // MARK: A school that taught the languages goes

    private static let ties: [(String, String)] = [
        ("de-traps", "Ich habe in der Ausbildung an der Fachschule für Physiotherapie Kassel Deutsch und Englisch studiert."),
        ("fr-plain", "J'ai étudié le CAP à lycée professionnel Les Mauves en français et en anglais."),
        ("example-fr", "J'ai étudié les sciences de l'éducation à l'université de Bologne en parlant italien et anglais."),
        ("pt-plain", "Estudei o curso na Escola Superior de Saúde do Mondego em português e inglês."),
    ]

    @Test("A sentence that ties a school or a course to the person's languages is rejected, with the reason to say them apart", arguments: ties)
    func tieRejected(id: String, sentence: String) throws {
        let verdict = try Self.check(id, sentence)

        #expect(verdict.kept.isEmpty, "\(verdict.kept)")
        #expect(verdict.rejected.map(\.sentence) == [sentence], "\(verdict.rejected)")
        #expect(verdict.rejected.map(\.reason) == [CVDataSanitizer.tiesAStudyToALanguage], "\(verdict.rejected)")
    }

    @Test("The final pass drops that sentence and keeps the opening", arguments: ties)
    func tieDroppedInTheFinalPass(id: String, sentence: String) throws {
        let summary = try Self.finalSummary(id, sentence)

        #expect(summary == Self.inputs[id]?.opening, "\(summary ?? "nil")")
    }

    // MARK: Two schools and two languages: a sentence the description says of one school stays (review round 1)

    private static let twoSchools = CVData(
        personalInfo: PersonalInfo(name: "Daniel Hart", title: "nurse"),
        experience: [],
        education: [
            Education(degree: "French", institution: "Lyon College"),
            Education(degree: "nursing", institution: "Harlow City College"),
        ],
        languages: [Language(name: "French"), Language(name: "German")]
    )

    private static let twoSchoolsDescription = "I studied French at Lyon College. I studied nursing at Harlow City College. I speak German."

    @Test("A sentence that ties one school to the language of another sentence goes, though another school's sentence names a language",
          arguments: [
            ("I studied nursing in German at Harlow City College.", false),
            ("I studied French at Lyon College.", true),
          ])
    func twoSchoolsTwoLanguages(sentence: String, kept: Bool) throws {
        let verdict = try Self.sanitizer("en").summaryCheck(
            of: Self.twoSchools, summary: sentence, field: nil, work: [], duties: [], qualities: [], against: Self.twoSchoolsDescription
        )
        let writing = DraftWriting(summary: "I studied nursing. " + sentence, roleDescriptions: [], technologies: [], softSkills: [])
        let draft = try Self.sanitizer("en").sanitize(Self.twoSchools, writing: writing, against: Self.twoSchoolsDescription)

        #expect(verdict.kept == (kept ? [sentence] : []), "\(verdict.kept) \(verdict.rejected)")
        #expect(verdict.rejected.map(\.reason) == (kept ? [] : [CVDataSanitizer.tiesAStudyToALanguage]), "\(verdict.rejected)")
        #expect(draft.summary == "I studied nursing." + (kept ? " " + sentence : ""), "\(draft.summary ?? "nil")")
    }

    // MARK: The studies and the languages, each on its own, stay

    private static let separate: [(String, String)] = [
        ("de-traps", "Ich spreche Deutsch und Englisch."),
        ("de-traps", "Ich habe meine Ausbildung an der Fachschule für Physiotherapie Kassel abgeschlossen."),
        ("fr-plain", "Je parle français et anglais."),
        ("fr-plain", "J'ai obtenu mon CAP au lycée professionnel Les Mauves."),
        ("example-fr", "Je parle italien et anglais."),
        ("example-fr", "J'ai étudié les sciences de l'éducation à l'université de Bologne."),
        ("pt-plain", "Falo português e inglês."),
        ("pt-plain", "Estudei na Escola Superior de Saúde do Mondego."),
    ]

    @Test("The sentence about the studies and the sentence about the languages each stay", arguments: separate)
    func separateSentencesKept(id: String, sentence: String) throws {
        let verdict = try Self.check(id, sentence)
        let summary = try Self.finalSummary(id, sentence)

        #expect(verdict.kept == [sentence], "\(verdict.kept) \(verdict.rejected)")
        #expect(verdict.rejected.isEmpty, "\(verdict.rejected)")
        #expect(summary == Self.inputs[id].map { $0.opening + " " + sentence }, "\(summary ?? "nil")")
    }

    // MARK: What the person states, or what only shares a word, stays

    private static let english = CVData(
        personalInfo: PersonalInfo(name: "Daniel Hart", title: "warehouse operative"),
        experience: [Experience(title: "warehouse operative", company: "Depot Arlen", startDate: "2019", current: true)],
        education: [Education(degree: "English literature", institution: "Harlow City College")],
        languages: [Language(name: "English"), Language(name: "Polish")]
    )

    private static let englishDescription = """
        Since 2019 I work as a warehouse operative at Depot Arlen, where I load the lorries. I studied English and Polish at Harlow \
        City College. I have a degree in English literature. I speak English and Polish.
        """

    @Test("A sentence the description says word for word stays, and so does a language the degree shares a word with",
          arguments: [
            "I studied English and Polish at Harlow City College.",
            "I speak English and Polish.",
          ])
    func statedAndSharedWordsKept(sentence: String) throws {
        let verdict = try Self.sanitizer("en").summaryCheck(
            of: Self.english, summary: sentence, field: nil, work: [], duties: [], qualities: [], against: Self.englishDescription
        )
        let writing = DraftWriting(
            summary: "I work as a warehouse operative. " + sentence, roleDescriptions: [nil], technologies: [], softSkills: []
        )
        let draft = try Self.sanitizer("en").sanitize(Self.english, writing: writing, against: Self.englishDescription)

        #expect(verdict.kept == [sentence], "\(verdict.kept) \(verdict.rejected)")
        #expect(draft.summary == "I work as a warehouse operative. " + sentence, "\(draft.summary ?? "nil")")
    }
}

import Testing
@testable import CVGeneratorAI

/// The draft of the evaluation's "jobs-de" (#359, P7): a landscape gardener who names four jobs and the duties of each. Its final
/// draft lost seven of the duties she said, though the model's first answer held them all. The answer and the text the second pass
/// wrote are the evaluation's run 1 (revision 5f848081, macOS 27), and every name and trade in them is invented.
@Suite("The evaluation's German jobs keep every duty the person said for them (#359, P7)", .richDraft)
struct GermanJobsDraftTests {
    /// The verbs the device tags in the description and in the written text.
    private static let tagger = ForcedLexicalTagger([.german: .words([
        "arbeite", "war", "umgetopft", "gepflegt", "habe", "ausgeholfen", "bin", "einteile", "plane", "fahre", "suche", "sorge",
        "stelle", "vorbereitet", "geschnitten", "gepflanzt", "gestaltet", "definiert", "sind", "verteilt", "wird", "teile", "pflege",
    ])])

    private static let sanitizer = CVDataSanitizer(
        languageOfText: { _ in "de" }, lexicalClasses: tagger,
        wordList: TableWordList(names: TableWordList.inventedNames.union(["lindenhof", "mertens", "grünwerk", "sauer", "hollerbach", "fulda"]))
    )

    private static let opening = "Ich arbeite seit sechzehn Jahren im Garten- und Landschaftsbau."

    private static func repeated(_ times: Int, then last: String? = nil) -> String {
        (Array(repeating: opening, count: times) + [last].compactMap { $0 }).joined(separator: " ")
    }

    /// The model's first answer, as the evaluation saved it.
    private static let answer = CVData(
        personalInfo: PersonalInfo(name: "Ich", location: "Fulda"),
        summary: opening + " Von 2009 bis 2013 war ich Gärtnerhelferin bei der Baumschule Lindenhof in Kassel, wo ich Jungpflanzen "
            + "umgetopft und die Beete gepflegt habe. Seit 2020 bin ich Vorarbeiterin bei der Stadtgärtnerei Hollerbach in Fulda, wo ich "
            + "die Kolonne einteile und die Pflege der Parkanlagen plane.",
        experience: [
            Experience(
                title: "Vorarbeiterin", company: "Stadtgärtnerei Hollerbach", location: "Fulda", current: true,
                description: repeated(3), achievements: ["die Kolonne einteile", "die Pflege der Parkanlagen plane"]
            ),
            Experience(
                title: "Gärtnerhelferin", company: "Baumschule Lindenhof", location: "Kassel", startDate: "2009", endDate: "2013",
                description: repeated(3, then: "Ich habe Jungpflanzen umgetopft und die Beete gepflegt."),
                achievements: ["Jungpflanzen umtopfen", "Beete pflegen"]
            ),
            Experience(
                title: "Landschaftsgärtnerin", company: "Gartenbau Mertens", location: "null", startDate: "2013", endDate: "2017",
                description: repeated(3, then: "Mit dem Verlegen von Pflasterflächen und dem Einbau von Bewässerungsanlagen."),
                achievements: ["Verlegen von Pflasterflächen", "Einbau von Bewässerungsanlagen"]
            ),
            Experience(
                title: "Arbeitskraft", company: "Grünwerk Sauer", location: "null", startDate: "2017", endDate: "2020",
                description: repeated(2, then: "Bei Grünwerk Sauer habe ich auch mal bei der Baumpflege ausgeholfen."),
                achievements: ["Baumpflege ausgeholfen"]
            ),
        ],
        skills: [Skill(name: "Minibagger", kind: .technology), Skill(name: "Rüttelplatte", kind: .technology), Skill(name: "Motorsäge", kind: .technology)],
        interests: ["verlässig", "gern im Team"]
    )

    /// What the second pass wrote for the grounded jobs, as the evaluation saved it.
    private static let writing = DraftWriting(
        summary: "Ich arbeite als Vorarbeiterin. Ich definiere alle Bereiche klar, um dafür verantwortlich zu sein.",
        roleDescriptions: [
            "Ich sorge dafür, dass alle Bereiche klar definiert sind. Ich stelle sicher, dass die Arbeit ordentlich verteilt wird.",
            "Ich habe die Erde vorbereitet. Ich habe die Ranken geschnitten.",
            "Gestalten von Grünflächen nach Vorgaben. Pflegen von Beeten und Sträuchern. Planen von Wegen und Landschaftsstrukturen. "
                + "Überwachen der Entwicklung von Pflanzenbeständen.",
            "Ich habe die Pflanzen gepflanzt. Ich habe die Wege gestaltet.",
        ],
        technologies: ["Baggersteuerung", "Erdbewegungsgerät", "Markierungswerkzeug", "Sägeanlage", "Umtopfer", "Bodenwalzmaschine"],
        softSkills: ["Planungstisch", "Zuverlässigkeit", "Teamgeist", "Arbeitsmoral"]
    )

    @Test("Each duty the person said stays in the final text of its job, as the evaluation counts it: its word is in the job's text", arguments: [
        ("Lindenhof", "Beete"), ("Lindenhof", "Jungpflanzen"), ("Mertens", "Pflasterflächen"), ("Grünwerk", "Pflasterflächen"),
        ("Mertens", "Bewässerungsanlagen"), ("Grünwerk", "Bewässerungsanlagen"), ("Grünwerk", "Baumpflege"),
        ("Hollerbach", "Parkanlagen"), ("Hollerbach", "Kolonne"),
    ])
    func dutyStays(employer: String, duty: String) throws {
        let description = try #require(DraftingInputs.jobs.first { $0.id == "jobs-de" }).description
        let draft = try Self.sanitizer.sanitize(Self.answer, writing: Self.writing, against: description)
        let job = try #require(draft.experience.first { $0.company.contains(employer) }, "\(draft.experience.map(\.company))")

        #expect(job.description?.contains(duty) == true, "\(draft.experience.map { "\($0.company): \($0.description ?? "")" })")
    }
}

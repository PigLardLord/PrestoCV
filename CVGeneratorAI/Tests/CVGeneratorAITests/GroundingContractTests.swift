import Testing
import Foundation
@testable import CVGeneratorAI

// ADR 0023, decision (a): the contract of the sanitiser. A row is a description, the draft a model wrote for it, and what
// `CVDataSanitizer` (the call the use case makes) must leave of the draft.
//
// NO ROW MAY BE DELETED OR WEAKENED: not its description, its draft or its expectation. A new finding adds a row, red
// first. A row the sanitiser does not hold yet is listed in `GroundingRows.notImplementedYet` and runs inside
// `withKnownIssue`: once the sanitiser holds it the wrapper fails, and the one edit a row ever takes is to leave that
// list. `rowCountNeverDrops` fails when a row goes.
//
// The rows assume that the closed vocabulary of the ADR holds the plain words they use: function words (I, a, at, in,
// from, to, for, and, the, have, am, with, of, where), the verbs of a CV (worked, taught, trained, studied, graduated,
// started, moved, employed), the words of time (now, since, before, years, months), of level, and of studying and
// graduating (degree, Abschluss, diplôme, laurea...). They assume too that a clause which names no employer joins the
// clause next to it (ADR 0023, rule (c)).

// MARK: - The suite

@Suite("Grounding contract: ADR 0023")
struct GroundingContractTests {
    @Test("A row of the contract holds", arguments: GroundingRows.all)
    func rowHolds(_ row: GroundingRow) throws {
        func check() throws {
            let differences = try Verdict.differences(of: row)
            #expect(differences.isEmpty, "\(row.id): \(row.reason)\n\(differences.joined(separator: "\n"))")
        }

        if GroundingRows.notImplementedYet.contains(row.id) {
            withKnownIssue("ADR 0023 not implemented yet") { try check() }
        } else if GroundingRows.residualRisks.contains(row.id) {
            withKnownIssue("ADR 0023, Consequences: a residual risk the owner accepts") { try check() }
        } else {
            try check()
        }
    }

    @Test("The table never loses a row")
    func rowCountNeverDrops() {
        #expect(GroundingRows.all.count >= GroundingRows.rowsWhenWritten, "A row was deleted: rows are never removed")
    }

    @Test("Every row has an id of its own")
    func idsAreUnique() {
        let ids = GroundingRows.all.map(\.id)

        #expect(Set(ids).count == ids.count, "Repeated ids: \(Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.keys.sorted())")
    }

    @Test("A known issue names a row of the table")
    func knownIssuesNameRows() {
        let ids = Set(GroundingRows.all.map(\.id))

        #expect(GroundingRows.notImplementedYet.subtracting(ids).isEmpty, "\(GroundingRows.notImplementedYet.subtracting(ids).sorted())")
    }

    @Test("A residual risk names a row of the table, and is no row the sanitiser does not hold yet")
    func residualRisksNameRows() {
        let ids = Set(GroundingRows.all.map(\.id))

        #expect(GroundingRows.residualRisks.subtracting(ids).isEmpty, "\(GroundingRows.residualRisks.subtracting(ids).sorted())")
        #expect(GroundingRows.residualRisks.isDisjoint(with: GroundingRows.notImplementedYet))
    }

    @Test("An expectation names fields that its draft has, once each")
    func expectationsNameFieldsOfTheirDraft() {
        for row in GroundingRows.all {
            guard case .keeping(let drops, let rewrites) = row.expected else { continue }
            let paths = Set(Sheet.leaves(of: row.draft).map(\.path))
            let named = drops.map(\.path) + rewrites.map(\.path)

            #expect(paths.isSuperset(of: named), "\(row.id): the draft has no field \(Set(named).subtracting(paths).sorted())")
            #expect(Set(rewrites.map(\.path)).isDisjoint(with: drops.map(\.path)), "\(row.id): a field is both dropped and rewritten")
        }
    }

    @Test("Each of the six languages has a faithful draft and a real-model draft of the app's example",
          arguments: ["en", "it", "de", "es", "fr", "pt"])
    func languagesAreCovered(language: String) {
        let rows = GroundingRows.all.filter { $0.language == language }

        #expect(rows.contains { $0.kind == .faithful }, "No faithful control in \(language)")
        #expect(rows.contains { $0.kind == .probe }, "No real-model probe in \(language)")
    }

    @Test("The example descriptions of the table are the ones the app shows",
          arguments: ["en", "it", "de", "es", "fr", "pt"])
    func exampleDescriptionsAreTheApps(language: String) throws {
        let catalogURL = SourceTree.root.appendingPathComponent("PrestoCV/Localizable.xcstrings")
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        let localizations = try #require(strings["ai.generation.example_text"]?["localizations"] as? [String: [String: Any]])
        let unit = try #require(localizations[language]?["stringUnit"] as? [String: Any])

        #expect(unit["value"] as? String == AppExample.text(in: language))
    }
}

// MARK: - A row

/// One idea of the contract.
struct GroundingRow: Sendable, CustomTestStringConvertible {
    enum Kind: Sendable {
        /// A finding of the review rounds, or a rule of the ADR, with a draft that breaks it.
        case counterexample
        /// A draft that quotes the app's example description, as a good model would.
        case faithful
        /// A draft a real model wrote for the app's example descriptions, or for another probe.
        case probe
    }

    let id: String
    /// What the row shows, in a line.
    let reason: String
    let kind: Kind
    /// BCP 47 code of the language of the description.
    let language: String
    let description: String
    /// What the model answered.
    let draft: CVData
    let expected: Outcome

    var testDescription: String { id }
}

/// What must be left of a draft.
enum Outcome: Sendable {
    /// Exactly this draft.
    case exactly(CVData)
    /// The draft as it was, but for the fields dropped and the fields rewritten.
    case keeping([Drop], rewriting: [Rewrite] = [])
    /// Safety only, where what survives depends on words the ADR leaves to its lists: no value holds a text of `never`,
    /// no field of `absent` exists, and the fields of `keeping` hold their value.
    case safe(never: [String], absent: [String] = [], keeping: [String: String] = [:])

    /// The draft as it was.
    static var unchanged: Outcome { .keeping([]) }
}

/// A field of the draft that the sanitiser takes out, and why.
struct Drop: Sendable {
    let path: String
    let because: String

    init(_ path: String, _ because: String) {
        self.path = path
        self.because = because
    }

    /// Every field of the draft that holds the word null, which the model writes for what it has not got.
    static func nulls(in draft: CVData) -> [Drop] {
        Sheet.leaves(of: draft).filter { $0.value.lowercased() == "null" }.map { Drop($0.path, "the model wrote the word null") }
    }

    /// Every field of an entry of the draft (`experience[1]`): the entry goes.
    static func entry(_ prefix: String, in draft: CVData, because: String) -> [Drop] {
        Sheet.leaves(of: draft).filter { $0.path.hasPrefix(prefix + ".") }.map { Drop($0.path, because) }
    }
}

/// A field of the draft that the sanitiser keeps in part, and why.
struct Rewrite: Sendable {
    let path: String
    let value: String
    let because: String

    init(_ path: String, to value: String, _ because: String) {
        self.path = path
        self.value = value
        self.because = because
    }
}

// MARK: - Reading a draft as fields

/// A draft as a list of fields (`experience[0].startDate = 2016`), one for each text that is not empty.
private enum Sheet {
    struct Step {
        let name: String
        let index: Int?

        init(_ name: String, _ index: Int? = nil) {
            self.name = name
            self.index = index
        }
    }

    struct Leaf {
        let steps: [Step]
        let value: String

        var path: String {
            steps.map { step in step.index.map { "\(step.name)[\($0)]" } ?? step.name }.joined(separator: ".")
        }
    }

    static func leaves(of cv: CVData) -> [Leaf] {
        var found: [Leaf] = []
        func add(_ steps: [Step], _ value: String?) {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            found.append(Leaf(steps: steps, value: value))
        }

        let info = cv.personalInfo
        let personal: [(String, String?)] = [
            ("name", info.name), ("email", info.email), ("phone", info.phone), ("location", info.location),
            ("website", info.website), ("linkedin", info.linkedin), ("github", info.github), ("title", info.title),
        ]
        for (name, value) in personal { add([Step("personalInfo"), Step(name)], value) }
        add([Step("summary")], cv.summary)

        for (index, job) in cv.experience.enumerated() {
            let entry = Step("experience", index)
            let fields: [(String, String?)] = [
                ("title", job.title), ("company", job.company), ("location", job.location), ("startDate", job.startDate),
                ("endDate", job.endDate), ("current", job.current ? "true" : nil), ("description", job.description),
            ]
            for (name, value) in fields { add([entry, Step(name)], value) }
            for (number, achievement) in job.achievements.enumerated() { add([entry, Step("achievements", number)], achievement) }
        }
        for (index, study) in cv.education.enumerated() {
            let entry = Step("education", index)
            let fields: [(String, String?)] = [
                ("degree", study.degree), ("institution", study.institution), ("startDate", study.startDate),
                ("endDate", study.endDate), ("description", study.description),
            ]
            for (name, value) in fields { add([entry, Step(name)], value) }
        }
        for (index, skill) in cv.skills.enumerated() {
            add([Step("skills", index), Step("name")], skill.name)
            add([Step("skills", index), Step("level")], skill.level?.rawValue)
        }
        for (index, language) in cv.languages.enumerated() {
            add([Step("languages", index), Step("name")], language.name)
            add([Step("languages", index), Step("proficiency")], language.proficiency?.rawValue)
        }
        for (index, certification) in cv.certifications.enumerated() {
            let entry = Step("certifications", index)
            let fields: [(String, String?)] = [
                ("name", certification.name), ("issuer", certification.issuer), ("date", certification.date), ("url", certification.url),
            ]
            for (name, value) in fields { add([entry, Step(name)], value) }
        }
        for (index, interest) in cv.interests.enumerated() { add([Step("interests", index)], interest) }
        return found
    }

    /// The fields by path, with the entries and achievements renumbered: an entry with nothing left is not counted.
    static func fields(of cv: CVData) -> [String: String] {
        compacted(leaves(of: cv))
    }

    /// The fields the sanitised draft must have for a `keeping` outcome.
    static func fields(of draft: CVData, dropping drops: [Drop], rewriting rewrites: [Rewrite]) -> [String: String] {
        let dropped = Set(drops.map(\.path))
        var rewritten: [String: String] = [:]
        for rewrite in rewrites { rewritten[rewrite.path] = rewrite.value }

        let kept = leaves(of: draft)
            .filter { !dropped.contains($0.path) }
            .map { leaf in rewritten[leaf.path].map { Leaf(steps: leaf.steps, value: $0) } ?? leaf }
        return compacted(kept)
    }

    private static func compacted(_ leaves: [Leaf]) -> [String: String] {
        var counters: [String: Int] = [:]
        var numbers: [String: Int] = [:]
        var fields: [String: String] = [:]

        for leaf in leaves {
            var path = ""
            for step in leaf.steps {
                path += path.isEmpty ? "" : "."
                guard let index = step.index else {
                    path += step.name
                    continue
                }
                let list = path + step.name
                let key = "\(list)#\(index)"
                if numbers[key] == nil {
                    numbers[key] = counters[list, default: 0]
                    counters[list, default: 0] += 1
                }
                path += "\(step.name)[\(numbers[key] ?? 0)]"
            }
            fields[path] = leaf.value
        }
        return fields
    }
}

// MARK: - Judging a row

private enum Verdict {
    /// What the sanitiser leaves of the draft of a row that the contract does not allow; empty when the row holds.
    static func differences(of row: GroundingRow) throws -> [String] {
        let result = try CVDataSanitizer().sanitize(row.draft, against: row.description)
        let actual = Sheet.fields(of: result)

        switch row.expected {
        case .exactly(let expected):
            return compare(Sheet.fields(of: expected), actual)
        case .keeping(let drops, let rewrites):
            return compare(Sheet.fields(of: row.draft, dropping: drops, rewriting: rewrites), actual)
        case .safe(let never, let absent, let keeping):
            var problems: [String] = []
            for (path, value) in actual.sorted(by: { $0.key < $1.key }) {
                if let text = never.first(where: { value.lowercased().contains($0.lowercased()) }) {
                    problems.append("  \(path) = \"\(value)\" holds \"\(text)\"")
                }
            }
            for path in absent where actual[path] != nil {
                problems.append("  \(path) = \"\(actual[path] ?? "")\" must not exist")
            }
            for (path, value) in keeping.sorted(by: { $0.key < $1.key }) where actual[path] != value {
                problems.append("  \(path): expected \"\(value)\", got \(describe(actual[path]))")
            }
            return problems
        }
    }

    private static func compare(_ expected: [String: String], _ actual: [String: String]) -> [String] {
        Set(expected.keys).union(actual.keys).sorted().compactMap { path in
            expected[path] == actual[path] ? nil : "  \(path): expected \(describe(expected[path])), got \(describe(actual[path]))"
        }
    }

    private static func describe(_ value: String?) -> String {
        value.map { "\"\($0)\"" } ?? "nothing"
    }
}

private enum SourceTree {
    /// The root of the repository, found from this file: CVGeneratorAI/Tests/CVGeneratorAITests/GroundingContractTests.swift.
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
}

// MARK: - Builders

private func job(
    _ title: String = "", _ company: String = "", from start: String? = nil, to end: String? = nil, current: Bool = false,
    location: String? = nil, description: String? = nil, achievements: [String] = []
) -> Experience {
    Experience(title: title, company: company, location: location, startDate: start, endDate: end, current: current,
               description: description, achievements: achievements)
}

private func study(
    _ degree: String? = nil, at institution: String? = nil, from start: String? = nil, to end: String? = nil, description: String? = nil
) -> Education {
    Education(degree: degree, institution: institution, startDate: start, endDate: end, description: description)
}

private func person(
    name: String? = nil, email: String? = nil, phone: String? = nil, location: String? = nil, website: String? = nil,
    linkedin: String? = nil, github: String? = nil, title: String? = nil
) -> PersonalInfo {
    PersonalInfo(name: name, email: email, phone: phone, location: location, website: website, linkedin: linkedin,
                 github: github, title: title)
}

private func row(
    _ id: String, _ reason: String, _ description: String, _ draft: CVData, _ expected: Outcome,
    kind: GroundingRow.Kind = .counterexample, language: String = "en"
) -> GroundingRow {
    GroundingRow(id: id, reason: reason, kind: kind, language: language, description: description, draft: draft, expected: expected)
}

/// What the real model writes for a field it has not got.
private let null = "null"

// MARK: - The app's example descriptions

/// `ai.generation.example_text` of the string catalog, in the six languages.
private enum AppExample {
    static let en = "I'm Maria Rossi, a primary school teacher from Bologna. Since 2016 I have taught at the Don Milani school, "
        + "where I trained 3 new teachers. Before that, from 2012 to 2016, I worked as an assistant in a nursery. "
        + "I studied Education Sciences at the University of Bologna and graduated in 2012. "
        + "I speak Italian (native) and English (B2). In my free time I like chess and hiking."
    static let it = "Sono Maria Rossi, insegnante di scuola primaria a Bologna. Dal 2016 insegno alla scuola Don Milani, "
        + "dove ho formato 3 nuovi insegnanti. Prima, dal 2012 al 2016, ho lavorato come assistente in un asilo nido. "
        + "Ho studiato Scienze della Formazione all'Università di Bologna e mi sono laureata nel 2012. "
        + "Parlo italiano (madrelingua) e inglese (B2). Nel tempo libero mi piacciono gli scacchi e le escursioni."
    static let de = "Ich bin Maria Rossi, Grundschullehrerin aus Bologna. Seit 2016 unterrichte ich an der Schule Don Milani, "
        + "wo ich 3 neue Lehrkräfte eingearbeitet habe. Davor habe ich von 2012 bis 2016 als Betreuerin in einer Kinderkrippe "
        + "gearbeitet. Ich habe Erziehungswissenschaften an der Universität Bologna studiert und 2012 meinen Abschluss gemacht. "
        + "Ich spreche Italienisch (Muttersprache) und Englisch (B2). In meiner Freizeit mag ich Schach und Wandern."
    static let es = "Soy Maria Rossi, maestra de primaria en Bolonia. Desde 2016 enseño en la escuela Don Milani, "
        + "donde formé a 3 nuevos maestros. Antes, de 2012 a 2016, trabajé como auxiliar en una guardería. "
        + "Estudié Ciencias de la Educación en la Universidad de Bolonia y me gradué en 2012. "
        + "Hablo italiano (nativo) e inglés (B2). En mi tiempo libre me gustan el ajedrez y el senderismo."
    static let fr = "Je suis Maria Rossi, institutrice dans une école primaire de Bologne. Depuis 2016, j'enseigne à l'école Don Milani, "
        + "où j'ai formé 3 nouveaux enseignants. Avant, de 2012 à 2016, j'ai travaillé comme assistante dans une crèche. "
        + "J'ai étudié les sciences de l'éducation à l'université de Bologne et j'ai obtenu mon diplôme en 2012. "
        + "Je parle italien (langue maternelle) et anglais (B2). Pendant mon temps libre, j'aime les échecs et la randonnée."
    static let pt = "Sou Maria Rossi, professora do ensino fundamental em Bolonha. Desde 2016 leciono na escola Don Milani, "
        + "onde formei 3 novos professores. Antes, de 2012 a 2016, trabalhei como auxiliar em uma creche. "
        + "Estudei Ciências da Educação na Universidade de Bolonha e me formei em 2012. "
        + "Falo italiano (nativo) e inglês (B2). No meu tempo livre, gosto de xadrez e de caminhadas."

    static func text(in language: String) -> String {
        switch language {
        case "it": return it
        case "de": return de
        case "es": return es
        case "fr": return fr
        case "pt": return pt
        default: return en
        }
    }
}

// MARK: - The table

enum GroundingRows {
    /// The rows the table had when it was written; it never has fewer.
    static let rowsWhenWritten = 1787

    /// Rows the sanitiser does not hold yet. Each runs in `withKnownIssue`; when the sanitiser holds it, the wrapper
    /// fails and the id leaves this list.
    static let notImplementedYet: Set<String> = [
        // Text typed without accents: an open residual risk of ADR 0023 that #249 must close before release.
        "a-konjunktiv-typed-without-its-umlaut-claims-nothing-de",
        // Whose words and whose title and place a claim gives: open residual risks of ADR 0023 that #249 must close before release.
        "speech-on-the-line-of-the-colon-claims-nothing",
        "the-title-of-a-person-the-claim-names-is-not-the-persons-en", "the-title-of-a-person-the-claim-names-is-not-the-persons-it",
        "the-title-of-a-person-the-claim-names-is-not-the-persons-de", "the-title-of-a-person-the-claim-names-is-not-the-persons-es",
        "the-title-of-a-person-the-claim-names-is-not-the-persons-fr", "the-title-of-a-person-the-claim-names-is-not-the-persons-pt",
    ]

    /// Rows whose desired output the sanitiser does not give, and whose leak the owner accepts as a residual risk (ADR 0023,
    /// Consequences). Each runs in `withKnownIssue`: once a rule closes the leak the wrapper fails, and the id leaves this list.
    static let residualRisks: Set<String> = [
        "a-lowercase-name-in-a-fragment-gives-no-email-en", "a-lowercase-name-in-a-fragment-gives-no-email-it",
        "a-lowercase-name-in-a-fragment-gives-no-email-es", "a-lowercase-name-in-a-fragment-gives-no-email-fr",
        "a-lowercase-name-in-a-fragment-gives-no-email-pt", "a-name-equal-to-an-employer-in-a-fragment-gives-no-email-en",
    ]

    static let all: [GroundingRow] = {
        var rows: [GroundingRow] = []
        rows += quotes()
        rows += contacts()
        rows += prose()
        rows += levels()
        rows += currentJobs()
        rows += clausesExplainEveryWord()
        rows += joinedClauses()
        rows += pulledClauses()
        rows += whatJoiningClausesGive()
        rows += oneYearOneDate()
        rows += figuresKeepTheirNeighbour()
        rows += summariesOfAnotherCV()
        rows += clausesBetweenTwoEntries()
        rows += quotesThatHoldAnEmployerPreposition()
        rows += employerPrepositionsOfTheDescriptionsLanguage()
        rows += wordsOfAnotherLanguageStateNothing()
        rows += titlesInANeutralClause()
        rows += aWordOfStudyingInTheClauseOfATitle()
        rows += negationInProse()
        rows += orderInProse()
        rows += oneClauseOfProse()
        rows += timeWordsInProse()
        rows += wordsAfterAnEmployerPreposition()
        rows += datesFromATimePhrase()
        rows += graduationPhrases()
        rows += achievementsOfGraduating()
        rows += hedgesInProse()
        rows += modalityInProse()
        rows += entriesNeedAFactualMention()
        rows += clausesThatDenyDoubtOrHope()
        rows += factualVerbs()
        rows += purposesAndStatements()
        rows += wordsBeforeTheName()
        rows += coordinatedMentions()
        rows += proseQuotesOneClause()
        rows += proseKeepsWhoDidWhat()
        rows += thePersonIsTheSubject()
        rows += theExplicitSubject()
        rows += theReadersObject()
        rows += languagesThatKeepTheirSubject()
        rows += contactsOfAnotherPerson()
        rows += theShapesOfAContact()
        rows += labelsThatNameSomeoneElse()
        rows += referencesAndTheReachablePerson()
        rows += bareNamesBeforeAVerblessContact()
        rows += namesInAFragmentBeforeAContact()
        rows += hobbiesAreNoSkills()
        rows += skillsTheDescriptionClaims()
        rows += hobbiesOfThePersonAlone()
        rows += factsTheDescriptionWithdraws()
        rows += wishesInAPhrase()
        rows += wishesAfterTheItem()
        rows += personalFieldsOfAClaim()
        rows += acceptedReadingsOfAClaim()
        rows += negationsOfTheAbility()
        rows += deniedLowLevels()
        rows += textWithoutAccents()
        rows += moodsOfSupposition()
        rows += questionsClaimNothing()
        rows += quotedSpeechClaimsNothing()
        rows += speechAfterALineOfAnotherPerson()
        rows += relativeClausesOfAnotherSubject()
        rows += titlesOfAnotherPersonInAClaim()
        rows += intentionWordsAsNouns()
        rows += intentionsInAPhrase()
        rows += everyFactIsThePersons()
        rows += datesOfJobs()
        rows += omittedEmployers()
        rows += omittedEmployersInManyWords()
        rows += titlesOfOthers()
        rows += schoolsAndCertifications()
        rows += entryNamesWithoutAnArticle()
        rows += degreesThatNameNoDegree()
        rows += faithfulExamples()
        rows += theAppExampleKeepsEveryFact()
        rows += realModelProbes()
        return rows
    }()

    // MARK: Facts are quotes (b)

    private static func quotes() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        rows.append(row("quote-employer-never-named",
                        "an employer the description does not name is invented, and a title alone is the person's, not a job",
                        "I'm a nurse.",
                        CVData(experience: [job("nurse", "Globex", from: "2012")]),
                        .exactly(CVData())))
        rows.append(row("quote-school-never-named",
                        "a school the description does not name is invented",
                        "I'm a nurse.",
                        CVData(education: [study("Nursing", at: "Beta University", to: "2014")]),
                        .exactly(CVData())))
        rows.append(row("quote-skill-never-named",
                        "a skill the description does not name is invented",
                        "I know Python.",
                        CVData(skills: [Skill(name: "Python"), Skill(name: "Kotlin")]),
                        .exactly(CVData(skills: [Skill(name: "Python")]))))
        rows.append(row("quote-interest-never-named",
                        "an interest the description does not name is invented",
                        "In my free time I like chess.",
                        CVData(interests: ["Chess", "Skydiving"]),
                        .exactly(CVData(interests: ["Chess"]))))
        rows.append(row("quote-certification-never-named",
                        "a certification the description does not name is invented",
                        "I hold a BLS.",
                        CVData(certifications: [Certification(name: "BLS"), Certification(name: "ACLS")]),
                        .exactly(CVData(certifications: [Certification(name: "BLS")]))))
        rows.append(row("quote-ignores-case-accents-and-spacing",
                        "case, diacritics and white space do not tell a quote from its source",
                        "I studied at the Université de Montréal.",
                        CVData(education: [study(at: "UNIVERSITE  DE MONTREAL")]),
                        .unchanged))
        rows.append(row("quote-is-made-of-whole-words",
                        "Java is not JavaScript",
                        "I know JavaScript.",
                        CVData(skills: [Skill(name: "Java")]),
                        .exactly(CVData())))
        rows.append(row("quote-is-contiguous",
                        "the words of a name must stand together in the description",
                        "I work at the Don Milani school.",
                        CVData(experience: [job("", "Milani Don")]),
                        .exactly(CVData())))
        rows.append(row("quote-may-be-part-of-a-longer-phrase",
                        "a name that is whole words of the description is a quote",
                        "I work at the Don Milani school.",
                        CVData(experience: [job("", "Don Milani")]),
                        .unchanged))
        rows.append(row("quote-name-from-two-people",
                        "John Smith is made of John and of Jane Smith, two different people",
                        "I am John; my manager is Jane Smith.",
                        CVData(personalInfo: person(name: "John Smith")),
                        .exactly(CVData())))
        rows.append(row("quote-name-of-the-person",
                        "the name the person gives stays",
                        "I'm Anna Verdi, a nurse.",
                        CVData(personalInfo: person(name: "Anna Verdi")),
                        .unchanged))
        rows.append(row("quote-name-is-not-the-title",
                        "for \"I'm a nurse\" the model writes Nurse as the name; the ADR is silent, the title stays",
                        "I'm a nurse.",
                        CVData(personalInfo: person(name: "Nurse", title: "Nurse")),
                        .exactly(CVData(personalInfo: person(title: "Nurse")))))
        rows.append(row("quote-the-word-null",
                        "the word null is what the model writes for an empty field; it is no quote",
                        "I'm a nurse in Turin.",
                        CVData(personalInfo: person(name: null, email: null, phone: null, location: "Turin", website: null,
                                                    linkedin: null, github: null, title: null), summary: null),
                        .exactly(CVData(personalInfo: person(location: "Turin")))))
        rows.append(row("quote-job-location-in-its-clause",
                        "a place in the clause that names the employer is the job's place",
                        "I worked as a nurse at Acme in Turin.",
                        CVData(experience: [job("nurse", "Acme", location: "Turin")]),
                        .unchanged))
        rows.append(row("quote-job-location-in-another-sentence",
                        "a place the description gives for the person is not the job's",
                        "I worked as a nurse at Acme. I live in Turin.",
                        CVData(experience: [job("nurse", "Acme", location: "Turin")]),
                        .exactly(CVData(experience: [job("nurse", "Acme")]))))
        rows.append(row("quote-date-not-written",
                        "a year the description does not write is invented",
                        "I worked as a nurse at Acme from 2012.",
                        CVData(experience: [job("nurse", "Acme", from: "2012", to: "2016")]),
                        .exactly(CVData(experience: [job("nurse", "Acme", from: "2012")]))))
        rows.append(row("quote-date-cut-to-the-year",
                        "the ADR is silent on ISO dates: the year the description writes stays, the month and day it lacks go",
                        "I worked as a nurse at Acme from 2012.",
                        CVData(experience: [job("nurse", "Acme", from: "2012-03-01")]),
                        .exactly(CVData(experience: [job("nurse", "Acme", from: "2012")]))))
        rows.append(row("quote-date-month-and-year",
                        "a date written with its month stays as written",
                        "I worked as a nurse at Acme from March 2012 to June 2014.",
                        CVData(experience: [job("nurse", "Acme", from: "March 2012", to: "June 2014")]),
                        .unchanged))
        return rows
    }

    // MARK: Contact details are whole tokens (b)

    private static func contacts() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        rows.append(row("contact-email-whole",
                        "an address the description gives in full stays",
                        "I'm a nurse. My email is anna.verdi@example.com.",
                        CVData(personalInfo: person(email: "anna.verdi@example.com")),
                        .unchanged))
        rows.append(row("contact-email-invented",
                        "an address of an example domain that the description never gives is invented",
                        "I'm a nurse in Turin.",
                        CVData(personalInfo: person(email: "jane.doe@example.com")),
                        .exactly(CVData())))
        rows.append(row("contact-links-invented",
                        "a website and profiles that the description never gives are invented",
                        "I'm a nurse in Turin.",
                        CVData(personalInfo: person(website: "https://example.com", linkedin: "linkedin.com/in/jane-doe",
                                                    github: "github.com/jane-doe")),
                        .exactly(CVData())))
        rows.append(row("contact-phone-invented",
                        "a number that the description never gives is invented",
                        "I'm a nurse in Turin.",
                        CVData(personalInfo: person(phone: "+1 555 010 0000")),
                        .exactly(CVData())))
        rows.append(row("contact-email-inside-a-longer-mailbox",
                        "anna@example.com is the end of joanna@example.com, another mailbox",
                        "Write to me at joanna@example.com.",
                        CVData(personalInfo: person(email: "anna@example.com")),
                        .exactly(CVData())))
        rows.append(row("contact-email-beside-a-longer-mailbox",
                        "write has no object here, so the clause is none of the three shapes of a contact (ADR 82b29702): no email",
                        "Write to joanna@example.com or anna@example.com.",
                        CVData(personalInfo: person(email: "anna@example.com")),
                        .exactly(CVData())))
        rows.append(row("contact-email-beside-a-longer-mailbox-in-a-label",
                        "a mailbox that stands whole beside a longer one stays",
                        "Email: joanna@example.com or anna@example.com.",
                        CVData(personalInfo: person(email: "anna@example.com")),
                        .unchanged))
        rows.append(row("contact-email-after-punctuation",
                        "anna@example.com is the end of sam!anna@example.com, another mailbox",
                        "My address is sam!anna@example.com.",
                        CVData(personalInfo: person(email: "anna@example.com")),
                        .exactly(CVData())))
        rows.append(row("contact-email-digit-of-another-script",
                        "alice1 and alice with the Arabic-Indic digit one are two mailboxes: digits are folded only for numbers",
                        "My address is alice\u{0661}@example.com.",
                        CVData(personalInfo: person(email: "alice1@example.com")),
                        .exactly(CVData())))
        rows.append(row("contact-link-start-of-a-longer-profile",
                        "github.com/alice is the start of github.com/alice-smith, another profile",
                        "My GitHub is github.com/alice-smith.",
                        CVData(personalInfo: person(github: "github.com/alice")),
                        .exactly(CVData())))
        rows.append(row("contact-link-start-of-a-path",
                        "example.com/portfolio is the start of example.com/portfolio/alice",
                        "My portfolio is example.com/portfolio/alice.",
                        CVData(personalInfo: person(website: "example.com/portfolio")),
                        .exactly(CVData())))
        rows.append(row("contact-link-host-of-a-query-address",
                        "example.com is the host of https://example.com?user=alice, which is another address",
                        "My page is https://example.com?user=alice.",
                        CVData(personalInfo: person(website: "example.com")),
                        .exactly(CVData())))
        rows.append(row("contact-link-with-a-query",
                        "an address with a query stays whole when the draft writes it whole",
                        "My page is https://example.com?user=alice.",
                        CVData(personalInfo: person(website: "https://example.com?user=alice")),
                        .unchanged))
        rows.append(row("contact-link-digit-of-another-script",
                        "example.com/user1 is not example.com/user with the Arabic-Indic digit one",
                        "My page is example.com/user\u{0661}.",
                        CVData(personalInfo: person(website: "example.com/user1")),
                        .exactly(CVData())))
        rows.append(row("contact-phone-whole",
                        "a number the description gives in full stays",
                        "Call me on +39 333 123 4567.",
                        CVData(personalInfo: person(phone: "+39 333 123 4567")),
                        .unchanged))
        rows.append(row("contact-phone-other-spacing",
                        "white space does not tell a number from its source",
                        "Call me on +39 333 123 4567.",
                        CVData(personalInfo: person(phone: "+39 3331234567")),
                        .unchanged))
        rows.append(row("contact-phone-truncated",
                        "a number with its last digit cut off is another number",
                        "Call me on +39 333 123 4567.",
                        CVData(personalInfo: person(phone: "+39 333 123 456")),
                        .exactly(CVData())))
        rows.append(row("contact-phone-with-a-digit-more",
                        "a number with a digit more is another number",
                        "Call me on +39 333 123 4567.",
                        CVData(personalInfo: person(phone: "+39 333 123 45678")),
                        .exactly(CVData())))
        rows.append(row("contact-link-start-of-a-longer-linkedin-profile",
                        "linkedin.com/in/anna is the start of linkedin.com/in/anna-verdi, another profile",
                        "My profile is linkedin.com/in/anna-verdi.",
                        CVData(personalInfo: person(linkedin: "linkedin.com/in/anna")),
                        .exactly(CVData())))
        rows.append(row("contact-link-query-digit-of-another-script",
                        "example.org/?id=1 is not example.org/?id= with the Arabic-Indic digit one",
                        "My page is example.org/?id=\u{0661}.",
                        CVData(personalInfo: person(website: "example.org/?id=1")),
                        .exactly(CVData())))

        let pairs: [(given: String, claimed: String)] = [
            ("anna@example.com", "joanna@example.com"), ("anna@example.com", "anna@example.co"),
            ("anna@example.com", "anna@example.com.au"), ("anna@mail.example.com", "anna@example.com"),
            ("anna@example.com", "anna@mail.example.com"), ("anna.rossi@example.com", "anna@example.com"),
        ]
        for (index, pair) in pairs.enumerated() {
            rows.append(row("contact-email-part-of-another-\(index + 1)",
                            "\(pair.claimed) is not \(pair.given): an address is whole, not a part of another or with a part more",
                            "My email is \(pair.given), write any time.",
                            CVData(personalInfo: person(email: pair.claimed)),
                            .exactly(CVData())))
        }
        return rows
    }

    // MARK: Prose is made of the description's words (d)

    private static func prose() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        let nights = "I'm a nurse in Turin. I work nights at the San Raffaele hospital."

        rows.append(row("prose-summary-words-of-the-description",
                        "a sentence made of the words of the description stays",
                        nights,
                        CVData(summary: "A nurse in Turin. I work nights at the San Raffaele hospital."),
                        .unchanged))
        rows.append(row("prose-summary-new-words",
                        "a paraphrase holds words the description does not use, so it is dropped",
                        nights,
                        CVData(summary: "A caring professional who looks after patients through the night."),
                        .exactly(CVData())))
        rows.append(row("prose-summary-sentence-by-sentence",
                        "a sentence is kept or dropped by itself",
                        nights,
                        CVData(summary: "A nurse in Turin. A dedicated professional. I work nights at the San Raffaele hospital."),
                        .exactly(CVData(summary: "A nurse in Turin. I work nights at the San Raffaele hospital."))))
        rows.append(row("prose-summary-lemma",
                        "the words of this sentence stand in two sentences of the description: a clause is explained by one clause alone",
                        "I'm a nurse. I look after hospitals.",
                        CVData(summary: "A nurse who looks after a hospital."),
                        .exactly(CVData())))
        rows.append(row("prose-summary-lemma-in-one-clause",
                        "no lemma is used: looked is not looks and hospital is not hospitals, so a change of inflection is no quote",
                        "I'm a nurse who looks after hospitals.",
                        CVData(summary: "A nurse who looked after a hospital."),
                        .exactly(CVData())))
        rows.append(row("prose-summary-holds-no-number",
                        "a summary holds no number, not even one the description gives",
                        "I'm a nurse. I trained 3 new nurses.",
                        CVData(summary: "A nurse. I trained 3 new nurses."),
                        .exactly(CVData(summary: "A nurse."))))
        rows.append(row("prose-summary-invented-number",
                        "ten years of experience is invented",
                        "I'm a nurse in Turin.",
                        CVData(summary: "A nurse in Turin. Over 10 years of experience."),
                        .exactly(CVData(summary: "A nurse in Turin."))))
        rows.append(row("prose-summary-invented-email",
                        "an address the description does not give is invented",
                        "I'm a nurse in Turin.",
                        CVData(summary: "A nurse in Turin. Write to nurse@invented.com."),
                        .exactly(CVData(summary: "A nurse in Turin."))))
        rows.append(row("prose-summary-invented-phone",
                        "a number the description does not give is invented",
                        "I'm a nurse in Turin.",
                        CVData(summary: "A nurse in Turin. Call 333 123 4567."),
                        .exactly(CVData(summary: "A nurse in Turin."))))
        rows.append(row("prose-summary-invented-link",
                        "a link the description does not give is invented",
                        "I'm a nurse in Turin.",
                        CVData(summary: "A nurse in Turin. See invented.dev/nurse."),
                        .exactly(CVData(summary: "A nurse in Turin."))))
        rows.append(row("prose-summary-invented-names",
                        "Jane Smith and Globex are names the description does not give",
                        "I worked as a nurse at Acme.",
                        CVData(summary: "Worked with Jane Smith at Globex."),
                        .exactly(CVData())))
        rows.append(row("prose-role-words-of-its-clause",
                        "a role made of the words of the clause that backs the job stays",
                        "I worked as a nurse at Acme.",
                        CVData(experience: [job("nurse", "Acme", description: "Worked as a nurse at Acme.")]),
                        .unchanged))
        rows.append(row("prose-role-invented-names",
                        "Jane Smith and Globex are names the description does not give",
                        "I worked as a nurse at Acme.",
                        CVData(experience: [job("nurse", "Acme", description: "Worked with Jane Smith at Globex.")]),
                        .exactly(CVData(experience: [job("nurse", "Acme")]))))
        rows.append(row("prose-role-invented-names-in-lower-case",
                        "letter case plays no part: jane smith and globex are still names the description does not give",
                        "I worked as a nurse at Acme.",
                        CVData(experience: [job("nurse", "Acme", description: "worked with jane smith at globex.")]),
                        .exactly(CVData(experience: [job("nurse", "Acme")]))))
        rows.append(row("prose-achievement-invented-names",
                        "an achievement is made of the words of the clauses that back its job, too",
                        "I worked as a nurse at Acme.",
                        CVData(experience: [job("nurse", "Acme", achievements: ["Worked with Jane Smith at Globex"])]),
                        .exactly(CVData(experience: [job("nurse", "Acme")]))))
        rows.append(row("prose-role-invented-place",
                        "Milan is a place the description does not give",
                        "I worked as a nurse at Acme.",
                        CVData(experience: [job("nurse", "Acme", description: "Worked as a nurse at Acme in Milan.")]),
                        .exactly(CVData(experience: [job("nurse", "Acme")]))))
        rows.append(row("prose-role-words-of-another-job",
                        "a job's text uses the words of its own clauses: nurse stands in the clause of Beta, not in Acme's",
                        "I worked as a cook at Acme. I worked as a nurse at Beta.",
                        CVData(experience: [job("cook", "Acme", description: "Worked as a nurse."),
                                            job("nurse", "Beta", description: "Worked as a nurse at Beta.")]),
                        .exactly(CVData(experience: [job("cook", "Acme"), job("nurse", "Beta", description: "Worked as a nurse at Beta.")]))))
        rows.append(row("prose-role-names-another-employer",
                        "a sentence of a job's text that names another employer is not about this job",
                        "I worked as a nurse at Acme. Later I moved to Beta.",
                        CVData(experience: [job("nurse", "Acme", description: "Worked as a nurse at Acme. Later moved to Beta."),
                                            job("", "Beta")]),
                        .exactly(CVData(experience: [job("nurse", "Acme", description: "Worked as a nurse at Acme."), job("", "Beta")]))))

        rows.append(row("prose-summary-given-contact",
                        "write to nurse@example.com leaves out me at from its clause: it is no quote, and the first sentence stays",
                        "I'm a nurse. Write to me at nurse@example.com.",
                        CVData(summary: "A nurse. Write to nurse@example.com."),
                        .exactly(CVData(summary: "A nurse."))))
        rows.append(row("prose-summary-given-contact-quoted",
                        "the clause of the description, address and all, is a quote: the sentence stays",
                        "I'm a nurse. Write to me at nurse@example.com.",
                        CVData(summary: "A nurse. Write to me at nurse@example.com."),
                        .unchanged))
        rows.append(row("prose-summary-address-with-a-digit-of-another-script",
                        "alice1@example.com is not the address with the Arabic-Indic digit one that the description gives",
                        "I'm a nurse. Write to alice\u{0661}@example.com.",
                        CVData(summary: "A nurse. Write to alice1@example.com."),
                        .exactly(CVData(summary: "A nurse."))))
        rows.append(row("prose-summary-address-with-a-digit-of-another-script-in-the-draft",
                        "the address with the Arabic-Indic digit one is not alice1@example.com, which the description gives",
                        "I'm a nurse. Write to alice1@example.com.",
                        CVData(summary: "A nurse. Write to alice\u{0661}@example.com."),
                        .exactly(CVData(summary: "A nurse."))))
        rows.append(row("prose-summary-number-in-another-script",
                        "99 people written with full-width digits is invented, as 99 is",
                        "I'm a nurse and I led people.",
                        CVData(summary: "Led \u{FF19}\u{FF19} people."),
                        .exactly(CVData())))

        let paraphrases: [(language: String, summary: String)] = [
            ("en", "A caring teacher who loves her pupils."),
            ("it", "Un'insegnante attenta ai suoi alunni."),
            ("de", "Eine engagierte Lehrerin."),
            ("es", "Una maestra dedicada a sus alumnos."),
            ("fr", "Une institutrice dévouée à ses élèves."),
            ("pt", "Uma professora dedicada aos seus alunos."),
        ]
        for paraphrase in paraphrases {
            rows.append(row("paraphrase-\(paraphrase.language)",
                            "the summary a model writes for the app's example is a paraphrase: its words are not the description's",
                            AppExample.text(in: paraphrase.language), CVData(summary: paraphrase.summary), .exactly(CVData()),
                            language: paraphrase.language))
        }

        let invented: [(language: String, description: String, title: String, company: String, text: String)] = [
            ("it", "Ho lavorato come infermiera presso Acme.", "infermiera", "Acme", "Ho lavorato con Jane Smith presso Globex."),
            ("de", "Ich habe als Krankenschwester bei Acme gearbeitet.", "Krankenschwester", "Acme", "Ich habe mit Jane Smith bei Globex gearbeitet."),
            ("es", "Trabajé como enfermera en Acme.", "enfermera", "Acme", "Trabajé con Jane Smith en Globex."),
            ("fr", "J'ai travaillé comme infirmière chez Acme.", "infirmière", "Acme", "J'ai travaillé avec Jane Smith chez Globex."),
            ("pt", "Trabalhei como enfermeira na Acme.", "enfermeira", "Acme", "Trabalhei com Jane Smith na Globex."),
        ]
        for variant in invented {
            rows.append(row("prose-role-invented-names-\(variant.language)",
                            "the same in \(variant.language): Jane Smith and Globex are names the description does not give",
                            variant.description,
                            CVData(experience: [job(variant.title, variant.company, description: variant.text)]),
                            .exactly(CVData(experience: [job(variant.title, variant.company)])),
                            language: variant.language))
        }

        rows += numbersInProse()
        return rows
    }

    /// A figure of a role is backed by the same number in the clause of the job, read as a number and not as digits.
    private static func numbersInProse() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        rows.append(row("number-in-another-script",
                        "99 written with full-width digits is invented, as 99 is",
                        "I worked as a nurse at Acme for 9 years.",
                        CVData(experience: [job("nurse", "Acme", description: "Worked as a nurse at Acme for \u{FF19}\u{FF19} years.")]),
                        .exactly(CVData(experience: [job("nurse", "Acme")]))))
        rows.append(row("number-same-in-another-script",
                        "digits of any script are the same number: a full-width 9 in the description backs a 9",
                        "I worked as a nurse at Acme for \u{FF19} years.",
                        CVData(experience: [job("nurse", "Acme", description: "Worked as a nurse at Acme for 9 years.")]),
                        .unchanged))
        rows.append(row("number-35-for-3.5",
                        "35 is not 3.5",
                        "I worked as a nurse at Acme for 3.5 years.",
                        CVData(experience: [job("nurse", "Acme", description: "Worked as a nurse at Acme for 35 years.")]),
                        .exactly(CVData(experience: [job("nurse", "Acme")]))))
        rows.append(row("number-3.5-for-35",
                        "3.5 is not 35",
                        "I worked as a nurse at Acme for 35 years.",
                        CVData(experience: [job("nurse", "Acme", description: "Worked as a nurse at Acme for 3.5 years.")]),
                        .exactly(CVData(experience: [job("nurse", "Acme")]))))
        rows.append(row("number-3.5-as-written",
                        "a decimal number the description writes stays",
                        "I worked as a nurse at Acme for 3.5 years.",
                        CVData(experience: [job("nurse", "Acme", description: "Worked as a nurse at Acme for 3.5 years.")]),
                        .unchanged))
        rows.append(row("number-1000-for-1.000",
                        "1000 is not 1.000: a separator is not read away",
                        "I worked as a nurse at Acme for 1.000 days.",
                        CVData(experience: [job("nurse", "Acme", description: "Worked as a nurse at Acme for 1000 days.")]),
                        .exactly(CVData(experience: [job("nurse", "Acme")]))))
        rows.append(row("number-1.000-for-1000",
                        "1.000 is not 1000: a separator is not invented",
                        "I worked as a nurse at Acme for 1000 days.",
                        CVData(experience: [job("nurse", "Acme", description: "Worked as a nurse at Acme for 1.000 days.")]),
                        .exactly(CVData(experience: [job("nurse", "Acme")]))))
        rows.append(row("number-1.000-as-written",
                        "a number with a separator stays when the description writes it so",
                        "I worked as a nurse at Acme for 1.000 days.",
                        CVData(experience: [job("nurse", "Acme", description: "Worked as a nurse at Acme for 1.000 days.")]),
                        .unchanged))
        rows.append(row("number-in-an-achievement",
                        "a figure the clause of the job does not give is invented",
                        "I worked as a nurse at Acme for 9 years.",
                        CVData(experience: [job("nurse", "Acme", achievements: ["Worked as a nurse at Acme for 99 years", "Worked as a nurse at Acme for 9 years"])]),
                        .exactly(CVData(experience: [job("nurse", "Acme", achievements: ["Worked as a nurse at Acme for 9 years"])]))))
        return rows
    }

    // MARK: Levels are stated, not denied (b)

    private static func levels() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        rows.append(row("level-skill-negated",
                        "not an expert denies the level; the skill stays without it",
                        "I am not an expert in Swift.",
                        CVData(skills: [Skill(name: "Swift", level: .expert)]),
                        .exactly(CVData(skills: [Skill(name: "Swift")]))))
        rows.append(row("level-skill-of-the-neighbour",
                        "the level of Swift is not the level of Python",
                        "I know Python (expert), Swift (advanced) and Go (beginner).",
                        CVData(skills: [Skill(name: "Python", level: .advanced)]),
                        .exactly(CVData(skills: [Skill(name: "Python")]))))
        rows.append(row("level-language-negated",
                        "not fluent denies the level; a language without a level goes",
                        "I speak Italian (native). My English is not fluent.",
                        CVData(languages: [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .c2)]),
                        .exactly(CVData(languages: [Language(name: "Italian", proficiency: .native)]))))
        rows.append(row("level-language-fluent",
                        "fluent states C1 or C2",
                        "My English is fluent.",
                        CVData(languages: [Language(name: "English", proficiency: .c1)]),
                        .unchanged))
        rows.append(row("level-language-fluent-is-not-native",
                        "fluent does not state native",
                        "My English is fluent.",
                        CVData(languages: [Language(name: "English", proficiency: .native)]),
                        .exactly(CVData())))
        rows.append(row("level-language-without-a-level",
                        "a language the description gives without a level goes: any level would be made up",
                        "I speak French.",
                        CVData(languages: [Language(name: "French", proficiency: .b2)]),
                        .exactly(CVData())))
        rows.append(row("level-language-of-the-neighbour",
                        "the A2 of French is not the level of English, which the description gives as B2",
                        "I speak Italian (native), French (A2) and English (B2).",
                        CVData(languages: [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .a2)]),
                        .exactly(CVData(languages: [Language(name: "Italian", proficiency: .native)]))))

        let denied: [(language: String, description: String, kept: String, denied: String)] = [
            ("it", "Parlo italiano (madrelingua). Il mio inglese non è fluente.", "italiano", "inglese"),
            ("de", "Ich spreche Italienisch (Muttersprache). Mein Englisch ist nicht fließend.", "Italienisch", "Englisch"),
            ("es", "Hablo italiano (nativo). Mi inglés no es fluido.", "italiano", "inglés"),
            ("fr", "Je parle italien (langue maternelle). Mon anglais n'est pas courant.", "italien", "anglais"),
            ("pt", "Falo italiano (nativo). Meu inglês não é fluente.", "italiano", "inglês"),
        ]
        for variant in denied {
            let draft = CVData(languages: [Language(name: variant.kept, proficiency: .native), Language(name: variant.denied, proficiency: .c2)])
            rows.append(row("level-language-negated-\(variant.language)",
                            "the same denial in \(variant.language): the denied language goes, the stated one stays",
                            variant.description, draft,
                            .exactly(CVData(languages: [Language(name: variant.kept, proficiency: .native)])),
                            language: variant.language))
        }
        return rows
    }

    // MARK: A job is current only if its own clause says so (c)

    private static func currentJobs() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        rows.append(row("current-not-said",
                        "a job the description puts in the past is not current",
                        "I worked at Acme in 2012.",
                        CVData(experience: [job("", "Acme", from: "2012", current: true)]),
                        .exactly(CVData(experience: [job("", "Acme", from: "2012")]))))
        rows.append(row("current-since-a-year",
                        "since a year, with one year in the clause, says the job goes on",
                        "Since 2019 I work at Acme.",
                        CVData(experience: [job("", "Acme", from: "2019", current: true)]),
                        .unchanged))
        rows.append(row("current-with-a-present-word",
                        "currently in the clause of the job says it goes on",
                        "I currently work at Acme.",
                        CVData(experience: [job("", "Acme", current: true)]),
                        .unchanged))
        rows.append(row("current-word-of-another-statement",
                        "I paint now says nothing of Acme: the present marker is in another clause",
                        "I paint now, I worked at Acme in 2012.",
                        CVData(experience: [job("", "Acme", from: "2012", current: true)]),
                        .exactly(CVData(experience: [job("", "Acme", from: "2012")]))))
        rows.append(row("current-word-of-another-employer-with-a-shared-title",
                        "a title two jobs share backs nothing: Beta's now does not make Acme current",
                        "I worked as a cook at Acme from 2012 to 2016. I am a cook at Beta now.",
                        CVData(experience: [job("cook", "Acme", from: "2012", to: "2016", current: true), job("cook", "Beta", current: true)]),
                        .exactly(CVData(experience: [job("cook", "Acme", from: "2012", to: "2016"), job("cook", "Beta", current: true)]))))
        rows.append(row("current-word-after-an-ended-job",
                        "I worked at Acme from 2012 to 2016, and now cook at Beta: the now is Beta's",
                        "I worked at Acme from 2012 to 2016, and now cook at Beta.",
                        CVData(experience: [job("", "Acme", from: "2012", to: "2016", current: true), job("cook", "Beta", current: true)]),
                        .exactly(CVData(experience: [job("", "Acme", from: "2012", to: "2016"), job("cook", "Beta", current: true)]))))

        let paint: [(language: String, description: String)] = [
            ("it", "Dipingo adesso, ho lavorato presso Acme nel 2012."),
            ("de", "Ich male jetzt, ich habe 2012 bei Acme gearbeitet."),
            ("es", "Pinto ahora, trabajé en Acme en 2012."),
            ("fr", "Je peins maintenant, j'ai travaillé chez Acme en 2012."),
            ("pt", "Pinto agora, trabalhei na Acme em 2012."),
        ]
        for variant in paint {
            rows.append(row("current-word-of-another-statement-\(variant.language)",
                            "the same in \(variant.language): a present marker in another clause does not make Acme current",
                            variant.description,
                            CVData(experience: [job("", "Acme", from: "2012", current: true)]),
                            .safe(never: [], absent: ["experience[0].current"], keeping: ["experience[0].company": "Acme"]),
                            language: variant.language))
        }
        return rows
    }

    // MARK: A clause backs a job only if every word of it is explained (c)

    private static func clausesExplainEveryWord() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        rows.append(row("clause-words-all-explained",
                        "a clause of function words, a verb of a CV, a year and the employer backs the year",
                        "In 2012 I worked at Acme.",
                        CVData(experience: [job("", "Acme", from: "2012")]),
                        .unchanged))
        rows.append(row("clause-words-of-the-title",
                        "the job's title explains the word nurse of its clause",
                        "In 2012 I worked as a nurse at Acme.",
                        CVData(experience: [job("nurse", "Acme", from: "2012")]),
                        .unchanged))
        rows.append(row("clause-with-a-descriptive-word",
                        "a busy hospital is descriptive: no word of the vocabulary or of the job's quotes explains it, so the clause backs nothing",
                        "In 2012 I worked at Acme in a busy hospital.",
                        CVData(experience: [job("", "Acme", from: "2012")]),
                        .exactly(CVData(experience: [job("", "Acme")]))))
        rows.append(row("clause-words-of-the-jobs-own-quote",
                        "the same words are explained when they lie inside the job's own location",
                        "In 2012 I worked at Acme in a busy hospital.",
                        CVData(experience: [job("", "Acme", from: "2012", location: "a busy hospital")]),
                        .unchanged))
        rows.append(row("clause-with-a-person",
                        "Jane Smith is a person: no word of the vocabulary or of the job's quotes explains her, so the clause backs nothing",
                        "In 2012 I worked at Acme with Jane Smith.",
                        CVData(experience: [job("", "Acme", from: "2012")]),
                        .exactly(CVData(experience: [job("", "Acme")]))))
        rows.append(row("clause-with-a-person-in-lower-case",
                        "letter case plays no part: jane smith is a person in lower case as well",
                        "in 2012 i worked at acme with jane smith.",
                        CVData(experience: [job("", "acme", from: "2012")]),
                        .exactly(CVData(experience: [job("", "acme")]))))
        rows.append(row("clause-with-another-employer",
                        "Beta is another employer, which the draft leaves out: the clause that holds it backs nothing of Acme",
                        "In 2012 I moved from Beta to Acme.",
                        CVData(experience: [job("", "Acme", from: "2012")]),
                        .exactly(CVData(experience: [job("", "Acme")]))))
        rows.append(row("clause-with-another-employer-in-lower-case",
                        "beta in lower case is another employer as well",
                        "In 2012 I moved from beta to Acme.",
                        CVData(experience: [job("", "Acme", from: "2012")]),
                        .exactly(CVData(experience: [job("", "Acme")]))))
        return rows
    }

    // MARK: A clause that names no employer joins the clause next to it (c)

    /// A clause that names no employer backs job E when it stands in the same sentence as, and next to, a clause that
    /// backs E, and every one of its words is explained by the closed vocabulary or by E's own quotes. The same rows in
    /// English, Italian and German.
    private static func joinedClauses() -> [GroundingRow] {
        typealias Variant = (
            language: String, before: String, after: String, title: String, quoted: String, achievement: String,
            paraphrase: String, neighbour: String, neighbourAchievement: String, otherSentence: String, present: String
        )
        var variants: [Variant] = []
        variants.append((
            "en", "Before that, from 2012 to 2016, I worked as a nurse at Acme.", "I worked as a nurse at Acme, from 2012 to 2016.", "nurse",
            "Since 2016 I have worked at Acme, where I trained 3 new teachers.", "trained 3 new teachers", "Trained 3 teachers",
            "At Acme in 2012 I worked, and beta employed me to train 9 nurses.", "train 9 nurses",
            "I worked at Acme. That was from 2012 to 2016.", "I work at Acme, since 2019."))
        variants.append((
            "it", "Prima, dal 2012 al 2016, ho lavorato come infermiera presso Acme.", "Ho lavorato come infermiera presso Acme, dal 2012 al 2016.",
            "infermiera", "Dal 2016 lavoro presso Acme, dove ho formato 3 nuovi insegnanti.", "ho formato 3 nuovi insegnanti",
            "Ho formato 3 insegnanti", "Presso Acme nel 2012 ho lavorato, e beta mi ha assunta per formare 9 infermieri.",
            "formare 9 infermieri", "Ho lavorato presso Acme. Era dal 2012 al 2016.", "Lavoro presso Acme, dal 2019."))
        variants.append((
            "de", "Davor, von 2012 bis 2016, habe ich als Krankenschwester bei Acme gearbeitet.",
            "Ich habe als Krankenschwester bei Acme gearbeitet, von 2012 bis 2016.", "Krankenschwester",
            "Seit 2016 arbeite ich bei Acme, wo ich 3 neue Lehrkräfte eingearbeitet habe.", "3 neue Lehrkräfte eingearbeitet",
            "3 Lehrkräfte eingearbeitet", "Bei Acme habe ich 2012 gearbeitet, und beta hat mich eingestellt, um 9 Pflegekräfte auszubilden.",
            "9 Pflegekräfte auszubilden", "Ich habe bei Acme gearbeitet. Das war von 2012 bis 2016.", "Ich arbeite bei Acme, seit 2019."))

        var rows: [GroundingRow] = []
        for v in variants {
            let years = job(v.title, "Acme", from: "2012", to: "2016")
            rows.append(row("joined-clause-before-\(v.language)",
                            "a clause of years before the clause of the employer joins it: the years stay",
                            v.before, CVData(experience: [years]), .unchanged, language: v.language))
            rows.append(row("joined-clause-after-\(v.language)",
                            "a clause of years after the clause of the employer joins it: the years stay",
                            v.after, CVData(experience: [years]), .unchanged, language: v.language))
            let beginsWithAVerb = v.language != "de"
            let quotedOutcome: Outcome = beginsWithAVerb ? .unchanged : .exactly(CVData(experience: [job("", "Acme", from: "2016", current: true)]))
            rows.append(row("joined-clause-quoted-achievement-\(v.language)",
                            beginsWithAVerb
                                ? "a clause after the employer's whose words the draft quotes in an achievement that begins with a verb joins it: the achievement stays"
                                : "the German quote ends with its participle: it does not begin with a CV verb, so it explains nothing and the achievement goes",
                            v.quoted, CVData(experience: [job("", "Acme", from: "2016", current: true, achievements: [v.achievement])]),
                            quotedOutcome, language: v.language))
            rows.append(row("joined-clause-paraphrased-achievement-\(v.language)",
                            "the same clause joins nothing when the draft's achievement is not a quote of it: its words are not explained",
                            v.quoted, CVData(experience: [job("", "Acme", from: "2016", current: true, achievements: [v.paraphrase])]),
                            .exactly(CVData(experience: [job("", "Acme", from: "2016", current: true)])), language: v.language))
            rows.append(row("joined-clause-with-an-unexplained-word-\(v.language)",
                            "a neighbour that holds beta, a word nothing explains, joins nothing, whatever the draft quotes",
                            v.neighbour, CVData(experience: [job("", "Acme", from: "2012", achievements: [v.neighbourAchievement])]),
                            .exactly(CVData(experience: [job("", "Acme", from: "2012")])), language: v.language))
            rows.append(row("joined-clause-in-another-sentence-\(v.language)",
                            "a clause of years in the next sentence joins nothing",
                            v.otherSentence, CVData(experience: [job("", "Acme", from: "2012", to: "2016")]),
                            .exactly(CVData(experience: [job("", "Acme")])), language: v.language))
            rows.append(row("joined-clause-present-\(v.language)",
                            "a since-clause next to the employer's joins it: the job is current",
                            v.present, CVData(experience: [job("", "Acme", from: "2019", current: true)]), .unchanged, language: v.language))
        }
        return rows
    }

    // MARK: A draft cannot pull another employer's clause in (c)

    /// A joining clause is explained only by the closed vocabulary and by an achievement quote of the job that lies inside
    /// it and holds no employer preposition. The title, the location and the other quotes never explain one. So a draft
    /// that copies Beta, with its preposition, into an achievement or a location cannot make Beta's clause Acme's.
    private static func pulledClauses() -> [GroundingRow] {
        typealias Variant = (language: String, description: String, quote: String)
        var variants: [Variant] = []
        variants.append(("en", "At Acme in 2012 I worked for 3 years and at Beta in 2019 I worked for 5 years.",
                         "at Beta in 2019 I worked for 5 years"))
        variants.append(("it", "Presso Acme nel 2012 ho lavorato per 3 anni e presso Beta nel 2019 ho lavorato per 5 anni.",
                         "presso Beta nel 2019 ho lavorato per 5 anni"))
        variants.append(("de", "Bei Acme habe ich 2012 3 Jahre gearbeitet und bei Beta habe ich 2019 5 Jahre gearbeitet.",
                         "bei Beta habe ich 2019 5 Jahre gearbeitet"))

        var rows: [GroundingRow] = []
        let ownFacts = CVData(experience: [job("", "Acme", from: "2012")])
        for v in variants {
            rows.append(row("pulled-clause-by-an-achievement-\(v.language)",
                            "an achievement that copies Beta with its preposition explains nothing: Beta's year is not Acme's",
                            v.description, CVData(experience: [job("", "Acme", from: "2012", to: "2019", achievements: [v.quote])]),
                            .exactly(ownFacts), language: v.language))
            rows.append(row("pulled-clause-by-a-location-\(v.language)",
                            "a location Beta explains no clause: Beta's year is not Acme's, and the location goes",
                            v.description, CVData(experience: [job("", "Acme", from: "2012", to: "2019", location: "Beta")]),
                            .exactly(ownFacts), language: v.language))
        }
        rows.append(row("joined-clause-title-does-not-explain",
                        "nurse, the job's title, does not explain a joining clause: the 2012 of that clause is not the job's",
                        "I worked at Acme, and as a nurse in 2012.",
                        CVData(experience: [job("nurse", "Acme", from: "2012")]),
                        .exactly(CVData(experience: [job("nurse", "Acme")]))))
        rows.append(row("joined-clause-location-does-not-explain",
                        "Turin, the job's location, does not explain a joining clause: the place goes, the year of the first clause stays",
                        "In 2012 I worked at Acme, and in Turin.",
                        CVData(experience: [job("", "Acme", from: "2012", location: "Turin")]),
                        .exactly(CVData(experience: [job("", "Acme", from: "2012")]))))
        return rows
    }

    // MARK: What a joining clause gives (c)

    /// A joining clause gives dates and "current" only as a pure time phrase: closed-vocabulary words and years. One that
    /// an achievement quote explains gives that achievement alone, never a date: the quote must begin with a CV verb.
    private static func whatJoiningClausesGive() -> [GroundingRow] {
        typealias Variant = (
            language: String, employedMe: String, employedQuote: String, withYear: String, yearQuote: String, yearQuoteToTheEnd: String
        )
        var variants: [Variant] = []
        variants.append(("en", "At Acme in 2012 I worked, and Beta employed me in 2019.", "Beta employed me",
                         "I worked at Acme and trained 3 new teachers in 2018.", "trained 3 new teachers",
                         "trained 3 new teachers in 2018"))
        variants.append(("it", "Presso Acme nel 2012 ho lavorato, e Beta mi ha assunta nel 2019.", "Beta mi ha assunta",
                         "Ho lavorato presso Acme e ho formato 3 nuovi insegnanti nel 2018.", "ho formato 3 nuovi insegnanti",
                         "ho formato 3 nuovi insegnanti nel 2018"))
        variants.append(("de", "Bei Acme habe ich 2012 gearbeitet, und Beta hat mich 2019 eingestellt.", "Beta hat mich",
                         "Ich habe bei Acme gearbeitet und leitete 3 neue Lehrkräfte im Jahr 2018.", "leitete 3 neue Lehrkräfte",
                         "leitete 3 neue Lehrkräfte im Jahr 2018"))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("joined-clause-employed-me-\(v.language)",
                            "an achievement that begins with Beta is no verb: the clause of Beta joins nothing, and 2019 is not Acme's",
                            v.employedMe,
                            CVData(experience: [job("", "Acme", from: "2012", to: "2019", achievements: [v.employedQuote])]),
                            .exactly(CVData(experience: [job("", "Acme", from: "2012")])), language: v.language))
            rows.append(row("joined-clause-achievement-gives-no-year-\(v.language)",
                            "the quote stops before the year that ends its clause: it is no quote, so the achievement goes, and the year is not the job's",
                            v.withYear,
                            CVData(experience: [job("", "Acme", to: "2018", achievements: [v.yearQuote])]),
                            .exactly(CVData(experience: [job("", "Acme")])), language: v.language))
            rows.append(row("joined-clause-achievement-with-its-year-\(v.language)",
                            "a clause explained by a quote that runs to its end gives the achievement and nothing else: its year is not the job's",
                            v.withYear,
                            CVData(experience: [job("", "Acme", to: "2018", achievements: [v.yearQuoteToTheEnd])]),
                            .exactly(CVData(experience: [job("", "Acme", achievements: [v.yearQuoteToTheEnd])])), language: v.language))
        }
        rows.append(row("joined-clause-achievement-must-begin-with-a-verb-en",
                        "a quote that begins with a number explains nothing: the clause joins nothing and the achievement goes",
                        "Since 2016 I have worked at Acme, where I trained 3 new teachers.",
                        CVData(experience: [job("", "Acme", from: "2016", current: true, achievements: ["3 new teachers"])]),
                        .exactly(CVData(experience: [job("", "Acme", from: "2016", current: true)]))))
        rows.append(row("joined-clause-achievement-must-begin-with-a-verb-it",
                        "the same in Italian: 3 nuovi insegnanti begins with a number",
                        "Dal 2016 lavoro presso Acme, dove ho formato 3 nuovi insegnanti.",
                        CVData(experience: [job("", "Acme", from: "2016", current: true, achievements: ["3 nuovi insegnanti"])]),
                        .exactly(CVData(experience: [job("", "Acme", from: "2016", current: true)])), language: "it"))
        rows.append(row("joined-clause-quoted-achievement-verb-first-de",
                        "a German clause with its verb first (after und) can be quoted from the verb: the achievement stays",
                        "Seit 2016 arbeite ich bei Acme und leite 3 neue Lehrkräfte.",
                        CVData(experience: [job("", "Acme", from: "2016", current: true, achievements: ["leite 3 neue Lehrkräfte"])]),
                        .unchanged, language: "de"))
        return rows
    }

    // MARK: A number keeps its neighbour (d)

    /// A number of a role description or an achievement stands next to the same word as in a backing clause: the word after
    /// it. "3 courses with 5 students" does not keep "5 courses with 3 students".
    private static func figuresKeepTheirNeighbour() -> [GroundingRow] {
        typealias Variant = (
            language: String, description: String, role: String, swappedRole: String, achievement: String, swappedAchievement: String
        )
        var variants: [Variant] = []
        variants.append(("en", "Since 2016 I have taught 3 courses with 5 students at Acme.", "Taught 3 courses with 5 students.",
                         "Taught 5 courses with 3 students.", "taught 3 courses with 5 students", "taught 5 courses with 3 students"))
        variants.append(("it", "Dal 2016 insegno 3 corsi con 5 studenti presso Acme.", "Insegno 3 corsi con 5 studenti.",
                         "Insegno 5 corsi con 3 studenti.", "insegno 3 corsi con 5 studenti", "insegno 5 corsi con 3 studenti"))
        variants.append(("de", "Seit 2016 unterrichte ich bei Acme 3 Kurse mit 5 Studenten.", "Ich unterrichte 3 Kurse mit 5 Studenten.",
                         "Ich unterrichte 5 Kurse mit 3 Studenten.", "3 Kurse mit 5 Studenten", "5 Kurse mit 3 Studenten"))
        variants.append(("es", "Desde 2016 enseño 3 cursos con 5 estudiantes en Acme.", "Enseño 3 cursos con 5 estudiantes.",
                         "Enseño 5 cursos con 3 estudiantes.", "enseño 3 cursos con 5 estudiantes", "enseño 5 cursos con 3 estudiantes"))
        variants.append(("pt", "Desde 2016 leciono 3 cursos com 5 estudantes na Acme.", "Leciono 3 cursos com 5 estudantes.",
                         "Leciono 5 cursos com 3 estudantes.", "leciono 3 cursos com 5 estudantes", "leciono 5 cursos com 3 estudantes"))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("figures-in-order-\(v.language)",
                            "the figures are in order but the text leaves out the clause's start and end (since 2016, at Acme): it is no quote, so it goes",
                            v.description,
                            CVData(experience: [job("", "Acme", from: "2016", current: true, description: v.role, achievements: [v.achievement])]),
                            .exactly(CVData(experience: [job("", "Acme", from: "2016", current: true)])), language: v.language))
            rows.append(row("figures-quoted-\(v.language)",
                            "the whole clause is a quote, figures and all: the role text and the achievement stay",
                            v.description,
                            CVData(experience: [job("", "Acme", from: "2016", current: true, description: v.description,
                                                    achievements: [String(v.description.dropLast())])]),
                            .unchanged, language: v.language))
            rows.append(row("figures-swapped-\(v.language)",
                            "the same words with the figures swapped say something else: the role text and the achievement go",
                            v.description,
                            CVData(experience: [job("", "Acme", from: "2016", current: true, description: v.swappedRole,
                                                    achievements: [v.swappedAchievement])]),
                            .exactly(CVData(experience: [job("", "Acme", from: "2016", current: true)])), language: v.language))
        }
        // The same with nurses, which the vocabulary does not hold: the job's title explains the word.
        let nurses = "Since 2016 I have managed 3 nurses for 5 years at Acme."
        rows.append(row("figures-in-order-nurses-en",
                        "the figures are in order but the text leaves out the clause's start and end: it is no quote, so it goes",
                        nurses,
                        CVData(experience: [job("nurses", "Acme", from: "2016", current: true, description: "Managed 3 nurses for 5 years.",
                                                achievements: ["managed 3 nurses for 5 years"])]),
                        .exactly(CVData(experience: [job("nurses", "Acme", from: "2016", current: true)]))))
        rows.append(row("figures-quoted-nurses-en",
                        "the whole clause is a quote, figures and all: the role text and the achievement stay",
                        nurses,
                        CVData(experience: [job("nurses", "Acme", from: "2016", current: true, description: nurses,
                                                achievements: [String(nurses.dropLast())])]),
                        .unchanged))
        rows.append(row("figures-swapped-nurses-en",
                        "managed 5 nurses for 3 years is not managed 3 nurses for 5 years: the role text and the achievement go",
                        nurses,
                        CVData(experience: [job("nurses", "Acme", from: "2016", current: true, description: "Managed 5 nurses for 3 years.",
                                                achievements: ["managed 5 nurses for 3 years"])]),
                        .exactly(CVData(experience: [job("nurses", "Acme", from: "2016", current: true)]))))
        return rows
    }

    // MARK: A summary uses only function and time words freely (d)

    /// Every other word of a sentence, the verbs of a CV and the words of studying included, must occur in the description.
    private static func summariesOfAnotherCV() -> [GroundingRow] {
        typealias Variant = (language: String, description: String, foreign: String, reused: String)
        var variants: [Variant] = []
        variants.append(("en", "I'm a nurse in Turin. I work nights at the San Raffaele hospital.",
                         "I managed a school for years. Led teams for years.", "I work for years."))
        variants.append(("it", "Sono un'infermiera a Torino. Lavoro di notte all'ospedale San Raffaele.",
                         "Ho gestito una scuola per anni. Ho diretto squadre per anni.", "Lavoro per anni."))
        variants.append(("de", "Ich bin Krankenschwester in Turin. Ich arbeite nachts im Krankenhaus San Raffaele.",
                         "Ich leitete eine Schule seit Jahren. Ich betreute Teams seit Jahren.", "Ich arbeite seit Jahren."))
        // "for years" is a phrase of time that the description does not say: only function words are free in prose.

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("summary-verbs-and-nouns-of-another-cv-\(v.language)",
                            "a verb of a CV and a noun of studying the description never uses are not the description's words: the summary goes",
                            v.description, CVData(summary: v.foreign), .exactly(CVData()), language: v.language))
            rows.append(row("summary-reuses-a-verb-of-the-description-\(v.language)",
                            "the verb is the description's, but a time phrase it does not say (for years) is not free: the sentence goes",
                            v.description, CVData(summary: v.reused), .exactly(CVData()), language: v.language))
        }
        return rows
    }

    // MARK: A clause between the clauses of two entries (c)

    /// A clause next to the backing clauses of two different entries joins neither. The entries are ordinary employers, and one
    /// is named with a word of the vocabulary.
    private static func clausesBetweenTwoEntries() -> [GroundingRow] {
        typealias Variant = (language: String, description: String, second: String)
        var variants: [Variant] = []
        variants.append(("en", "At Acme I worked, from 2012 to 2016, and at Beta I worked, from 2019 to 2023.", "Beta"))
        variants.append(("it", "Presso Acme ho lavorato, dal 2012 al 2016, e presso Beta ho lavorato, dal 2019 al 2023.", "Beta"))
        variants.append(("de", "Bei Acme habe ich gearbeitet, von 2012 bis 2016, und bei Beta habe ich gearbeitet, von 2019 bis 2023.", "Beta"))
        variants.append(("en", "At Acme I worked, from 2012 to 2016, and at Time I worked, from 2019 to 2023.", "Time"))

        var rows: [GroundingRow] = []
        for v in variants {
            let draft = CVData(experience: [job("", "Acme", from: "2012", to: "2016"), job("", v.second, from: "2019", to: "2023")])
            rows.append(row(v.second == "Time" ? "dates-between-two-employers-one-named-like-a-word" : "dates-between-two-employers-\(v.language)",
                            "the years between the clauses of two employers are neither's; the years after the second one's are its own",
                            v.description, draft,
                            .exactly(CVData(experience: [job("", "Acme"), job("", v.second, from: "2019", to: "2023")])),
                            language: v.language))
        }
        return rows
    }

    // MARK: A quote that holds an employer preposition explains nothing (c)

    private static func quotesThatHoldAnEmployerPreposition() -> [GroundingRow] {
        typealias Variant = (language: String, description: String, quote: String)
        var variants: [Variant] = []
        variants.append(("en", "At Acme in 2012 I worked, and worked for Beta in 2019.", "worked for Beta"))
        variants.append(("it", "Presso Acme nel 2012 ho lavorato, e ho lavorato per Beta nel 2019.", "ho lavorato per Beta"))
        variants.append(("de", "Bei Acme habe ich 2012 gearbeitet, und habe für Beta 2019 gearbeitet.", "habe für Beta"))

        return variants.map { v in
            row("pulled-clause-by-a-verb-and-a-preposition-\(v.language)",
                "a quote that begins with a verb but holds for, per or für explains nothing: the achievement goes and 2019 is not Acme's",
                v.description, CVData(experience: [job("", "Acme", from: "2012", to: "2019", achievements: [v.quote])]),
                .exactly(CVData(experience: [job("", "Acme", from: "2012")])), language: v.language)
        }
    }

    /// A word is read in the language of the description (#202): an employer preposition of another language that the description's
    /// language uses for something else is that word, so French "j'ai" holds no Italian "ai", English "per shift" no Italian "per",
    /// and Portuguese "da" (of the) no Italian "da". A preposition of another language that is no word of the description's language
    /// still introduces an employer: "chez Gamma" in English, "at Gamma" in Italian.
    private static func employerPrepositionsOfTheDescriptionsLanguage() -> [GroundingRow] {
        typealias Variant = (id: String, language: String, description: String, employer: String, achievement: String, keeps: Bool)
        var variants: [Variant] = []
        variants.append(("j-ai-is-no-italian-ai-fr", "fr",
                         "Depuis 2016, j'enseigne à l'école Don Milani, où j'ai formé 3 nouveaux enseignants.", "école Don Milani",
                         "j'ai formé 3 nouveaux enseignants", true))
        variants.append(("per-shift-is-no-italian-per-en", "en",
                         "Since 2016 I have worked at the Molinette hospital, where I managed up to 12 patients per shift.", "Molinette hospital",
                         "managed up to 12 patients per shift", true))
        variants.append(("all-is-no-italian-all-en", "en",
                         "Since 2016 I have worked at Acme, where I trained all new nurses.", "Acme", "trained all new nurses", true))
        variants.append(("da-is-no-italian-da-pt", "pt",
                         "Desde 2016 trabalho na Acme, onde formei 3 enfermeiros da equipe.", "Acme", "formei 3 enfermeiros da equipe", true))
        variants.append(("chez-still-introduces-an-employer-en", "en",
                         "Since 2016 I have worked at Acme, where I trained 3 cooks chez Gamma.", "Acme", "trained 3 cooks chez Gamma", false))
        variants.append(("at-still-introduces-an-employer-it", "it",
                         "Dal 2016 lavoro presso Acme, dove ho formato 3 cuochi at Gamma.", "Acme", "ho formato 3 cuochi at Gamma", false))

        return variants.map { v in
            let current = { (achievements: [String]) in job("", v.employer, from: "2016", current: true, achievements: achievements) }
            return row("employer-preposition-of-the-description-\(v.id)",
                       v.keeps
                           ? "the quote holds a preposition of another language that is another word in the description's: the achievement stays"
                           : "the quote holds a preposition of another language that is no word of the description's: it explains nothing",
                       v.description, CVData(experience: [current([v.achievement])]),
                       v.keeps ? .unchanged : .exactly(CVData(experience: [current([])])), language: v.language)
        }
    }

    /// A word of negation, doubt or condition of one language that is another word in the description's language (#202) states
    /// nothing there: German and French "Mai" is a month and no Italian "mai" (never), Portuguese "no" is "in the" and no English or
    /// Spanish "no", English "fast" is quick and no German "fast" (almost).
    private static func wordsOfAnotherLanguageStateNothing() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        rows.append(row("a-month-is-no-italian-never-de", "Mai is the month of the start, not the Italian mai: the job goes on",
                        "Seit Mai 2016 arbeite ich bei Acme.", CVData(experience: [job("", "Acme", from: "Mai 2016", current: true)]),
                        .unchanged, language: "de"))
        rows.append(row("a-month-is-no-italian-never-fr", "mai is the month of the start, not the Italian mai: the job goes on",
                        "Je travaille chez Acme depuis mai 2016.", CVData(experience: [job("", "Acme", from: "mai 2016", current: true)]),
                        .unchanged, language: "fr"))
        rows.append(row("in-the-is-no-denial-of-a-job-pt", "no is in the, not the English or Spanish no: the job goes on",
                        "Desde 2016 trabalho no Hospital Santa Maria.",
                        CVData(experience: [job("", "Hospital Santa Maria", from: "2016", current: true)]), .unchanged, language: "pt"))
        rows.append(row("in-the-is-no-denial-of-a-level-pt", "no is in the, not the English or Spanish no: the level stays",
                        "Falo inglês (B2) no trabalho.", CVData(languages: [Language(name: "inglês", proficiency: .b2)]),
                        .unchanged, language: "pt"))
        rows.append(row("fast-is-no-german-almost-en",
                        "fast is quick, not the German fast: Acme is mentioned as a fact, though the clause backs no year, as fast and team are unexplained",
                        "Since 2016 I have worked at Acme in a fast team.", CVData(experience: [job("", "Acme", from: "2016", current: true)]),
                        .exactly(CVData(experience: [job("", "Acme")]))))
        return rows
    }

    // MARK: A title quoted in a clause that names no entry (b)

    /// A clause that names no entry and whose words the vocabulary, the entry's quotes or the person's quotes explain backs no
    /// other entry: the title quoted there stays. With a word nothing explains in it (the person's place, not in the draft)
    /// the title goes.
    private static func titlesInANeutralClause() -> [GroundingRow] {
        typealias Variant = (language: String, description: String, title: String, place: String)
        var variants: [Variant] = []
        variants.append(("en", "I am a primary school teacher from Bologna. Since 2016 I have worked at Acme.", "primary school teacher", "Bologna"))
        variants.append(("it", "Sono un'insegnante di scuola primaria di Bologna. Dal 2016 lavoro presso Acme.", "insegnante di scuola primaria", "Bologna"))
        variants.append(("de", "Ich bin Grundschullehrerin aus Bologna. Seit 2016 arbeite ich bei Acme.", "Grundschullehrerin", "Bologna"))
        variants.append(("es", "Soy maestra de primaria en Bolonia. Desde 2016 trabajo en Acme.", "maestra de primaria", "Bolonia"))
        variants.append(("fr", "Je suis institutrice à Bologne. Depuis 2016 je travaille chez Acme.", "institutrice", "Bologne"))
        variants.append(("pt", "Sou professora em Bolonha. Desde 2016 trabalho na Acme.", "professora", "Bolonha"))

        var rows: [GroundingRow] = []
        for v in variants {
            let current = { (title: String) in job(title, "Acme", from: "2016", current: true) }
            rows.append(row("title-in-a-neutral-clause-\(v.language)",
                            "the clause of the person's title holds only explained words, the person's place among them: the job's title stays",
                            v.description, CVData(personalInfo: person(location: v.place), experience: [current(v.title)]),
                            .unchanged, language: v.language))
            rows.append(row("title-in-a-clause-with-an-unexplained-word-\(v.language)",
                            "the same clause holds the person's place, which the draft does not quote: nothing explains it, so the title goes",
                            v.description, CVData(experience: [current(v.title)]),
                            .exactly(CVData(experience: [current("")])), language: v.language))
        }
        return rows
    }

    /// "Ensino fundamental" (primary school) is a word of studying (#202): the clause of the person's title holds only explained
    /// words, so the job's shorter title, quoted there, stays.
    private static func aWordOfStudyingInTheClauseOfATitle() -> [GroundingRow] {
        [row("a-word-of-studying-in-the-clause-of-a-title-pt",
             "fundamental, of ensino fundamental, is a word of studying: the clause of the title is explained, and professora stays",
             "Sou Maria Rossi, professora do ensino fundamental em Bolonha. Desde 2016 leciono na escola Don Milani.",
             CVData(personalInfo: person(name: "Maria Rossi", location: "Bolonha"),
                    experience: [job("professora", "escola Don Milani", from: "2016", current: true)]),
             .unchanged, language: "pt")]
    }

    // MARK: Prose is explained clause by clause (d)

    /// Each clause of a prose sentence is explained by one clause of the description: its words, other than function words,
    /// all occur in that clause, in the same order, and both hold the same negation words.
    private static func negationInProse() -> [GroundingRow] {
        typealias Variant = (language: String, never: String, positive: String, faithful: String)
        var variants: [Variant] = []
        variants.append(("en", "I have never managed a school.", "I have managed a school.", "I have never missed a deadline."))
        variants.append(("it", "Non ho mai gestito una scuola.", "Ho gestito una scuola.", "Non ho mai perso una scadenza."))
        variants.append(("de", "Ich habe nie eine Schule geleitet.", "Ich habe eine Schule geleitet.", "Ich habe nie eine Frist verpasst."))
        variants.append(("es", "Nunca he dirigido una escuela.", "He dirigido una escuela.", "Nunca he perdido un plazo."))
        variants.append(("fr", "Je n'ai jamais dirigé une école.", "J'ai dirigé une école.", "Je n'ai jamais manqué une échéance."))
        variants.append(("pt", "Nunca dirigi uma escola.", "Dirigi uma escola.", "Nunca perdi um prazo."))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("summary-negated-description-\(v.language)",
                            "the description denies it: a sentence that drops the negation does not keep it",
                            v.never, CVData(summary: v.positive), .exactly(CVData()), language: v.language))
            rows.append(row("summary-negated-prose-\(v.language)",
                            "the description says it: a sentence that adds a negation is not the description's",
                            v.positive, CVData(summary: v.never), .exactly(CVData()), language: v.language))
            rows.append(row("summary-negated-faithful-\(v.language)",
                            "a negated sentence that the description negates in the same way stays",
                            v.faithful, CVData(summary: v.faithful), .unchanged, language: v.language))
        }
        return rows
    }

    /// The words of a clause keep their order: Beta hired Acme is not Acme hired Beta, in a summary, a role text or an
    /// achievement.
    private static func orderInProse() -> [GroundingRow] {
        typealias Summary = (language: String, description: String, reversed: String)
        var summaries: [Summary] = []
        summaries.append(("en", "Beta hired Acme.", "Acme hired Beta."))
        summaries.append(("it", "Beta ha assunto Acme.", "Acme ha assunto Beta."))
        summaries.append(("de", "Beta hat Acme eingestellt.", "Acme hat Beta eingestellt."))
        summaries.append(("es", "Beta contrató a Acme.", "Acme contrató a Beta."))
        summaries.append(("fr", "Beta a embauché Acme.", "Acme a embauché Beta."))
        summaries.append(("pt", "A Beta contratou a Acme.", "A Acme contratou a Beta."))

        typealias Role = (language: String, description: String, reversed: String, reversedQuote: String, quote: String, quoteToTheEnd: String)
        var roles: [Role] = []
        roles.append(("en", "I taught courses to students at Acme.", "Taught students courses at Acme.", "taught students courses",
                      "taught courses to students", "taught courses to students at Acme"))
        roles.append(("it", "Insegno corsi a studenti presso Acme.", "Insegno a studenti corsi presso Acme.", "insegno a studenti corsi",
                      "insegno corsi a studenti", "insegno corsi a studenti presso Acme"))
        roles.append(("de", "Ich unterrichte Kurse für Studenten bei Acme.", "Ich unterrichte Studenten Kurse bei Acme.",
                      "unterrichte Studenten Kurse", "unterrichte Kurse für Studenten", "unterrichte Kurse für Studenten bei Acme"))

        var rows: [GroundingRow] = []
        for v in summaries {
            rows.append(row("summary-reversed-\(v.language)",
                            "the same words in another order say another thing: the summary goes",
                            v.description, CVData(summary: v.reversed), .exactly(CVData()), language: v.language))
            rows.append(row("summary-in-order-\(v.language)",
                            "the words in the order of the description, but the explicit subject is Beta, not the person: the clause is never quoted, so the summary goes",
                            v.description, CVData(summary: v.description), .exactly(CVData()), language: v.language))
        }
        for v in roles {
            // The role text of the description, as a text and as the quote of an achievement.
            let faithfulRole = String(v.description.dropLast()) + "."
            rows.append(row("role-and-achievement-reversed-\(v.language)",
                            "the same words in another order say another thing: the role text and the achievement go",
                            v.description,
                            CVData(experience: [job("", "Acme", description: v.reversed, achievements: [v.reversedQuote])]),
                            .exactly(CVData(experience: [job("", "Acme")])), language: v.language))
            rows.append(row("role-and-achievement-in-order-\(v.language)",
                            "the role text is the whole clause and stays; the achievement stops before the clause's end (at Acme): no quote, so it goes",
                            v.description,
                            CVData(experience: [job("", "Acme", description: faithfulRole, achievements: [v.quote])]),
                            .exactly(CVData(experience: [job("", "Acme", description: faithfulRole)])), language: v.language))
            rows.append(row("achievement-quotes-a-clause-to-its-end-\(v.language)",
                            "the achievement runs to the end of the clause, after its lead-in: it stays",
                            v.description,
                            CVData(experience: [job("", "Acme", achievements: [v.quoteToTheEnd])]),
                            .unchanged, language: v.language))
        }
        return rows
    }

    /// A sentence whose words come from two clauses of the description is dropped, though every word occurs in it.
    private static func oneClauseOfProse() -> [GroundingRow] {
        typealias Variant = (language: String, description: String, crossed: String, single: String)
        var variants: [Variant] = []
        variants.append(("en", "I managed a school, and I led a team.", "I led a school.", "I led a team."))
        variants.append(("it", "Ho gestito una scuola e ho diretto una squadra.", "Ho diretto una scuola.", "Ho diretto una squadra."))
        variants.append(("de", "Ich leitete eine Schule und ich betreute ein Team.", "Ich betreute eine Schule.", "Ich betreute ein Team."))
        variants.append(("es", "Dirigí una escuela y coordiné un equipo.", "Coordiné una escuela.", "Coordiné un equipo."))
        variants.append(("fr", "J'ai dirigé une école et j'ai coordonné une équipe.", "J'ai coordonné une école.", "J'ai coordonné une équipe."))
        variants.append(("pt", "Dirigi uma escola e coordenei uma equipe.", "Coordenei uma escola.", "Coordenei uma equipe."))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("summary-from-two-clauses-\(v.language)",
                            "the verb stands in one clause of the description and the noun in another: the words are not combined",
                            v.description, CVData(summary: v.crossed), .exactly(CVData()), language: v.language))
            rows.append(row("summary-from-one-clause-\(v.language)",
                            "the verb and the noun stand in one clause of the description: the sentence stays",
                            v.description, CVData(summary: v.single), .unchanged, language: v.language))
        }
        return rows
    }

    /// Only function words are free in prose. A word of time the description does not use is not.
    private static func timeWordsInProse() -> [GroundingRow] {
        typealias Variant = (language: String, description: String, withTime: String, single: String, whole: String)
        var variants: [Variant] = []
        variants.append(("en", "I'm a nurse in Turin. I work nights at the San Raffaele hospital.", "I work nights today.", "I work nights.",
                         "I work nights at the San Raffaele hospital."))
        variants.append(("it", "Sono un'infermiera a Torino. Lavoro di notte all'ospedale San Raffaele.", "Lavoro di notte oggi.",
                         "Lavoro di notte.", "Lavoro di notte all'ospedale San Raffaele."))
        variants.append(("de", "Ich bin Krankenschwester in Turin. Ich arbeite nachts im Krankenhaus San Raffaele.", "Ich arbeite nachts heute.",
                         "Ich arbeite nachts.", "Ich arbeite nachts im Krankenhaus San Raffaele."))
        variants.append(("es", "Soy enfermera en Turín. Trabajo de noche en el hospital San Raffaele.", "Trabajo de noche hoy.",
                         "Trabajo de noche.", "Trabajo de noche en el hospital San Raffaele."))
        variants.append(("fr", "Je suis infirmière à Turin. Je travaille la nuit à l'hôpital San Raffaele.", "Je travaille la nuit aujourd'hui.",
                         "Je travaille la nuit.", "Je travaille la nuit à l'hôpital San Raffaele."))
        variants.append(("pt", "Sou enfermeira em Turim. Trabalho à noite no hospital San Raffaele.", "Trabalho à noite hoje.",
                         "Trabalho à noite.", "Trabalho à noite no hospital San Raffaele."))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("summary-with-a-time-word-the-description-lacks-\(v.language)",
                            "a word of time that the description never says is not free in prose: the sentence goes",
                            v.description, CVData(summary: v.withTime), .exactly(CVData()), language: v.language))
            rows.append(row("summary-of-the-words-of-one-clause-\(v.language)",
                            "the words of one clause, but the quote stops before the clause's end: it is no quote, so the sentence goes",
                            v.description, CVData(summary: v.single), .exactly(CVData()), language: v.language))
            rows.append(row("summary-quotes-a-whole-clause-\(v.language)",
                            "the whole clause of the description is a quote: the sentence stays",
                            v.description, CVData(summary: v.whole), .unchanged, language: v.language))
        }
        rows.append(row("summary-with-a-time-word-the-description-lacks-currently-en",
                        "currently is a word of time that the description never says: the sentence goes",
                        "I'm a nurse in Turin. I work nights at the San Raffaele hospital.",
                        CVData(summary: "I work nights currently."), .exactly(CVData())))
        return rows
    }

    /// The word after an employer preposition must follow the same preposition in the description, though it is a word of time
    /// or a function word ("at Next", "for May", "at Will").
    private static func wordsAfterAnEmployerPreposition() -> [GroundingRow] {
        typealias Variant = (id: String, language: String, description: String, prose: String)
        var variants: [Variant] = []
        variants.append(("en", "en", "I worked at Acme.", "I worked at Next."))
        variants.append(("will-en", "en", "I worked at Acme.", "I worked at Will."))
        variants.append(("may-en", "en", "I worked for Acme.", "I worked for May."))
        variants.append(("it", "it", "Ho lavorato presso Acme.", "Ho lavorato presso Ora."))
        variants.append(("de", "de", "Ich habe bei Acme gearbeitet.", "Ich habe bei Heute gearbeitet."))
        variants.append(("es", "es", "Trabajé en Acme.", "Trabajé en Hoy."))
        variants.append(("fr", "fr", "J'ai travaillé chez Acme.", "J'ai travaillé chez Demain."))
        variants.append(("pt", "pt", "Trabalhei na Acme.", "Trabalhei na Hoje."))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("summary-after-an-employer-preposition-\(v.id)",
                            "the word after the preposition is a word of time, not the employer the description names: the sentence goes",
                            v.description, CVData(summary: v.prose), .exactly(CVData()), language: v.language))
            if v.id == v.language {
                rows.append(row("summary-same-preposition-and-word-\(v.language)",
                                "the preposition followed by the word that follows it in the description: the sentence stays",
                                v.description, CVData(summary: v.description), .unchanged, language: v.language))
            }
        }
        return rows
    }

    // MARK: A joining clause gives dates only as a pure time phrase (c)

    /// "and at Next in 2020" is no time phrase: at and next are not in the list. The employer is named like a word of time.
    private static func datesFromATimePhrase() -> [GroundingRow] {
        typealias Variant = (language: String, description: String)
        var variants: [Variant] = []
        variants.append(("en", "I worked at Acme in 2012 and at Next in 2020."))
        variants.append(("it", "Ho lavorato presso Acme nel 2012 e presso Ora nel 2020."))
        variants.append(("de", "Ich habe bei Acme 2012 gearbeitet und bei Heute 2020."))
        variants.append(("es", "Trabajé en Acme en 2012 y en Hoy en 2020."))
        variants.append(("fr", "J'ai travaillé chez Acme en 2012 et chez Demain en 2020."))
        variants.append(("pt", "Trabalhei na Acme em 2012 e na Hoje em 2020."))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("dates-after-a-clause-with-a-word-outside-the-list-\(v.language)",
                            "a clause with a word outside the time-phrase list gives no date: the 2020 of the other employer is not Acme's",
                            v.description,
                            CVData(experience: [job("", "Acme", from: "2012", to: "2020", current: false)]),
                            .exactly(CVData(experience: [job("", "Acme", from: "2012")])), language: v.language))
        }

        typealias Until = (language: String, description: String, title: String)
        var untils: [Until] = []
        untils.append(("en", "I worked as a nurse at Acme, until 2016.", "nurse"))
        untils.append(("it", "Ho lavorato come infermiera presso Acme, fino al 2016.", "infermiera"))
        untils.append(("de", "Ich habe als Krankenschwester bei Acme gearbeitet, bis 2016.", "Krankenschwester"))
        for v in untils {
            rows.append(row("joined-time-phrase-until-\(v.language)",
                            "until 2016, fino al 2016 and bis 2016 are pure time phrases: they join the clause of the employer and give the year",
                            v.description, CVData(experience: [job(v.title, "Acme", to: "2016")]), .unchanged, language: v.language))
        }
        return rows
    }

    // MARK: A graduation phrase joins an education entry and gives its end date (c)

    /// A pure time phrase that also holds words of graduating joins only an education entry and gives it its end date. Next to
    /// a job's clause it joins nothing, so a job never takes a graduation year; with a word outside the lists it joins nothing.
    private static func graduationPhrases() -> [GroundingRow] {
        typealias Variant = (
            language: String, withAJob: String, withNext: String, degree: String, school: String, schoolAndGraduation: String
        )
        var variants: [Variant] = []
        variants.append((
            "en", "I have worked at Acme since 2016 and graduated in 2012.",
            "I studied Nursing at Alpha University and graduated at Next in 2012.", "Nursing", "Alpha University",
            "I studied Nursing at Alpha University and graduated in 2012."))
        variants.append((
            "it", "Lavoro presso Acme dal 2016 e mi sono laureata nel 2012.",
            "Ho studiato Infermieristica all'Università Alpha e mi sono laureata presso Ora nel 2012.", "Infermieristica", "Università Alpha",
            "Ho studiato Infermieristica all'Università Alpha e mi sono laureata nel 2012."))
        variants.append((
            "de", "Ich arbeite seit 2016 bei Acme und habe 2012 meinen Abschluss gemacht.",
            "Ich habe Pflege an der Universität Alpha studiert und bei Heute 2012 meinen Abschluss gemacht.", "Pflege", "Universität Alpha",
            "Ich habe Pflege an der Universität Alpha studiert und 2012 meinen Abschluss gemacht."))
        variants.append((
            "es", "Trabajo en Acme desde 2016 y me gradué en 2012.",
            "Estudié Enfermería en la Universidad Alfa y me gradué en Hoy en 2012.", "Enfermería", "Universidad Alfa",
            "Estudié Enfermería en la Universidad Alfa y me gradué en 2012."))
        variants.append((
            "fr", "Je travaille chez Acme depuis 2016 et j'ai obtenu mon diplôme en 2012.",
            "J'ai étudié les soins à l'université Alpha et j'ai obtenu mon diplôme chez Demain en 2012.", "les soins", "université Alpha",
            "J'ai étudié les soins à l'université Alpha et j'ai obtenu mon diplôme en 2012."))
        variants.append((
            "pt", "Trabalho na Acme desde 2016 e me formei em 2012.",
            "Estudei Enfermagem na Universidade Alfa e me formei na Hoje em 2012.", "Enfermagem", "Universidade Alfa",
            "Estudei Enfermagem na Universidade Alfa e me formei em 2012."))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("a-job-never-takes-a-graduation-year-as-its-end-\(v.language)",
                            "the graduation phrase next to the clause of a job joins nothing: 2012 is not the job's end, 2016 stays its start",
                            v.withAJob, CVData(experience: [job("", "Acme", from: "2016", to: "2012")]),
                            .exactly(CVData(experience: [job("", "Acme", from: "2016")])), language: v.language))
            rows.append(row("a-job-never-takes-a-graduation-year-as-its-start-\(v.language)",
                            "the graduation phrase next to the clause of a job joins nothing: 2012 is not the job's start",
                            v.withAJob, CVData(experience: [job("", "Acme", from: "2012")]),
                            .exactly(CVData(experience: [job("", "Acme")])), language: v.language))
            rows.append(row("graduation-phrase-with-a-word-outside-the-lists-\(v.language)",
                            "a word outside the lists (at Next) keeps the clause from being a graduation phrase: it gives the degree no year",
                            v.withNext, CVData(education: [study(v.degree, at: v.school, to: "2012")]),
                            .exactly(CVData(education: [study(v.degree, at: v.school)])), language: v.language))
            rows.append(row("one-year-one-date-of-a-graduation-\(v.language)",
                            "2012 is written once, in a graduation phrase: a study keeps it as its end date only",
                            v.schoolAndGraduation, CVData(education: [study(v.degree, at: v.school, from: "2012", to: "2012")]),
                            .exactly(CVData(education: [study(v.degree, at: v.school, to: "2012")])), language: v.language))
        }
        return rows
    }

    // MARK: Clauses that deny, doubt or only hope back nothing (c)

    /// An achievement quote that holds a word of graduating never explains a job's clause.
    private static func achievementsOfGraduating() -> [GroundingRow] {
        typealias Variant = (language: String, description: String, quote: String)
        var variants: [Variant] = []
        variants.append(("en", "I have worked at Acme since 2016 and graduated in 2012.", "graduated in 2012"))
        variants.append(("it", "Lavoro presso Acme dal 2016 e mi sono laureata nel 2012.", "mi sono laureata nel 2012"))
        variants.append(("de", "Ich arbeite seit 2016 bei Acme und habe 2012 meinen Abschluss gemacht.", "habe 2012 meinen Abschluss gemacht"))
        variants.append(("es", "Trabajo en Acme desde 2016 y me gradué en 2012.", "me gradué en 2012"))
        variants.append(("fr", "Je travaille chez Acme depuis 2016 et j'ai obtenu mon diplôme en 2012.", "j'ai obtenu mon diplôme en 2012"))
        variants.append(("pt", "Trabalho na Acme desde 2016 e me formei em 2012.", "me formei em 2012"))

        return variants.map { v in
            row("a-graduation-phrase-is-no-achievement-of-a-job" + (v.language == "en" ? "" : "-\(v.language)"),
                "an achievement that quotes the graduation clause explains nothing of a job: the achievement goes, 2016 stays",
                v.description, CVData(experience: [job("", "Acme", from: "2016", achievements: [v.quote])]),
                .exactly(CVData(experience: [job("", "Acme", from: "2016")])), language: v.language)
        }
    }

    /// Prose keeps the words of doubt or degree of its description clause: barely managed is not managed.
    private static func hedgesInProse() -> [GroundingRow] {
        typealias Variant = (language: String, hedged: String, plain: String)
        var variants: [Variant] = []
        variants.append(("en", "I have barely managed a school.", "I have managed a school."))
        variants.append(("it", "Ho gestito a malapena una scuola.", "Ho gestito una scuola."))
        variants.append(("de", "Ich habe kaum eine Schule geleitet.", "Ich habe eine Schule geleitet."))
        variants.append(("es", "Apenas he dirigido una escuela.", "He dirigido una escuela."))
        variants.append(("fr", "J'ai à peine dirigé une école.", "J'ai dirigé une école."))
        variants.append(("pt", "Mal dirigi uma escola.", "Dirigi uma escola."))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("summary-drops-a-hedge-of-the-description" + (v.language == "en" ? "" : "-\(v.language)"),
                            "the description says barely: a sentence without the hedge says more than it does, so it goes",
                            v.hedged, CVData(summary: v.plain), .exactly(CVData()), language: v.language))
            rows.append(row("summary-adds-a-hedge-to-the-description-\(v.language)",
                            "the description says it plainly: a sentence with a hedge is not the description's",
                            v.plain, CVData(summary: v.hedged), .exactly(CVData()), language: v.language))
            rows.append(row("summary-keeps-the-hedge-of-the-description-\(v.language)",
                            "a sentence that keeps the hedge of its description clause stays",
                            v.hedged, CVData(summary: v.hedged), .unchanged, language: v.language))
        }
        return rows
    }

    /// Prose keeps the words of doubt ("almost") and of wish ("want") of its description clause, and loses the sentence that
    /// drops them.
    private static func modalityInProse() -> [GroundingRow] {
        typealias Variant = (language: String, almost: String, plainAlmost: String, want: String, plainWant: String)
        var variants: [Variant] = []
        variants.append(("en", "I almost finished my degree.", "I finished my degree.", "I want to lead a team.", "I lead a team."))
        variants.append(("it", "Ho quasi finito gli studi.", "Ho finito gli studi.", "Voglio dirigere una squadra.", "Dirigo una squadra."))
        variants.append(("de", "Ich habe mein Studium fast abgeschlossen.", "Ich habe mein Studium abgeschlossen.",
                         "Ich will ein Team leiten.", "Ich leite ein Team."))
        variants.append(("es", "Casi terminé mis estudios.", "Terminé mis estudios.", "Quiero dirigir un equipo.", "Dirijo un equipo."))
        variants.append(("fr", "J'ai presque terminé mes études.", "J'ai terminé mes études.", "Je veux diriger une équipe.", "Je dirige une équipe."))
        variants.append(("pt", "Quase terminei meus estudos.", "Terminei meus estudos.", "Quero dirigir uma equipe.", "Dirijo uma equipe."))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("summary-drops-almost-\(v.language)",
                            "the description says almost: the sentence without it says more than the description does",
                            v.almost, CVData(summary: v.plainAlmost), .exactly(CVData()), language: v.language))
            rows.append(row("summary-keeps-almost-\(v.language)",
                            "the sentence that keeps the almost of its description clause stays",
                            v.almost, CVData(summary: v.almost), .unchanged, language: v.language))
            rows.append(row("summary-drops-a-wish-\(v.language)",
                            "the description says want: the sentence without it states what the person only wishes",
                            v.want, CVData(summary: v.plainWant), .exactly(CVData()), language: v.language))
            rows.append(row("summary-keeps-a-wish-\(v.language)",
                            "the sentence that keeps the want of its description clause stays",
                            v.want, CVData(summary: v.want), .unchanged, language: v.language))
        }
        return rows
    }

    /// An entry is kept only if some clause names its employer, school or certification without a word of negation, doubt,
    /// wish, intention, future or condition. A denied, hoped-for or conditional mention gives no entry.
    private static func entriesNeedAFactualMention() -> [GroundingRow] {
        typealias Variant = (language: String, never: String, wish: String, future: String, condition: String)
        var variants: [Variant] = []
        variants.append(("en", "I have never worked at Acme.", "I would like to work at Acme.", "I will work at Acme from 2027.",
                         "If Acme hires me, I will work there from 2027."))
        variants.append(("it", "Non ho mai lavorato presso Acme.", "Vorrei lavorare presso Acme.", "Lavorerò presso Acme dal 2027.",
                         "Se Acme mi assume, lavorerò lì dal 2027."))
        variants.append(("de", "Ich habe nie bei Acme gearbeitet.", "Ich möchte bei Acme arbeiten.", "Ich werde ab 2027 bei Acme arbeiten.",
                         "Wenn Acme mich einstellt, werde ich dort ab 2027 arbeiten."))
        variants.append(("es", "Nunca he trabajado en Acme.", "Me gustaría trabajar en Acme.", "Trabajaré en Acme desde 2027.",
                         "Si Acme me contrata, trabajaré allí desde 2027."))
        variants.append(("fr", "Je n'ai jamais travaillé chez Acme.", "Je voudrais travailler chez Acme.",
                         "Je travaillerai chez Acme à partir de 2027.", "Si Acme m'embauche, je travaillerai là-bas à partir de 2027."))
        variants.append(("pt", "Nunca trabalhei na Acme.", "Gostaria de trabalhar na Acme.", "Trabalharei na Acme a partir de 2027.",
                         "Se a Acme me contratar, trabalharei lá a partir de 2027."))

        var rows: [GroundingRow] = []
        for v in variants {
            let undated = CVData(experience: [job("", "Acme")])
            let dated = CVData(experience: [job("", "Acme", from: "2027")])
            rows.append(row("no-job-from-a-denied-mention-\(v.language)",
                            "the only mention of Acme denies the work: there is no Acme job",
                            v.never, undated, .exactly(CVData()), language: v.language))
            rows.append(row("no-job-from-a-wish-\(v.language)",
                            "the only mention of Acme is a wish: there is no Acme job",
                            v.wish, undated, .exactly(CVData()), language: v.language))
            rows.append(row("no-job-from-a-future-\(v.language)",
                            "the only mention of Acme is a future: there is no Acme job, and 2027 is nobody's",
                            v.future, dated, .exactly(CVData()), language: v.language))
            rows.append(row("no-job-from-a-condition-\(v.language)",
                            "the only mention of Acme is a condition and a future: there is no Acme job",
                            v.condition, dated, .exactly(CVData()), language: v.language))
        }

        typealias School = (language: String, wish: String, never: String, institution: String)
        var schools: [School] = []
        schools.append(("en", "I would like to study at the University of Bologna.", "I have never studied at the University of Bologna.",
                        "University of Bologna"))
        schools.append(("it", "Vorrei studiare all'Università di Bologna.", "Non ho mai studiato all'Università di Bologna.",
                        "Università di Bologna"))
        schools.append(("de", "Ich möchte an der Universität Bologna studieren.", "Ich habe nie an der Universität Bologna studiert.",
                        "Universität Bologna"))
        schools.append(("es", "Me gustaría estudiar en la Universidad de Bolonia.", "Nunca he estudiado en la Universidad de Bolonia.",
                        "Universidad de Bolonia"))
        schools.append(("fr", "Je voudrais étudier à l'université de Bologne.", "Je n'ai jamais étudié à l'université de Bologne.",
                        "université de Bologne"))
        schools.append(("pt", "Gostaria de estudar na Universidade de Bolonha.", "Nunca estudei na Universidade de Bolonha.",
                        "Universidade de Bolonha"))
        for v in schools {
            let draft = CVData(education: [study(at: v.institution)])
            rows.append(row("no-study-from-a-wish-\(v.language)",
                            "the only mention of the university is a wish: there is no study",
                            v.wish, draft, .exactly(CVData()), language: v.language))
            rows.append(row("no-study-from-a-denied-mention-\(v.language)",
                            "the only mention of the university denies the study: there is no study",
                            v.never, draft, .exactly(CVData()), language: v.language))
        }

        typealias Certificate = (language: String, wish: String, both: String)
        var certificates: [Certificate] = []
        certificates.append(("en", "I would like to earn a BLS.", "I have a BLS. I would like to earn an ACLS."))
        certificates.append(("it", "Vorrei ottenere un BLS.", "Ho un BLS. Vorrei ottenere un ACLS."))
        certificates.append(("de", "Ich möchte ein BLS erwerben.", "Ich habe ein BLS. Ich möchte ein ACLS erwerben."))
        certificates.append(("es", "Me gustaría obtener un BLS.", "Tengo un BLS. Me gustaría obtener un ACLS."))
        certificates.append(("fr", "Je voudrais obtenir un BLS.", "J'ai un BLS. Je voudrais obtenir un ACLS."))
        certificates.append(("pt", "Gostaria de obter um BLS.", "Tenho um BLS. Gostaria de obter um ACLS."))
        for v in certificates {
            rows.append(row("no-certification-from-a-wish-\(v.language)",
                            "the only mention of the BLS is a wish: there is no certification",
                            v.wish, CVData(certifications: [Certification(name: "BLS")]), .exactly(CVData()), language: v.language))
            rows.append(row("certification-held-and-certification-wished-\(v.language)",
                            "the BLS is held and the ACLS only wished: the BLS stays and the ACLS goes",
                            v.both, CVData(certifications: [Certification(name: "BLS"), Certification(name: "ACLS")]),
                            .exactly(CVData(certifications: [Certification(name: "BLS")])), language: v.language))
        }
        return rows
    }

    /// The employer of a factual mention stays, and what denies, hopes or promises gives nothing.
    private static func clausesThatDenyDoubtOrHope() -> [GroundingRow] {
        typealias Variant = (
            language: String, hoped: String, denied: String, mixed: String, promised: String
        )
        var variants: [Variant] = []
        variants.append(("en", "I work at Acme. I would like to work at Beta.", "I have worked at Acme since 2016; I never worked at Beta.",
                         "I worked at Acme in 2012. I will not work at Acme in 2020.",
                         "I have worked at Acme since 2016, and I will stay until 2030."))
        variants.append(("it", "Lavoro presso Acme. Vorrei lavorare presso Beta.", "Lavoro presso Acme dal 2016; non ho mai lavorato presso Beta.",
                         "Ho lavorato presso Acme nel 2012. Non lavorerò presso Acme nel 2020.",
                         "Lavoro presso Acme dal 2016 e resterò fino al 2030."))
        variants.append(("de", "Ich arbeite bei Acme. Ich möchte bei Beta arbeiten.",
                         "Ich arbeite seit 2016 bei Acme; ich habe nie bei Beta gearbeitet.",
                         "Ich habe 2012 bei Acme gearbeitet. Ich werde 2020 nicht bei Acme arbeiten.",
                         "Ich arbeite seit 2016 bei Acme und werde bis 2030 bleiben."))
        variants.append(("es", "Trabajo en Acme. Me gustaría trabajar en Beta.", "Trabajo en Acme desde 2016; nunca he trabajado en Beta.",
                         "Trabajé en Acme en 2012. No trabajaré en Acme en 2020.",
                         "Trabajo en Acme desde 2016 y me quedaré hasta 2030."))
        variants.append(("fr", "Je travaille chez Acme. Je voudrais travailler chez Beta.",
                         "Je travaille chez Acme depuis 2016; je n'ai jamais travaillé chez Beta.",
                         "J'ai travaillé chez Acme en 2012. Je ne travaillerai pas chez Acme en 2020.",
                         "Je travaille chez Acme depuis 2016 et je resterai jusqu'en 2030."))
        variants.append(("pt", "Trabalho na Acme. Gostaria de trabalhar na Beta.", "Trabalho na Acme desde 2016; nunca trabalhei na Beta.",
                         "Trabalhei na Acme em 2012. Não trabalharei na Acme em 2020.",
                         "Trabalho na Acme desde 2016 e ficarei até 2030."))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("job-kept-and-job-wished-\(v.language)",
                            "Acme is mentioned as a fact and Beta as a wish: Acme stays and Beta goes",
                            v.hoped, CVData(experience: [job("", "Acme"), job("", "Beta")]),
                            .exactly(CVData(experience: [job("", "Acme")])), language: v.language))
            rows.append(row("job-kept-and-job-denied-\(v.language)",
                            "Acme is mentioned as a fact with 2016 and Beta as never worked: Acme stays with 2016 and Beta goes",
                            v.denied, CVData(experience: [job("", "Acme", from: "2016"), job("", "Beta")]),
                            .exactly(CVData(experience: [job("", "Acme", from: "2016")])), language: v.language))
            rows.append(row("job-kept-with-a-clause-that-denies-the-same-employer-\(v.language)",
                            "a fact and a denied future about Acme: the entry stays, and the clause that denies gives it no 2020",
                            v.mixed, CVData(experience: [job("", "Acme", from: "2012", to: "2020")]),
                            .exactly(CVData(experience: [job("", "Acme", from: "2012")])), language: v.language))
            rows.append(row("no-end-date-from-a-promise-\(v.language)",
                            "a promise (will stay until 2030) gives no date: Acme keeps 2016 and current, and never an end in 2030",
                            v.promised, CVData(experience: [job("", "Acme", from: "2016", to: "2030", current: true)]),
                            .exactly(CVData(experience: [job("", "Acme", from: "2016", current: true)])), language: v.language))
        }
        return rows
    }

    // MARK: A mention is factual when every verb is a listed present or past form (c)

    /// The rule is about the form of the verbs, not a list of phrases: another verb in any form, an infinitive, a verb after
    /// "to" or "zu" makes a mention not factual. A clause without a verb stays factual.
    private static func factualVerbs() -> [GroundingRow] {
        typealias Variant = (language: String, future: String)
        var futures: [Variant] = []
        futures.append(("en", "I will stay at Acme from 2027."))
        futures.append(("it", "Resterò presso Acme dal 2027."))
        futures.append(("de", "Ich werde ab 2027 bei Acme bleiben."))
        futures.append(("es", "Me quedaré en Acme desde 2027."))
        futures.append(("fr", "Je resterai chez Acme à partir de 2027."))
        futures.append(("pt", "Ficarei na Acme a partir de 2027."))

        var rows: [GroundingRow] = []
        let promised = CVData(experience: [job("", "Acme", from: "2027")])
        for v in futures {
            rows.append(row("no-job-from-a-future-of-another-verb-\(v.language)",
                            "stay is no CV verb and the future is no listed present or past: the mention is not factual, so no Acme job and no 2027",
                            v.future, promised, .exactly(CVData()), language: v.language))
        }

        typealias Going = (language: String, description: String)
        var goings: [Going] = []
        goings.append(("en", "I am going to work at Acme from 2027."))
        goings.append(("it", "Sto per lavorare presso Acme dal 2027."))
        goings.append(("es", "Voy a trabajar en Acme desde 2027."))
        goings.append(("fr", "Je vais travailler chez Acme à partir de 2027."))
        goings.append(("pt", "Vou trabalhar na Acme a partir de 2027."))
        for v in goings {
            rows.append(row("no-job-from-going-to-\(v.language)",
                            "work after going to is an infinitive: the mention is not factual, so no Acme job and no 2027",
                            v.description, promised, .exactly(CVData()), language: v.language))
        }

        typealias Intention = (language: String, description: String, from: String?)
        var intentions: [Intention] = []
        intentions.append(("en", "I try to work at Acme.", nil))
        intentions.append(("it", "Ho intenzione di lavorare presso Acme dal 2027.", "2027"))
        intentions.append(("de", "Ich habe vor, bei Acme zu arbeiten, ab 2027.", "2027"))
        intentions.append(("es", "Intento trabajar en Acme.", nil))
        intentions.append(("fr", "J'essaie de travailler chez Acme.", nil))
        intentions.append(("pt", "Pretendo trabalhar na Acme.", nil))
        for v in intentions {
            rows.append(row("no-job-from-an-intention-phrase-\(v.language)",
                            "an intention has a verb that is no listed present or past, and an infinitive after it: no Acme job",
                            v.description, CVData(experience: [job("", "Acme", from: v.from)]), .exactly(CVData()), language: v.language))
        }

        typealias Verbless = (language: String, description: String, title: String)
        var verbless: [Verbless] = []
        verbless.append(("en", "Nurse at Acme, 2016\u{2013}2020.", "nurse"))
        verbless.append(("it", "Infermiera presso Acme, 2016\u{2013}2020.", "infermiera"))
        verbless.append(("de", "Krankenschwester bei Acme, 2016\u{2013}2020.", "Krankenschwester"))
        verbless.append(("es", "Enfermera en Acme, 2016\u{2013}2020.", "enfermera"))
        verbless.append(("fr", "Infirmière chez Acme, 2016\u{2013}2020.", "infirmière"))
        verbless.append(("pt", "Enfermeira na Acme, 2016\u{2013}2020.", "enfermeira"))
        for v in verbless {
            rows.append(row("verbless-mention-is-factual-\(v.language)",
                            "a clause without a verb is factual: the job stays with both years, which the pure time phrase gives",
                            v.description, CVData(experience: [job(v.title, "Acme", from: "2016", to: "2020")]), .unchanged,
                            language: v.language))
        }

        typealias Ordinary = (language: String, present: String, past: String, perfect: String)
        var ordinary: [Ordinary] = []
        ordinary.append(("en", "I work at Acme since 2016.", "I worked at Acme in 2012.", "I have worked at Acme since 2016."))
        ordinary.append(("it", "Lavoro presso Acme dal 2016.", "Ho lavorato presso Acme nel 2012.", "Ho lavorato presso Acme dal 2016."))
        ordinary.append(("de", "Ich arbeite seit 2016 bei Acme.", "Ich habe 2012 bei Acme gearbeitet.", "Ich habe seit 2016 bei Acme gearbeitet."))
        ordinary.append(("es", "Trabajo en Acme desde 2016.", "Trabajé en Acme en 2012.", "He trabajado en Acme desde 2016."))
        ordinary.append(("fr", "Je travaille chez Acme depuis 2016.", "J'ai travaillé chez Acme en 2012.", "J'ai travaillé chez Acme depuis 2016."))
        ordinary.append(("pt", "Trabalho na Acme desde 2016.", "Trabalhei na Acme em 2012.", "Tenho trabalhado na Acme desde 2016."))
        for v in ordinary {
            rows.append(row("ordinary-present-keeps-the-job-\(v.language)",
                            "a CV verb in a listed present form is factual: the job and its year stay",
                            v.present, CVData(experience: [job("", "Acme", from: "2016")]), .unchanged, language: v.language))
            rows.append(row("ordinary-past-keeps-the-job-\(v.language)",
                            "a CV verb in a listed past form is factual: the job and its year stay",
                            v.past, CVData(experience: [job("", "Acme", from: "2012")]), .unchanged, language: v.language))
            rows.append(row("perfect-with-an-auxiliary-keeps-the-job-\(v.language)",
                            "a CV verb in a perfect with its auxiliary is factual: the job and its year stay",
                            v.perfect, CVData(experience: [job("", "Acme", from: "2016")]), .unchanged, language: v.language))
        }

        typealias Infinitive = (language: String, inTheClause: String?, apart: String)
        var infinitives: [Infinitive] = []
        infinitives.append(("en", "I worked at Acme to support 3 teams.", "I worked at Acme, to support 3 teams."))
        infinitives.append(("it", "Ho lavorato presso Acme per sostenere 3 squadre.", "Ho lavorato presso Acme, per sostenere 3 squadre."))
        infinitives.append(("de", nil, "Ich habe bei Acme gearbeitet, um 3 Teams zu unterstützen."))
        infinitives.append(("es", "Trabajé en Acme para apoyar a 3 equipos.", "Trabajé en Acme, para apoyar a 3 equipos."))
        infinitives.append(("fr", "J'ai travaillé chez Acme pour soutenir 3 équipes.", "J'ai travaillé chez Acme, pour soutenir 3 équipes."))
        infinitives.append(("pt", "Trabalhei na Acme para apoiar 3 equipes.", "Trabalhei na Acme, para apoiar 3 equipes."))
        for v in infinitives {
            if let inTheClause = v.inTheClause {
                rows.append(row("infinitive-marker-in-the-clause-of-the-employer-\(v.language)",
                                "the verb after the marker comes after the name and a factual verb: a purpose, which does not undo the mention, "
                                    + "so Acme stays",
                                inTheClause, CVData(experience: [job("", "Acme")]), .unchanged, language: v.language))
            }
            rows.append(row("infinitive-marker-in-another-clause-\(v.language)",
                            "the comma splits the clause: the clause that names Acme holds only a listed past, so the job stays "
                                + "and the clause of the infinitive gives nothing",
                            v.apart, CVData(experience: [job("", "Acme")]), .unchanged, language: v.language))
        }
        return rows
    }

    // MARK: A purpose after a factual statement keeps the mention (c)

    /// Every verb before the name, or before the clause's first factual verb, must be factual. A verb after both is a purpose or a
    /// detail: it does not undo the mention, and the words from it to the end of the clause give no facts. The present and past of
    /// "to be", contracted or not, are factual verbs.
    private static func purposesAndStatements() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        typealias Variant = (language: String, studied: String)
        var studied: [Variant] = []
        studied.append(("en", "I studied hard to work at Acme."))
        studied.append(("it", "Ho studiato molto per lavorare presso Acme."))
        studied.append(("de", "Ich habe fleißig gelernt, um bei Acme zu arbeiten."))
        studied.append(("es", "Estudié mucho para trabajar en Acme."))
        studied.append(("fr", "J'ai beaucoup étudié pour travailler chez Acme."))
        studied.append(("pt", "Estudei muito para trabalhar na Acme."))
        for v in studied {
            rows.append(row("no-job-from-a-purpose-before-the-name-\(v.language)",
                            "the verb after the marker comes before the name and no factual verb precedes it: the mention is not factual",
                            v.studied, CVData(experience: [job("", "Acme")]), .exactly(CVData()), language: v.language))
        }
        rows.append(row("no-job-from-an-infinitive-clause-de",
                        "bei Acme zu arbeiten: the name comes before zu, but no factual verb comes before the infinitive",
                        "Ich habe vor, bei Acme zu arbeiten.",
                        CVData(experience: [job("", "Acme")]), .exactly(CVData()), language: "de"))
        rows.append(row("no-job-from-going-to-contracted-en",
                        "I'm going to work: going is no listed verb and work an infinitive, so no Acme job and no 2027",
                        "I'm going to work at Acme from 2027.",
                        CVData(experience: [job("", "Acme", from: "2027")]), .exactly(CVData())))

        typealias ToBe = (language: String, present: String, past: String, title: String)
        var toBe: [ToBe] = []
        toBe.append(("en", "I am a nurse at Acme since 2016.", "I was a nurse at Acme in 2012.", "nurse"))
        toBe.append(("it", "Sono infermiera presso Acme dal 2016.", "Ero infermiera presso Acme nel 2012.", "infermiera"))
        toBe.append(("de", "Ich bin Krankenschwester bei Acme seit 2016.", "Ich war Krankenschwester bei Acme 2012.", "Krankenschwester"))
        toBe.append(("es", "Soy enfermera en Acme desde 2016.", "Era enfermera en Acme en 2012.", "enfermera"))
        toBe.append(("fr", "Je suis infirmière chez Acme depuis 2016.", "J'étais infirmière chez Acme en 2012.", "infirmière"))
        toBe.append(("pt", "Sou enfermeira na Acme desde 2016.", "Era enfermeira na Acme em 2012.", "enfermeira"))
        for v in toBe {
            rows.append(row("to-be-present-keeps-the-job-\(v.language)",
                            "the present of to be is a factual verb: the job and its year stay",
                            v.present, CVData(experience: [job(v.title, "Acme", from: "2016")]), .unchanged, language: v.language))
            rows.append(row("to-be-past-keeps-the-job-\(v.language)",
                            "the past of to be is a factual verb: the job and its year stay",
                            v.past, CVData(experience: [job(v.title, "Acme", from: "2012")]), .unchanged, language: v.language))
        }
        rows.append(row("to-be-contracted-keeps-the-job-en",
                        "a contraction counts as its full form: I'm a nurse at Acme is factual, and the job keeps 2016",
                        "I'm a nurse at Acme since 2016.",
                        CVData(experience: [job("nurse", "Acme", from: "2016")]), .unchanged))

        // The words from the verb of a purpose to the end of the clause give no facts: no achievement, no figure.
        rows.append(row("purpose-tail-gives-no-facts-nurses-en",
                        "to train 3 nurses is a purpose after a factual statement: it gives no achievement",
                        "I worked at Acme to train 3 nurses.",
                        CVData(experience: [job("", "Acme", achievements: ["trained 3 nurses"])]),
                        .exactly(CVData(experience: [job("", "Acme")]))))
        typealias Tail = (language: String, description: String, achievement: String)
        var tails: [Tail] = []
        tails.append(("en", "I worked at Acme to teach 3 courses.", "taught 3 courses"))
        tails.append(("it", "Ho lavorato presso Acme per insegnare 3 corsi.", "insegnato 3 corsi"))
        tails.append(("de", "Ich habe bei Acme gearbeitet, um 3 Kurse zu unterrichten.", "3 Kurse unterrichtet"))
        tails.append(("es", "Trabajé en Acme para enseñar 3 cursos.", "enseñé 3 cursos"))
        tails.append(("fr", "J'ai travaillé chez Acme pour enseigner 3 cours.", "enseigné 3 cours"))
        tails.append(("pt", "Trabalhei na Acme para lecionar 3 cursos.", "lecionei 3 cursos"))
        for v in tails {
            rows.append(row("purpose-tail-gives-no-facts-\(v.language)",
                            "the words from the verb of a purpose on give no facts: the achievement goes and the job stays",
                            v.description, CVData(experience: [job("", "Acme", achievements: [v.achievement])]),
                            .exactly(CVData(experience: [job("", "Acme")])), language: v.language))
        }
        rows.append(row("purpose-tail-leaves-the-statement-en",
                        "taught 3 courses stops before at Acme, the end of the statement: it is no quote, so the achievement goes",
                        "I taught 3 courses at Acme to support students.",
                        CVData(experience: [job("", "Acme", achievements: ["taught 3 courses"])]), .exactly(CVData(experience: [job("", "Acme")]))))
        rows.append(row("purpose-tail-leaves-the-statement-quoted-en",
                        "the statement up to the purpose is a quote: its achievement stays, and to support students gives nothing",
                        "I taught 3 courses at Acme to support students.",
                        CVData(experience: [job("", "Acme", achievements: ["taught 3 courses at Acme"])]), .unchanged))
        return rows
    }

    // MARK: Every word before the name of a mention is explained (c)

    /// The device tags the verbs of some languages only, so every word before the name, or before the clause's first factual
    /// verb, must be explained by the closed vocabulary or by the entry's or the person's own quotes: a verb the lists do not
    /// hold, a word of search or of dream, cannot slip in unseen.
    private static func wordsBeforeTheName() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        typealias Dream = (language: String, before: String, after: String)
        var dreams: [Dream] = []
        dreams.append(("en", "I dream of Acme from 2027.", "At Acme I dream of working."))
        dreams.append(("it", "Sogno Acme dal 2027.", "Presso Acme sogno di lavorare."))
        dreams.append(("de", "Ich träume von Acme ab 2027.", "Bei Acme träume ich davon zu arbeiten."))
        dreams.append(("es", "Sueño con Acme desde 2027.", "En Acme sueño con trabajar."))
        dreams.append(("fr", "Je rêve d'Acme depuis 2027.", "Chez Acme je rêve de travailler."))
        dreams.append(("pt", "Sonho com a Acme desde 2027.", "Na Acme sonho em trabalhar."))
        for v in dreams {
            rows.append(row("no-job-from-a-dream-\(v.language)",
                            "dream is a verb the lists do not hold, and it stands before the name: the word is not explained, so no Acme job and no 2027",
                            v.before, CVData(experience: [job("", "Acme", from: "2027")]), .exactly(CVData()), language: v.language))
            rows.append(row("no-job-from-a-dream-after-the-name-\(v.language)",
                            "the name comes first, then a word nothing explains before any factual verb: the mention is not factual",
                            v.after, CVData(experience: [job("", "Acme")]), .exactly(CVData()), language: v.language))
        }

        typealias Search = (language: String, title: String, titleOnly: String, withEmployer: String)
        var searches: [Search] = []
        searches.append(("en", "nurse", "I'm looking for a job as a nurse in Rome.", "I'm looking for a job at Acme as a nurse."))
        searches.append(("it", "infermiera", "Cerco lavoro come infermiera a Roma.", "Cerco lavoro presso Acme come infermiera."))
        searches.append(("de", "Krankenschwester", "Ich suche eine Stelle als Krankenschwester.", "Ich suche eine Stelle bei Acme als Krankenschwester."))
        searches.append(("es", "enfermera", "Busco trabajo como enfermera.", "Busco trabajo en Acme como enfermera."))
        searches.append(("fr", "infirmière", "Je cherche un emploi d'infirmière.", "Je cherche un emploi chez Acme comme infirmière."))
        searches.append(("pt", "enfermeira", "Procuro emprego como enfermeira.", "Procuro emprego na Acme como enfermeira."))
        for v in searches {
            rows.append(row("a-job-search-is-no-job-\(v.language)",
                            "looking for a job is no job: the words of the search before the title are not explained, so no entry",
                            v.titleOnly, CVData(experience: [job(v.title)]), .exactly(CVData()), language: v.language))
            rows.append(row("a-job-search-at-an-employer-is-no-job-\(v.language)",
                            "looking for a job at Acme is no job at Acme: the words of the search before the name are not explained",
                            v.withEmployer, CVData(experience: [job(v.title, "Acme")]), .exactly(CVData()), language: v.language))
        }

        // Controls: the words before the name are function words, words of time and listed verbs.
        typealias Plain = (language: String, description: String)
        var plain: [Plain] = []
        plain.append(("en", "Then I also worked at Acme."))
        plain.append(("it", "Poi ho anche lavorato presso Acme."))
        plain.append(("de", "Dann habe ich auch bei Acme gearbeitet."))
        plain.append(("es", "Luego también trabajé en Acme."))
        plain.append(("fr", "Ensuite j'ai aussi travaillé chez Acme."))
        plain.append(("pt", "Depois também trabalhei na Acme."))
        for v in plain {
            rows.append(row("words-before-the-name-are-explained-\(v.language)",
                            "function words and a listed verb before the name are all explained: the job stays",
                            v.description, CVData(experience: [job("", "Acme")]), .unchanged, language: v.language))
        }

        // Accepted losses, by the letter: a title the draft does not quote is a word nothing explains before the name.
        typealias Title = (language: String, description: String)
        var titles: [Title] = []
        titles.append(("en", "Engineer at Acme, 2016\u{2013}2020."))
        titles.append(("it", "Ingegnere presso Acme, 2016\u{2013}2020."))
        titles.append(("de", "Ingenieur bei Acme, 2016\u{2013}2020."))
        titles.append(("es", "Ingeniero en Acme, 2016\u{2013}2020."))
        titles.append(("fr", "Ingénieur chez Acme, 2016\u{2013}2020."))
        titles.append(("pt", "Engenheiro na Acme, 2016\u{2013}2020."))
        for v in titles {
            rows.append(row("a-title-the-draft-does-not-quote-is-an-accepted-loss-\(v.language)",
                            "the title stands before the name and the draft does not quote it: nothing explains it, so the job is lost (accepted)",
                            v.description, CVData(experience: [job("", "Acme", from: "2016", to: "2020")]), .exactly(CVData()), language: v.language))
        }
        rows.append(row("a-title-of-several-words-the-draft-does-not-quote-is-an-accepted-loss-en",
                        "licensed and practical are words nothing explains before the name: the job is lost (accepted)",
                        "Licensed practical nurse at Acme, 2016-2020.",
                        CVData(experience: [job("", "Acme", from: "2016", to: "2020")]), .exactly(CVData())))
        rows.append(row("participle-after-the-name-is-a-detail-en",
                        "obtained comes after the name and a factual verb: a detail, so PALS stays and 2019 is not given",
                        "I hold PALS obtained in 2019.",
                        CVData(certifications: [Certification(name: "PALS", date: "2019")]),
                        .exactly(CVData(certifications: [Certification(name: "PALS")]))))
        return rows
    }

    // MARK: A verbless clause belongs to the clause before it (c)

    /// A verbless clause split off by a comma or a conjunction belongs to the clause before it in its sentence, and is factual only
    /// if that clause is: "I have never worked at Acme or Beta" gives no Beta, "I worked at Acme, Beta and Gamma" keeps all three.
    private static func coordinatedMentions() -> [GroundingRow] {
        typealias Variant = (language: String, denied: String, wish: String, future: String, search: String, factual: String)
        var variants: [Variant] = []
        variants.append(("en", "I have never worked at Acme or Beta.", "I would like to work at Acme, Beta or Gamma.", "I will join Acme or Beta.",
                         "I'm looking for a job at Acme or Beta.", "I worked at Acme, Beta and Gamma."))
        variants.append(("it", "Non ho mai lavorato presso Acme o Beta.", "Vorrei lavorare presso Acme, Beta o Gamma.", "Entrerò in Acme o Beta.",
                         "Cerco lavoro presso Acme o Beta.", "Ho lavorato presso Acme, Beta e Gamma."))
        variants.append(("de", "Ich arbeite nie bei Acme oder Beta.", "Ich möchte bei Acme, Beta oder Gamma arbeiten.", "Ich werde bei Acme oder Beta anfangen.",
                         "Ich suche eine Stelle bei Acme oder Beta.", "Ich arbeite bei Acme, Beta und Gamma."))
        variants.append(("es", "Nunca he trabajado en Acme o Beta.", "Me gustaría trabajar en Acme, Beta o Gamma.", "Entraré en Acme o Beta.",
                         "Busco trabajo en Acme o Beta.", "Trabajé en Acme, Beta y Gamma."))
        variants.append(("fr", "Je n'ai jamais travaillé chez Acme ou Beta.", "Je voudrais travailler chez Acme, Beta ou Gamma.", "Je rejoindrai Acme ou Beta.",
                         "Je cherche un emploi chez Acme ou Beta.", "J'ai travaillé chez Acme, Beta et Gamma."))
        variants.append(("pt", "Nunca trabalhei na Acme ou na Beta.", "Gostaria de trabalhar na Acme, na Beta ou na Gamma.", "Entrarei na Acme ou na Beta.",
                         "Procuro emprego na Acme ou na Beta.", "Trabalhei na Acme, na Beta e na Gamma."))

        var rows: [GroundingRow] = []
        for v in variants {
            let two = CVData(experience: [job("", "Acme"), job("", "Beta")])
            let three = CVData(experience: [job("", "Acme"), job("", "Beta"), job("", "Gamma")])
            rows.append(row("no-experience-from-a-denied-coordination-\(v.language)",
                            "Beta stands after or in a clause that denies the work: it belongs to that clause, so there is no Beta",
                            v.denied, CVData(experience: [job("", "Beta")]), .exactly(CVData()), language: v.language))
            rows.append(row("no-experience-from-a-coordinated-wish-\(v.language)",
                            "Beta and Gamma stand after a wish: they belong to the clause of the wish, so there is none of the three",
                            v.wish, three, .exactly(CVData()), language: v.language))
            rows.append(row("no-experience-from-a-coordinated-future-\(v.language)",
                            "Beta stands after a future: it belongs to that clause, so there is neither Acme nor Beta",
                            v.future, two, .exactly(CVData()), language: v.language))
            rows.append(row("no-experience-from-a-coordinated-search-\(v.language)",
                            "Beta stands after a job search: it belongs to that clause, so there is neither Acme nor Beta",
                            v.search, two, .exactly(CVData()), language: v.language))
            rows.append(row("coordinated-mentions-stay-\(v.language)",
                            "Beta and Gamma belong to a clause that states the work: all three jobs stay",
                            v.factual, three, .unchanged, language: v.language))
        }
        return rows
    }

    // MARK: A prose clause quotes one clause of the description (d)

    /// Each clause of a summary sentence, a role description or an achievement quotes one clause of the description: the same
    /// words, in the same forms and order, running to the clause's end, after an optional lead-in of pronouns and joining words.
    /// No lemma is used.
    private static func proseQuotesOneClause() -> [GroundingRow] {
        typealias Variant = (
            language: String, clause: String, leftOut: String, tense: String?, person: String, inflection: String?, reordered: String?, early: String
        )
        var variants: [Variant] = []
        variants.append(("en", "I managed the school library in Rome.", "I managed the library in Rome.", "I manage the school library in Rome.",
                         "She managed the school library in Rome.", "I managed the school libraries in Rome.",
                         "I managed in Rome the school library.", "I managed the school library."))
        variants.append(("it", "Ho gestito la biblioteca della scuola a Roma.", "Ho gestito la biblioteca a Roma.",
                         "Gestisco la biblioteca della scuola a Roma.", "Ha gestito la biblioteca della scuola a Roma.",
                         "Ho gestito le biblioteche della scuola a Roma.", "Ho gestito a Roma la biblioteca della scuola.",
                         "Ho gestito la biblioteca della scuola."))
        variants.append(("de", "Ich habe die Schulbibliothek in Rom geleitet.", "Ich habe in Rom geleitet.", "Ich leite die Schulbibliothek in Rom.",
                         "Sie hat die Schulbibliothek in Rom geleitet.", "Ich habe die Schulbibliotheken in Rom geleitet.",
                         "Ich habe in Rom die Schulbibliothek geleitet.", "Ich habe die Schulbibliothek in Rom."))
        variants.append(("es", "Dirigí la biblioteca de la escuela en Roma.", "Dirigí la biblioteca en Roma.", nil,
                         "Dirigió la biblioteca de la escuela en Roma.", nil, nil, "Dirigí la biblioteca de la escuela."))
        variants.append(("fr", "J'ai dirigé la bibliothèque de l'école à Rome.", "J'ai dirigé la bibliothèque à Rome.", nil,
                         "Elle a dirigé la bibliothèque de l'école à Rome.", nil, nil, "J'ai dirigé la bibliothèque de l'école."))
        variants.append(("pt", "Dirigi a biblioteca da escola em Roma.", "Dirigi a biblioteca em Roma.", nil,
                         "Dirigiu a biblioteca da escola em Roma.", nil, nil, "Dirigi a biblioteca da escola."))

        func summary(_ text: String, from description: String, as id: String, _ language: String, _ reason: String, keeps: Bool) -> GroundingRow {
            row(id + "-" + language, reason, description, CVData(summary: text), keeps ? .unchanged : .exactly(CVData()), language: language)
        }

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(summary(v.clause, from: v.clause, as: "quote-keeps-the-clause", v.language,
                                "the sentence is the clause of the description, word for word: it stays", keeps: true))
            rows.append(summary(v.leftOut, from: v.clause, as: "quote-with-a-word-left-out", v.language,
                                "a word left out of the middle of the clause makes it no quote: the sentence goes", keeps: false))
            rows.append(summary(v.person, from: v.clause, as: "quote-with-another-person", v.language,
                                "the same claim about someone else is no quote: the sentence goes", keeps: false))
            rows.append(summary(v.early, from: v.clause, as: "quote-that-stops-early", v.language,
                                "a quote that stops before the clause's end is no quote: the sentence goes", keeps: false))
            if let tense = v.tense {
                rows.append(summary(tense, from: v.clause, as: "quote-with-another-tense", v.language,
                                    "another tense is another form of the verb: no quote, so the sentence goes", keeps: false))
            }
            if let inflection = v.inflection {
                rows.append(summary(inflection, from: v.clause, as: "quote-with-another-inflection", v.language,
                                    "no lemma is used: the plural of a noun is another form, so the sentence goes", keeps: false))
            }
            if let reordered = v.reordered {
                rows.append(summary(reordered, from: v.clause, as: "quote-reordered", v.language,
                                    "the same words in another order are no quote: the sentence goes", keeps: false))
            }
        }

        typealias Lead = (language: String, description: String, summary: String)
        var leads: [Lead] = []
        leads.append(("en", "I worked in Rome, where I trained interns.", "Trained interns."))
        leads.append(("it", "Ho lavorato a Roma, dove ho formato tirocinanti.", "Ho formato tirocinanti."))
        leads.append(("de", "Ich habe in Rom gearbeitet, wo ich Praktikanten ausgebildet habe.", "Praktikanten ausgebildet habe."))
        leads.append(("es", "Trabajé en Roma, donde formé a becarios.", "Formé a becarios."))
        leads.append(("fr", "J'ai travaillé à Rome, où j'ai formé des stagiaires.", "J'ai formé des stagiaires."))
        leads.append(("pt", "Trabalhei em Roma, onde formei estagiários.", "Formei estagiários."))
        for v in leads {
            rows.append(summary(v.summary, from: v.description, as: "quote-without-its-lead-in", v.language,
                                "where I and its kin are a lead-in of joining words and a pronoun: a quote may leave it out, and the sentence stays",
                                keeps: true))
        }
        return rows
    }

    /// A quote keeps the user's own claim, with its subject, its voice and its negation: "I was trained by Acme" does not keep "I
    /// trained Acme", and "My colleague managed a school" does not keep "I managed a school".
    private static func proseKeepsWhoDidWhat() -> [GroundingRow] {
        typealias Voice = (language: String, passive: String, active: String)
        var voices: [Voice] = []
        voices.append(("en", "I was trained by Acme.", "I trained Acme."))
        voices.append(("it", "Sono stata formata da Acme.", "Ho formato Acme."))
        voices.append(("de", "Ich wurde von Acme ausgebildet.", "Ich habe Acme ausgebildet."))
        voices.append(("es", "Fui formada por Acme.", "Formé a Acme."))
        voices.append(("fr", "J'ai été formée par Acme.", "J'ai formé Acme."))
        voices.append(("pt", "Fui formada pela Acme.", "Formei a Acme."))

        var rows: [GroundingRow] = []
        for v in voices {
            let quoted = String(v.passive.dropLast())
            let reversed = String(v.active.dropLast())
            rows.append(row("summary-reverses-who-did-what-\(v.language)",
                            "the sentence says Acme was trained by me, the description says the opposite: it is no quote, so it goes",
                            v.passive, CVData(summary: v.active), .exactly(CVData()), language: v.language))
            rows.append(row("summary-quotes-who-did-what-\(v.language)",
                            "the sentence is the clause of the description: it stays",
                            v.passive, CVData(summary: v.passive), .unchanged, language: v.language))
            rows.append(row("role-and-achievement-reverse-who-did-what-\(v.language)",
                            "the role text and the achievement reverse who trained whom: they are no quotes, so they go",
                            v.passive, CVData(experience: [job("", "Acme", description: v.active, achievements: [reversed])]),
                            .exactly(CVData(experience: [job("", "Acme")])), language: v.language))
            rows.append(row("role-and-achievement-quote-who-did-what-\(v.language)",
                            "the role text and the achievement are the clause of the description: they stay",
                            v.passive, CVData(experience: [job("", "Acme", description: v.passive, achievements: [quoted])]),
                            .unchanged, language: v.language))
        }

        typealias Colleague = (language: String, colleague: String, mine: String)
        var colleagues: [Colleague] = []
        colleagues.append(("en", "My colleague managed a school.", "I managed a school."))
        colleagues.append(("it", "La mia collega ha gestito una scuola.", "Ho gestito una scuola."))
        colleagues.append(("de", "Meine Kollegin hat eine Schule geleitet.", "Ich habe eine Schule geleitet."))
        colleagues.append(("es", "Mi colega dirigió una escuela.", "Dirigí una escuela."))
        colleagues.append(("fr", "Ma collègue a dirigé une école.", "J'ai dirigé une école."))
        colleagues.append(("pt", "A minha colega dirigiu uma escola.", "Dirigi uma escola."))
        for v in colleagues {
            rows.append(row("summary-of-a-colleague-is-not-mine-\(v.language)",
                            "the description says what a colleague did: a sentence that makes it the person's own drops the subject, so it goes",
                            v.colleague, CVData(summary: v.mine), .exactly(CVData()), language: v.language))
            rows.append(row("summary-of-a-colleague-quoted-\(v.language)",
                            "the clause has another subject (a colleague): it speaks for someone else, so it is never quoted, subject and all",
                            v.colleague, CVData(summary: v.colleague), .exactly(CVData()), language: v.language))
        }
        return rows
    }

    // MARK: The person is the subject (c)

    /// A clause speaks for the person only when its subject is a first-person pronoun, or is absent the way a CV writes. In the
    /// pro-drop languages a listed verb form must be first person singular. A clause with another subject backs nothing, gives no
    /// mention and is never quoted; a clause that starts with its verb after a conjunction or a comma shares the subject of the
    /// clause before it.
    private static func thePersonIsTheSubject() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        typealias Sister = (language: String, description: String, summary: String)
        var sisters: [Sister] = []
        sisters.append(("en", "My sister is a nurse and worked at Acme.", "Worked at Acme."))
        sisters.append(("it", "Mia sorella è infermiera e ha lavorato presso Acme.", "Ha lavorato presso Acme."))
        sisters.append(("de", "Meine Schwester ist Krankenschwester und hat bei Acme gearbeitet.", "Hat bei Acme gearbeitet."))
        sisters.append(("es", "Mi hermana es enfermera y trabajó en Acme.", "Trabajó en Acme."))
        sisters.append(("fr", "Ma sœur est infirmière et a travaillé chez Acme.", "A travaillé chez Acme."))
        sisters.append(("pt", "Minha irmã é enfermeira e trabalhou na Acme.", "Trabalhou na Acme."))
        for v in sisters {
            rows.append(row("summary-of-a-subjectless-clause-is-not-mine-\(v.language)",
                            "the clause starts with its verb after and: it shares the subject of the clause before it, my sister, so it is never quoted",
                            v.description, CVData(summary: v.summary), .exactly(CVData()), language: v.language))
            rows.append(row("job-of-a-subjectless-clause-is-not-mine-\(v.language)",
                            "the clause that names Acme shares the subject of the clause before it, my sister: it gives no mention, so no Acme job",
                            v.description, CVData(experience: [job("", "Acme")]), .exactly(CVData()), language: v.language))
        }

        typealias Third = (language: String, description: String)
        var thirds: [Third] = []
        thirds.append(("en", "She worked at Acme since 2016."))
        thirds.append(("it", "Lei lavora presso Acme dal 2016."))
        thirds.append(("de", "Er arbeitet seit 2016 bei Acme."))
        thirds.append(("es", "Ella trabaja en Acme desde 2016."))
        thirds.append(("fr", "Elle travaille chez Acme depuis 2016."))
        thirds.append(("pt", "Ela trabalha na Acme desde 2016."))
        for v in thirds {
            rows.append(row("a-third-person-subject-gives-no-job-\(v.language)",
                            "the subject is she, not the person: the clause gives no mention, so no Acme job and no 2016",
                            v.description, CVData(experience: [job("", "Acme", from: "2016")]), .exactly(CVData()), language: v.language))
        }

        typealias ProDrop = (language: String, third: String, first: String)
        var proDrops: [ProDrop] = []
        proDrops.append(("it", "Ha lavorato presso Acme dal 2012.", "Ho lavorato presso Acme dal 2012."))
        proDrops.append(("es", "Trabajó en Acme desde 2012.", "Trabajé en Acme desde 2012."))
        proDrops.append(("pt", "Trabalhou na Acme desde 2012.", "Trabalhei na Acme desde 2012."))
        for v in proDrops {
            rows.append(row("a-third-person-verb-form-gives-no-job-\(v.language)",
                            "without a pronoun the verb form tells the subject: a third person is not the person, so no Acme job",
                            v.third, CVData(experience: [job("", "Acme", from: "2012")]), .exactly(CVData()), language: v.language))
            rows.append(row("a-first-person-verb-form-keeps-the-job-\(v.language)",
                            "the same clause in the first person speaks for the person: the job and its year stay",
                            v.first, CVData(experience: [job("", "Acme", from: "2012")]), .unchanged, language: v.language))
        }

        typealias Shared = (language: String, shared: String, subjectless: String)
        var shareds: [Shared] = []
        shareds.append(("en", "I worked at Acme and trained 3 teachers.", "Worked at Acme, 2012\u{2013}2016."))
        shareds.append(("it", "Ho lavorato presso Acme e ho formato 3 insegnanti.", "Ho lavorato presso Acme, 2012\u{2013}2016."))
        shareds.append(("de", "Ich habe bei Acme gearbeitet und 3 Lehrkräfte ausgebildet.", "Bei Acme gearbeitet, 2012\u{2013}2016."))
        shareds.append(("es", "Trabajé en Acme y formé a 3 maestros.", "Trabajé en Acme, 2012\u{2013}2016."))
        shareds.append(("fr", "J'ai travaillé chez Acme et j'ai formé 3 enseignants.", "Travaillé chez Acme, 2012\u{2013}2016."))
        shareds.append(("pt", "Trabalhei na Acme e formei 3 professores.", "Trabalhei na Acme, 2012\u{2013}2016."))
        for v in shareds {
            rows.append(row("a-shared-first-person-keeps-the-job-\(v.language)",
                            "both clauses speak in the first person, the second sharing the subject of the first: the job stays",
                            v.shared, CVData(experience: [job("", "Acme")]), .unchanged, language: v.language))
            rows.append(row("a-subjectless-cv-clause-keeps-the-job-\(v.language)",
                            "a clause without a subject, as a CV writes, speaks for the person: the job and its years stay",
                            v.subjectless, CVData(experience: [job("", "Acme", from: "2012", to: "2016")]), .unchanged, language: v.language))
        }

        typealias Manager = (language: String, description: String)
        var managers: [Manager] = []
        managers.append(("en", "My manager Anna praised my work."))
        managers.append(("it", "Il mio responsabile Anna ha apprezzato il mio lavoro."))
        managers.append(("de", "Meine Chefin Anna hat meine Arbeit gelobt."))
        managers.append(("es", "Mi jefa Anna elogió mi trabajo."))
        managers.append(("fr", "Ma responsable Anna a félicité mon travail."))
        managers.append(("pt", "Minha chefe Anna elogiou meu trabalho."))
        for v in managers {
            rows.append(row("a-clause-about-a-third-person-is-never-the-summary-\(v.language)",
                            "the subject is my manager Anna: the clause speaks for her, so the sentence is never quoted",
                            v.description, CVData(summary: v.description), .exactly(CVData()), language: v.language))
        }
        return rows
    }

    // MARK: The explicit subject (c)

    /// The explicit subject is the noun phrase before the clause's first verb (in German, the phrase right after the verb when a
    /// phrase of time or place comes first). Only a first-person pronoun counts as the person: a noun ("a nurse"), a name
    /// ("Alice"), a third-person pronoun or a possession ("my sister") never does, even when the draft quotes the same word as a
    /// title. A clause with another subject backs nothing, gives no mention and is never quoted.
    ///
    /// Open point, not pinned by these rows: "My email is ..." and "My English is fluent." have a possession as their subject
    /// as well. The contact and level rows that use them keep the field, as they did before the amendment.
    private static func theExplicitSubject() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        typealias Noun = (language: String, description: String, title: String)
        var nurses: [Noun] = []
        nurses.append(("en", "A nurse worked at Acme in 2019.", "nurse"))
        nurses.append(("it", "Un infermiere ha lavorato presso Acme nel 2019.", "infermiere"))
        nurses.append(("de", "Eine Krankenschwester hat 2019 bei Acme gearbeitet.", "Krankenschwester"))
        nurses.append(("es", "Una enfermera trabajó en Acme en 2019.", "enfermera"))
        nurses.append(("fr", "Une infirmière a travaillé chez Acme en 2019.", "infirmière"))
        nurses.append(("pt", "Uma enfermeira trabalhou na Acme em 2019.", "enfermeira"))
        for v in nurses {
            rows.append(row("a-noun-subject-quoted-as-the-title-gives-nothing-\(v.language)",
                            "the subject is a nurse, a noun: the clause speaks for someone else, so no Acme job, no 2019, and the title goes with it though the draft quotes it from this very clause",
                            v.description, CVData(experience: [job(v.title, "Acme", from: "2019")]), .exactly(CVData()), language: v.language))
        }

        typealias Named = (language: String, description: String)
        var alices: [Named] = []
        alices.append(("en", "Alice managed a school."))
        alices.append(("it", "Alice ha gestito una scuola."))
        alices.append(("de", "Alice hat eine Schule geleitet."))
        alices.append(("es", "Alice dirigió una escuela."))
        alices.append(("fr", "Alice a dirigé une école."))
        alices.append(("pt", "Alice dirigiu uma escola."))
        for v in alices {
            rows.append(row("a-name-subject-gives-no-summary-\(v.language)",
                            "the subject is Alice, a name and not the person: the sentence speaks for someone else, so it is never the summary",
                            v.description, CVData(summary: v.description), .exactly(CVData()), language: v.language))
        }

        typealias Sister = (language: String, description: String, spoken: String)
        var sisters: [Sister] = []
        sisters.append(("en", "My sister speaks French (C2).", "French"))
        sisters.append(("it", "Mia sorella parla francese (C2).", "francese"))
        sisters.append(("de", "Meine Schwester spricht Französisch (C2).", "Französisch"))
        sisters.append(("es", "Mi hermana habla francés (C2).", "francés"))
        sisters.append(("fr", "Ma sœur parle français (C2).", "français"))
        sisters.append(("pt", "Minha irmã fala francês (C2).", "francês"))
        for v in sisters {
            rows.append(row("a-possession-subject-gives-no-language-\(v.language)",
                            "the subject is my sister, a possession: the clause speaks for someone else, so no French and no C2",
                            v.description, CVData(languages: [Language(name: v.spoken, proficiency: .c2)]), .exactly(CVData()), language: v.language))
        }

        var doctors: [Named] = []
        doctors.append(("en", "The doctor worked at Acme."))
        doctors.append(("it", "Il medico ha lavorato presso Acme."))
        doctors.append(("de", "Der Arzt hat bei Acme gearbeitet."))
        doctors.append(("es", "El médico trabajó en Acme."))
        doctors.append(("fr", "Le médecin a travaillé chez Acme."))
        doctors.append(("pt", "O médico trabalhou na Acme."))
        for v in doctors {
            rows.append(row("a-noun-subject-gives-no-job-\(v.language)",
                            "the subject is the doctor, a noun: the clause gives no mention, so no Acme job",
                            v.description, CVData(experience: [job("", "Acme")]), .exactly(CVData()), language: v.language))
        }

        var doctorsSince: [Noun] = []
        doctorsSince.append(("en", "The doctor worked at Acme from 2016.", "doctor"))
        doctorsSince.append(("it", "Il medico ha lavorato presso Acme dal 2016.", "medico"))
        doctorsSince.append(("de", "Der Arzt hat seit 2016 bei Acme gearbeitet.", "Arzt"))
        doctorsSince.append(("es", "El médico trabajó en Acme desde 2016.", "médico"))
        doctorsSince.append(("fr", "Le médecin a travaillé chez Acme depuis 2016.", "médecin"))
        doctorsSince.append(("pt", "O médico trabalhou na Acme desde 2016.", "médico"))
        for v in doctorsSince {
            let clause = String(v.description.dropLast())
            rows.append(row("a-noun-subject-quoted-as-the-title-gives-no-entry-\(v.language)",
                            "the draft quotes the subject as the title and the clause as the role text: the clause is still another subject's, so no entry, no 2016, no quote",
                            v.description,
                            CVData(experience: [job(v.title, "Acme", from: "2016", description: clause)]),
                            .exactly(CVData()), language: v.language))
        }

        var marcos: [Named] = []
        marcos.append(("en", "Marco worked at Acme."))
        marcos.append(("it", "Marco ha lavorato presso Acme."))
        marcos.append(("de", "Marco hat bei Acme gearbeitet."))
        marcos.append(("es", "Marco trabajó en Acme."))
        marcos.append(("fr", "Marco a travaillé chez Acme."))
        marcos.append(("pt", "Marco trabalhou na Acme."))
        for v in marcos {
            rows.append(row("a-name-subject-gives-no-job-\(v.language)",
                            "the subject is Marco, a name and not the person: the clause gives no mention, so no Acme job",
                            v.description, CVData(experience: [job("", "Acme")]), .exactly(CVData()), language: v.language))
        }

        // The subject after the verb, when a phrase of place comes first. German is the language the ADR names; in the pro-drop
        // languages the third-person verb form says the same. English and French are left out: "At Acme worked a nurse" reads as a
        // CV clause with no subject.
        var inverted: [Noun] = []
        inverted.append(("de", "Bei Acme arbeitete eine Krankenschwester seit 2016.", "Krankenschwester"))
        inverted.append(("it", "Presso Acme ha lavorato un infermiere dal 2016.", "infermiere"))
        inverted.append(("es", "En Acme trabajó una enfermera desde 2016.", "enfermera"))
        inverted.append(("pt", "Na Acme trabalhou uma enfermeira desde 2016.", "enfermeira"))
        for v in inverted {
            rows.append(row("an-inverted-noun-subject-gives-nothing-\(v.language)",
                            "the noun after the verb is the subject: a nurse, not the person, so no Acme job, no 2016 and no title",
                            v.description, CVData(experience: [job(v.title, "Acme", from: "2016")]), .exactly(CVData()), language: v.language))
        }

        // Controls: a phrase before the verb is no subject, and the subject after the verb is the person's.
        var timeFirst: [Named] = []
        timeFirst.append(("en", "Since 2016 I work at Acme."))
        timeFirst.append(("it", "Dal 2016 lavoro presso Acme."))
        timeFirst.append(("de", "Seit 2016 arbeite ich bei Acme."))
        timeFirst.append(("es", "Desde 2016 trabajo en Acme."))
        timeFirst.append(("fr", "Depuis 2016 je travaille chez Acme."))
        timeFirst.append(("pt", "Desde 2016 trabalho na Acme."))
        for v in timeFirst {
            rows.append(row("a-time-phrase-before-the-verb-keeps-the-job-\(v.language)",
                            "the time phrase is no subject, and the subject (or the first-person verb form) is the person's: the job and its year stay",
                            v.description, CVData(experience: [job("", "Acme", from: "2016")]), .unchanged, language: v.language))
        }

        typealias Placed = (language: String, description: String, place: String)
        var placeFirst: [Placed] = []
        placeFirst.append(("en", "In Rome I worked at Acme.", "Rome"))
        placeFirst.append(("it", "A Roma ho lavorato presso Acme.", "Roma"))
        placeFirst.append(("de", "In Rom habe ich bei Acme gearbeitet.", "Rom"))
        placeFirst.append(("es", "En Roma trabajé en Acme.", "Roma"))
        placeFirst.append(("fr", "À Rome j'ai travaillé chez Acme.", "Rome"))
        placeFirst.append(("pt", "Em Roma trabalhei na Acme.", "Roma"))
        for v in placeFirst {
            rows.append(row("a-place-phrase-before-the-verb-keeps-the-job-\(v.language)",
                            "the place is no subject, and the subject (or the first-person verb form) is the person's: the job and its place stay",
                            v.description, CVData(experience: [job("", "Acme", location: v.place)]), .unchanged, language: v.language))
        }

        // After a phrase of time or place, the subject is the next noun phrase: a possession of a person there is someone else.
        rows.append(row("place-before-sister-language",
                        "after the place phrase the subject is my sister, a possession of a person: no French and no C2",
                        "In Rome my sister speaks French (C2).",
                        CVData(languages: [Language(name: "French", proficiency: .c2)]), .exactly(CVData())))
        typealias Spoken = (language: String, description: String, spoken: String)
        var sistersAfterAPlace: [Spoken] = []
        sistersAfterAPlace.append(("it", "A Roma mia sorella parla francese (C2).", "francese"))
        sistersAfterAPlace.append(("de", "In Rom spricht meine Schwester Französisch (C2).", "Französisch"))
        sistersAfterAPlace.append(("es", "En Roma mi hermana habla francés (C2).", "francés"))
        sistersAfterAPlace.append(("fr", "À Rome ma sœur parle français (C2).", "français"))
        sistersAfterAPlace.append(("pt", "Em Roma minha irmã fala francês (C2).", "francês"))
        for v in sistersAfterAPlace {
            rows.append(row("place-before-sister-language-\(v.language)",
                            "after the place phrase the subject is my sister, a possession of a person: no French and no C2",
                            v.description, CVData(languages: [Language(name: v.spoken, proficiency: .c2)]), .exactly(CVData()), language: v.language))
        }

        var personAfterAPlace: [Spoken] = []
        personAfterAPlace.append(("en", "In Rome I speak French (C2).", "French"))
        personAfterAPlace.append(("it", "A Roma parlo francese (C2).", "francese"))
        personAfterAPlace.append(("de", "In Rom spreche ich Französisch (C2).", "Französisch"))
        personAfterAPlace.append(("es", "En Roma hablo francés (C2).", "francés"))
        personAfterAPlace.append(("fr", "À Rome je parle français (C2).", "français"))
        personAfterAPlace.append(("pt", "Em Roma falo francês (C2).", "francês"))
        for v in personAfterAPlace {
            rows.append(row(v.language == "en" ? "place-before-i-keeps-the-language" : "place-before-i-keeps-the-language-\(v.language)",
                            "after the place phrase the subject is the person (or the first-person verb form): French and C2 stay",
                            v.description, CVData(languages: [Language(name: v.spoken, proficiency: .c2)]), .unchanged, language: v.language))
        }

        // A possessive right after a preposition belongs to the preposition's phrase, and is no subject: "my free time" is no person.
        var freeTime: [Spoken] = []
        freeTime.append(("en", "In my free time I play chess.", "chess"))
        freeTime.append(("it", "Nel mio tempo libero mi piacciono gli scacchi.", "scacchi"))
        freeTime.append(("de", "In meiner Freizeit mag ich Schach.", "Schach"))
        freeTime.append(("es", "En mi tiempo libre me gustan el ajedrez y el senderismo.", "ajedrez"))
        freeTime.append(("fr", "Pendant mon temps libre j'aime les échecs.", "échecs"))
        freeTime.append(("pt", "No meu tempo livre gosto de xadrez.", "xadrez"))
        for v in freeTime {
            rows.append(row(v.language == "en" ? "free-time-is-no-person-keeps-the-interest" : "free-time-is-no-person-keeps-the-interest-\(v.language)",
                            "the possessive opens the phrase of the preposition before it, and owns no subject: the interest stays",
                            v.description, CVData(interests: [v.spoken]), .unchanged, language: v.language))
        }
        return rows
    }

    // MARK: The reader's clause is the person's only as the object of its verb of contacting (c)

    /// A clause addressed to the reader speaks for the person only when the person is the object of its verb of contacting: "reach
    /// me", "contattarmi", "mi potete contattare", "erreichen Sie mich", "contactez-moi", "contáctame", "contacte-me". A third
    /// party right after the verb ("reach my manager") makes it another person's clause, even when a first-person word follows.
    private static func theReadersObject() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        rows.append(row("reader-manager-through-me",
                        "the object of reach is my manager, a third party: the me of through me is no object of it, so no email",
                        "You can reach my manager through me at boss@example.com.",
                        CVData(personalInfo: person(email: "boss@example.com")), .exactly(CVData())))
        typealias Addressed = (language: String, description: String)
        var managers: [Addressed] = []
        managers.append(("it", "Puoi contattare il mio responsabile tramite me a boss@example.com."))
        managers.append(("de", "Du kannst meinen Chef über mich unter boss@example.com erreichen."))
        managers.append(("es", "Puedes contactar a mi jefe a través de mí en boss@example.com."))
        managers.append(("fr", "Vous pouvez contacter mon responsable via moi à boss@example.com."))
        managers.append(("pt", "Você pode contatar meu chefe através de mim em boss@example.com."))
        for v in managers {
            rows.append(row("reader-manager-through-me-\(v.language)",
                            "the object of the verb of contacting is my manager, a third party: the first-person word after it is no object of it, so no email",
                            v.description, CVData(personalInfo: person(email: "boss@example.com")), .exactly(CVData()), language: v.language))
        }

        typealias Reached = (id: String, language: String, description: String)
        var reachMe: [Reached] = []
        reachMe.append(("reader-reach-me-keeps-the-email", "en", "You can reach me at me@example.com."))
        reachMe.append(("reader-contact-me-keeps-the-email", "en", "Contact me at me@example.com."))
        reachMe.append(("reader-write-to-me-keeps-the-email", "en", "Write to me at me@example.com."))
        reachMe.append(("reader-email-me-keeps-the-email", "en", "Email me at me@example.com."))
        reachMe.append(("reader-contattarmi-keeps-the-email-it", "it", "Puoi contattarmi a me@example.com."))
        reachMe.append(("reader-scrivermi-keeps-the-email-it", "it", "Potete scrivermi a me@example.com."))
        reachMe.append(("reader-mi-potete-contattare-keeps-the-email-it", "it", "Mi potete contattare a me@example.com."))
        reachMe.append(("reader-erreichen-sie-mich-keeps-the-email-de", "de", "Erreichen Sie mich unter me@example.com."))
        reachMe.append(("reader-du-kannst-mich-erreichen-keeps-the-email-de", "de", "Du kannst mich unter me@example.com erreichen."))
        reachMe.append(("reader-contactez-moi-keeps-the-email-fr", "fr", "Contactez-moi à me@example.com."))
        reachMe.append(("reader-contactame-keeps-the-email-es", "es", "Contáctame en me@example.com."))
        reachMe.append(("reader-contacte-me-keeps-the-email-pt", "pt", "Contacte-me em me@example.com."))
        for v in reachMe {
            rows.append(row(v.id, "the person is the object of the verb of contacting: the email stays",
                            v.description, CVData(personalInfo: person(email: "me@example.com")), .unchanged, language: v.language))
        }
        rows.append(row("reader-call-me-keeps-the-phone",
                        "the person is the object of call: the phone stays",
                        "Call me on +39 333 123 4567.",
                        CVData(personalInfo: person(phone: "+39 333 123 4567")), .unchanged))
        rows += theReadersObjectInOtherShapes()
        return rows
    }

    /// The same pattern in other shapes: the reader addressed by an imperative, by the form of a verb or by a verb that invites to
    /// contact, and a first-person word before the verb of contacting. Its object, a third party, makes the clause another person's.
    private static func theReadersObjectInOtherShapes() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        typealias Shape = (language: String, description: String)
        func someoneElses(_ id: String, _ reason: String, _ email: String, _ shapes: [Shape]) {
            for v in shapes {
                rows.append(row("\(id)-\(v.language)", reason, v.description, CVData(personalInfo: person(email: email)), .exactly(CVData()),
                                language: v.language))
            }
        }

        var agents: [Shape] = []
        agents.append(("en", "Contact my agent at agent@example.com."))
        agents.append(("it", "Contatta il mio agente a agent@example.com."))
        agents.append(("de", "Kontaktieren Sie meinen Agenten unter agent@example.com."))
        agents.append(("es", "Contacta a mi agente en agent@example.com."))
        agents.append(("fr", "Contactez mon agent à agent@example.com."))
        agents.append(("pt", "Contate meu agente em agent@example.com."))
        someoneElses("imperative-contact-my-agent", "an imperative addresses the reader, and its object is my agent: no email",
                     "agent@example.com", agents)

        var notMe: [Shape] = []
        notMe.append(("en", "Contact my agent, not me, at agent@example.com."))
        notMe.append(("it", "Contatta il mio agente, non me, a agent@example.com."))
        notMe.append(("de", "Kontaktieren Sie meinen Agenten, nicht mich, unter agent@example.com."))
        notMe.append(("es", "Contacta a mi agente, no a mí, en agent@example.com."))
        notMe.append(("fr", "Contactez mon agent, pas moi, à agent@example.com."))
        notMe.append(("pt", "Contate meu agente, não a mim, em agent@example.com."))
        someoneElses("contact-my-agent-not-me", "the object of the imperative is my agent, and the clauses after it share its subject: no email",
                     "agent@example.com", notMe)

        var throughMe: [Shape] = []
        throughMe.append(("en", "Through me you can reach my colleague at colleague@example.com."))
        throughMe.append(("it", "Tramite me puoi contattare il mio collega a colleague@example.com."))
        throughMe.append(("de", "Über mich kannst du meinen Kollegen unter colleague@example.com erreichen."))
        throughMe.append(("es", "A través de mí puedes contactar a mi colega en colleague@example.com."))
        throughMe.append(("fr", "Par moi vous pouvez contacter mon collègue à colleague@example.com."))
        throughMe.append(("pt", "Através de mim você pode contatar meu colega em colleague@example.com."))
        someoneElses("reader-through-me-reaches-my-colleague",
                     "the first-person word before the verb belongs to the phrase of through, and the object of the verb is my colleague: no email",
                     "colleague@example.com", throughMe)

        var formal: [Shape] = []
        formal.append(("en", "You can contact my manager at boss@example.com."))
        formal.append(("it", "Può contattare il mio responsabile a boss@example.com."))
        formal.append(("de", "Sie können meinen Chef unter boss@example.com erreichen."))
        formal.append(("es", "Puede contactar a mi jefe en boss@example.com."))
        formal.append(("fr", "Vous pouvez contacter mon responsable à boss@example.com."))
        formal.append(("pt", "Pode contatar meu chefe em boss@example.com."))
        someoneElses("formal-reader-contacts-my-manager", "the reader, named or told by the form of the verb, is to contact my manager: no email",
                     "boss@example.com", formal)

        var writeTo: [Shape] = []
        writeTo.append(("en", "Write to my manager at boss@example.com."))
        writeTo.append(("it", "Scrivi al mio responsabile a boss@example.com."))
        writeTo.append(("de", "Schreiben Sie meinem Chef an boss@example.com."))
        writeTo.append(("es", "Escribe a mi jefe a boss@example.com."))
        writeTo.append(("fr", "Écrivez à mon responsable à boss@example.com."))
        writeTo.append(("pt", "Escreva para o meu chefe em boss@example.com."))
        someoneElses("write-to-my-manager", "write reaches my manager through the preposition it takes: no email", "boss@example.com", writeTo)

        var invited: [Shape] = []
        invited.append(("en", "Feel free to contact my manager at boss@example.com."))
        invited.append(("it", "Non esitate a contattare il mio responsabile a boss@example.com."))
        invited.append(("de", "Zögern Sie nicht, meinen Chef unter boss@example.com zu kontaktieren."))
        invited.append(("es", "No dudes en contactar a mi jefe en boss@example.com."))
        invited.append(("fr", "N'hésitez pas à contacter mon responsable à boss@example.com."))
        invited.append(("pt", "Não hesite em contatar meu chefe em boss@example.com."))
        someoneElses("invited-to-contact-my-manager",
                     "the verb of contacting completes no statement of the person, so it is the reader's, and its object is my manager: no email",
                     "boss@example.com", invited)

        rows.append(row("references-contact-my-former-manager",
                        "the clause after the comma is an imperative whose object is my former manager Anna: no email",
                        "For references, contact my former manager Anna at anna@example.com.",
                        CVData(personalInfo: person(email: "anna@example.com")), .exactly(CVData())))
        rows.append(row("contact-me-or-write-to-my-manager",
                        "the clause after or has its own verb of contacting, whose object is my manager: no email",
                        "Contact me or write to my manager at boss@example.com.",
                        CVData(personalInfo: person(email: "boss@example.com")), .exactly(CVData())))

        // Controls: the person as the object, a purpose of the person's own statement, and a verb of a CV with its work.
        var invitedToMe: [Shape] = []
        invitedToMe.append(("en", "Feel free to contact me at me@example.com."))
        invitedToMe.append(("it", "Non esitate a contattarmi a me@example.com."))
        invitedToMe.append(("de", "Zögern Sie nicht, mich unter me@example.com zu kontaktieren."))
        invitedToMe.append(("es", "No dudes en contactarme en me@example.com."))
        invitedToMe.append(("fr", "N'hésitez pas à me contacter à me@example.com."))
        invitedToMe.append(("pt", "Não hesite em me contatar em me@example.com."))
        for v in invitedToMe {
            rows.append(row("invited-to-contact-me-keeps-the-email-\(v.language)", "the person is the object of the verb of contacting: the email stays",
                            v.description, CVData(personalInfo: person(email: "me@example.com")), .unchanged, language: v.language))
        }

        var purposes: [Shape] = []
        purposes.append(("en", "Worked at Acme to contact new clients."))
        purposes.append(("it", "Ho lavorato presso Acme per contattare nuovi clienti."))
        purposes.append(("de", "Ich habe bei Acme gearbeitet, um neue Kunden zu kontaktieren."))
        purposes.append(("es", "Trabajé en Acme para contactar nuevos clientes."))
        purposes.append(("fr", "J'ai travaillé chez Acme pour contacter de nouveaux clients."))
        purposes.append(("pt", "Trabalhei na Acme para contatar novos clientes."))
        for v in purposes {
            rows.append(row("a-purpose-of-contacting-keeps-the-job-\(v.language)",
                            "the verb of contacting is the purpose of the person's own statement, not the reader's: the job stays",
                            v.description, CVData(experience: [job("", "Acme")]), .unchanged, language: v.language))
        }

        rows.append(row("a-verb-of-a-cv-with-its-work-keeps-the-job",
                        "write takes its work directly, and reaches no one: the job stays",
                        "Write technical documentation at Acme.",
                        CVData(experience: [job("", "Acme")]), .unchanged))
        rows.append(row("contact-details-keep-the-email",
                        "contact names the person's own details here, and reaches no one: the email stays",
                        "Contact details: me@example.com.",
                        CVData(personalInfo: person(email: "me@example.com")), .unchanged))
        return rows
    }

    // MARK: Languages that keep their subject (c)

    /// English, French and German do not drop the subject: a clause whose first verb comes after anything but a pure time phrase needs
    /// a first-person pronoun before that verb, or right after it in German. Otherwise the words before the verb are another subject,
    /// a name too ("In Rome Anna speaks French (C2)"), though a phrase of place hides where it starts. The languages that drop the
    /// pronoun tell the same by the form of the verb.
    private static func languagesThatKeepTheirSubject() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        typealias Spoken = (language: String, description: String, spoken: String)
        var annas: [Spoken] = []
        annas.append(("en", "In Rome Anna speaks French (C2).", "French"))
        annas.append(("it", "A Roma Anna parla francese (C2).", "francese"))
        annas.append(("de", "In Rom spricht Anna Französisch (C2).", "Französisch"))
        annas.append(("es", "En Roma Anna habla francés (C2).", "francés"))
        annas.append(("fr", "À Rome Anna parle français (C2).", "français"))
        annas.append(("pt", "Em Roma Anna fala francês (C2).", "francês"))
        for v in annas {
            rows.append(row("a-name-after-a-place-gives-no-language-\(v.language)",
                            "the words before the verb are no pure time phrase and hold no first-person pronoun: Anna is the subject, so no French and no C2",
                            v.description, CVData(languages: [Language(name: v.spoken, proficiency: .c2)]), .exactly(CVData()), language: v.language))
        }

        typealias Worked = (language: String, description: String, title: String)
        var nurses: [Worked] = []
        nurses.append(("en", "At Acme Anna worked as a nurse.", "nurse"))
        nurses.append(("it", "Presso Acme Anna ha lavorato come infermiera.", "infermiera"))
        nurses.append(("de", "In Berlin arbeitete Anna bei Acme.", ""))
        nurses.append(("es", "En Acme Anna trabajó como enfermera.", "enfermera"))
        nurses.append(("fr", "Chez Acme Anna a travaillé comme infirmière.", "infirmière"))
        nurses.append(("pt", "Na Acme Anna trabalhou como enfermeira.", "enfermeira"))
        for v in nurses {
            rows.append(row("a-name-after-a-place-gives-no-job-\(v.language)",
                            "Anna, after the phrase of place, is the subject: no Acme job and no title",
                            v.description, CVData(experience: [job(v.title, "Acme")]), .exactly(CVData()), language: v.language))
        }

        // Controls: a pure time phrase before a verb with no subject, the way a CV writes.
        var since: [(language: String, description: String)] = []
        since.append(("en", "Since 2016 worked at Acme."))
        since.append(("de", "Seit 2016 bei Acme gearbeitet."))
        since.append(("fr", "Depuis 2016 travaille chez Acme."))
        for v in since {
            rows.append(row("a-time-phrase-before-a-verb-with-no-subject-keeps-the-job-\(v.language)",
                            "a pure time phrase is no subject: the job and its year stay",
                            v.description, CVData(experience: [job("", "Acme", from: "2016")]), .unchanged, language: v.language))
        }
        return rows
    }

    // MARK: A contact is the person's only when its clause names no other person (b)

    /// A contact (email, phone, link) is the person's only when its clause names no other person: a possession of a person, a pronoun
    /// of a third person, or a name after a verb of contacting. The clause may speak for the person and still give another person's
    /// contact ("I can put you in touch with my manager at ...").
    private static func contactsOfAnotherPerson() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        typealias Shape = (language: String, description: String)
        func noEmail(_ id: String, _ reason: String, _ email: String, _ shapes: [Shape]) {
            for v in shapes {
                rows.append(row(v.language == "en" ? id : "\(id)-\(v.language)", reason, v.description,
                                CVData(personalInfo: person(email: email)), .exactly(CVData()), language: v.language))
            }
        }

        var managers: [Shape] = []
        managers.append(("en", "I can put you in touch with my manager at boss@example.com."))
        managers.append(("it", "Posso metterti in contatto con il mio responsabile a boss@example.com."))
        managers.append(("de", "Ich kann dich mit meinem Chef unter boss@example.com in Kontakt bringen."))
        managers.append(("es", "Puedo ponerte en contacto con mi jefe en boss@example.com."))
        managers.append(("fr", "Je peux vous mettre en contact avec mon responsable à boss@example.com."))
        managers.append(("pt", "Posso colocar você em contato com meu chefe em boss@example.com."))
        noEmail("a-contact-beside-my-manager-goes", "the clause is the person's, but it names my manager: the email is not the person's",
                "boss@example.com", managers)

        var throughManagers: [Shape] = []
        throughManagers.append(("en", "You can reach me through my manager at boss@example.com."))
        throughManagers.append(("it", "Puoi contattarmi tramite il mio responsabile a boss@example.com."))
        throughManagers.append(("de", "Du kannst mich über meinen Chef unter boss@example.com erreichen."))
        throughManagers.append(("es", "Puedes contactarme a través de mi jefe en boss@example.com."))
        throughManagers.append(("fr", "Vous pouvez me contacter par mon responsable à boss@example.com."))
        throughManagers.append(("pt", "Você pode me contatar através do meu chefe em boss@example.com."))
        noEmail("reader-me-through-my-manager", "the person is the object of the verb of contacting, but the clause names my manager: no email",
                "boss@example.com", throughManagers)

        var hims: [Shape] = []
        hims.append(("en", "I can put you in touch with him at boss@example.com."))
        hims.append(("it", "Posso metterti in contatto con lui a boss@example.com."))
        hims.append(("de", "Ich kann dich mit ihm unter boss@example.com in Kontakt bringen."))
        hims.append(("es", "Puedo ponerte en contacto con él en boss@example.com."))
        hims.append(("fr", "Je peux vous mettre en contact avec lui à boss@example.com."))
        hims.append(("pt", "Posso colocar você em contato com ele em boss@example.com."))
        noEmail("a-contact-beside-him-goes", "the clause names him, a third person: the email is not the person's", "boss@example.com", hims)

        var annas: [Shape] = []
        annas.append(("en", "For references, I suggest you contact Anna at anna@example.com."))
        annas.append(("it", "Per le referenze, vi suggerisco di contattare Anna a anna@example.com."))
        annas.append(("es", "Para referencias, te sugiero contactar a Anna en anna@example.com."))
        annas.append(("fr", "Pour des références, je vous suggère de contacter Anna à anna@example.com."))
        annas.append(("pt", "Para referências, sugiro que você contate a Anna em anna@example.com."))
        noEmail("a-contact-after-contacting-a-name-goes", "the verb of contacting reaches Anna, a name: the email is not the person's",
                "anna@example.com", annas)

        // Controls: the clause names nothing but the person and their own fields.
        var own: [Shape] = []
        own.append(("en", "You can write to me at my personal address me@example.com."))
        own.append(("it", "Puoi scrivermi al mio indirizzo personale me@example.com."))
        own.append(("de", "Du kannst mir an meine E-Mail-Adresse me@example.com schreiben."))
        own.append(("es", "Puedes escribirme a mi correo personal me@example.com."))
        own.append(("fr", "Vous pouvez m'écrire à mon adresse e-mail me@example.com."))
        own.append(("pt", "Você pode me escrever no meu e-mail pessoal me@example.com."))
        for v in own {
            rows.append(row("a-contact-beside-the-persons-own-fields-stays-\(v.language)",
                            "the clause names the person and their own address, and no one else: the email stays",
                            v.description, CVData(personalInfo: person(email: "me@example.com")), .unchanged, language: v.language))
        }
        return rows
    }

    // MARK: A contact is the person's only in three shapes (b)

    /// A contact (email, phone, link) is the person's only in three shapes, each with no other person named in the clause: a verbless
    /// clause ("Email: me@example.com"), the person's possession of the field ("My email is me@example.com") and a verb of contacting
    /// whose object is the person ("You can reach me at ..."). Any other clause gives no contact, even one the person speaks.
    private static func theShapesOfAContact() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        typealias Shape = (language: String, description: String)
        func add(_ id: String, _ reason: String, _ shapes: [Shape], _ draft: CVData, _ expected: Outcome) {
            for v in shapes {
                rows.append(row(v.language == "en" ? id : "\(id)-\(v.language)", reason, v.description, draft, expected, language: v.language))
            }
        }

        var recruiters: [Shape] = []
        recruiters.append(("en", "I can put you in touch with the recruiter at rec@example.com."))
        recruiters.append(("it", "Posso metterti in contatto con la selezionatrice a rec@example.com."))
        recruiters.append(("de", "Ich kann dich mit der Personalvermittlerin unter rec@example.com in Kontakt bringen."))
        recruiters.append(("es", "Puedo ponerte en contacto con la reclutadora en rec@example.com."))
        recruiters.append(("fr", "Je peux vous mettre en contact avec la recruteuse à rec@example.com."))
        recruiters.append(("pt", "Posso colocar você em contato com a recrutadora em rec@example.com."))
        add("a-contact-beside-the-recruiter-goes", "a clause of the person, but in none of the three shapes of a contact: no email", recruiters,
            CVData(personalInfo: person(email: "rec@example.com")), .exactly(CVData()))

        var teams: [Shape] = []
        teams.append(("en", "I worked with the team at team@acme.com."))
        teams.append(("it", "Ho lavorato con il team a team@acme.com."))
        teams.append(("de", "Ich habe mit dem Team unter team@acme.com gearbeitet."))
        teams.append(("es", "Trabajé con el equipo en team@acme.com."))
        teams.append(("fr", "J'ai travaillé avec l'équipe à team@acme.com."))
        teams.append(("pt", "Trabalhei com a equipe em team@acme.com."))
        add("a-contact-of-the-team-goes", "a clause of the person, but in none of the three shapes of a contact: no email", teams,
            CVData(personalInfo: person(email: "team@acme.com")), .exactly(CVData()))

        var offices: [Shape] = []
        offices.append(("en", "Our office is at office@acme.com."))
        offices.append(("it", "Il nostro ufficio è a office@acme.com."))
        offices.append(("de", "Unser Büro ist unter office@acme.com."))
        offices.append(("es", "Nuestra oficina está en office@acme.com."))
        offices.append(("fr", "Notre bureau est à office@acme.com."))
        offices.append(("pt", "Nosso escritório fica em office@acme.com."))
        add("a-contact-of-our-office-goes", "an office is no field of the person: no email", offices,
            CVData(personalInfo: person(email: "office@acme.com")), .exactly(CVData()))

        var noShape: [Shape] = []
        noShape.append(("en", "I am at me@example.com."))
        noShape.append(("it", "Sono a me@example.com."))
        noShape.append(("de", "Ich bin unter me@example.com."))
        noShape.append(("es", "Estoy en me@example.com."))
        noShape.append(("fr", "Je suis à me@example.com."))
        noShape.append(("pt", "Estou em me@example.com."))
        add("a-contact-in-no-shape-goes", "the person speaks, but in none of the three shapes of a contact: no email", noShape,
            CVData(personalInfo: person(email: "me@example.com")), .exactly(CVData()))

        rows.append(row("a-contact-of-a-named-owner-goes",
                        "Anna's email names Anna, another person, in a verbless clause: no email",
                        "Anna's email: anna@example.com.",
                        CVData(personalInfo: person(email: "anna@example.com")), .exactly(CVData())))
        rows.append(row("a-contact-through-a-named-owner-goes",
                        "the person is the object of reach, but the genitive names Anna, another person: no email",
                        "You can reach me through Anna's office at office@example.com.",
                        CVData(personalInfo: person(email: "office@example.com")), .exactly(CVData())))

        // Controls: each of the three shapes.
        var phones: [Shape] = []
        phones.append(("en", "Phone: +39 333 123 4567."))
        phones.append(("it", "Telefono: +39 333 123 4567."))
        phones.append(("de", "Telefon: +39 333 123 4567."))
        phones.append(("es", "Teléfono: +39 333 123 4567."))
        phones.append(("fr", "Téléphone : +39 333 123 4567."))
        phones.append(("pt", "Telefone: +39 333 123 4567."))
        add("a-verbless-phone-stays", "a verbless clause gives the person's contact: the phone stays", phones,
            CVData(personalInfo: person(phone: "+39 333 123 4567")), .unchanged)

        var sites: [Shape] = []
        sites.append(("en", "Website: https://example.com."))
        sites.append(("it", "Sito web: https://example.com."))
        sites.append(("de", "Webseite: https://example.com."))
        sites.append(("es", "Sitio web: https://example.com."))
        sites.append(("fr", "Site web : https://example.com."))
        sites.append(("pt", "Site: https://example.com."))
        add("a-verbless-link-stays", "a verbless clause gives the person's contact: the link stays", sites,
            CVData(personalInfo: person(website: "https://example.com")), .unchanged)

        var emails: [Shape] = []
        emails.append(("en", "My email is me@example.com."))
        emails.append(("it", "La mia email è me@example.com."))
        emails.append(("de", "Meine E-Mail-Adresse ist me@example.com."))
        emails.append(("es", "Mi correo es me@example.com."))
        emails.append(("fr", "Mon adresse e-mail est me@example.com."))
        emails.append(("pt", "Meu e-mail é me@example.com."))
        add("a-contact-of-my-own-field-stays", "the person's possession of the field gives the person's contact: the email stays", emails,
            CVData(personalInfo: person(email: "me@example.com")), .unchanged)

        var portfolios: [Shape] = []
        portfolios.append(("en", "My portfolio is https://example.com."))
        portfolios.append(("it", "Il mio portfolio è https://example.com."))
        portfolios.append(("de", "Mein Portfolio ist https://example.com."))
        portfolios.append(("es", "Mi portfolio es https://example.com."))
        portfolios.append(("fr", "Mon site web est https://example.com."))
        portfolios.append(("pt", "Meu portfolio é https://example.com."))
        add("a-link-of-my-own-field-stays", "the person's possession of the field gives the person's contact: the link stays", portfolios,
            CVData(personalInfo: person(website: "https://example.com")), .unchanged)
        return rows
    }

    // MARK: A label names no other person (b)

    /// In each shape that gives the person's contact, every word beyond the shape's own is a contact or field word, a number, a function
    /// or time word, or the person's own quote. A name or a noun such as "Reference" gives no contact: "Reference: Anna Verdi,
    /// anna@example.com" gives none, whatever name the draft gives the person, nor does "Puoi contattarmi tramite Anna a ...".
    private static func labelsThatNameSomeoneElse() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        typealias Reference = (language: String, word: String, person: String)
        var references: [Reference] = []
        references.append(("en", "Reference:", "I'm Maria Rossi."))
        references.append(("it", "Referente:", "Sono Maria Rossi."))
        references.append(("de", "Referenz:", "Ich bin Maria Rossi."))
        references.append(("es", "Referencia:", "Soy Maria Rossi."))
        references.append(("fr", "Référence :", "Je suis Maria Rossi."))
        references.append(("pt", "Referência:", "Sou Maria Rossi."))

        let email = "anna@example.com", phone = "+39 333 123 4567", link = "linkedin.com/in/anna-verdi"
        for v in references {
            let label = "\(v.word) Anna Verdi"
            rows.append(row("a-reference-label-gives-no-email-\(v.language)",
                            "the label holds a reference and a name, which are no words of a contact: no email",
                            "\(label), \(email).", CVData(personalInfo: person(email: email)), .exactly(CVData()), language: v.language))
            rows.append(row("a-reference-label-gives-no-phone-\(v.language)",
                            "the label holds a reference and a name, which are no words of a contact: no phone",
                            "\(label), \(phone).", CVData(personalInfo: person(phone: phone)), .exactly(CVData()), language: v.language))
            rows.append(row("a-reference-label-gives-no-link-\(v.language)",
                            "the label holds a reference and a name, which are no words of a contact: no link",
                            "\(label), \(link).", CVData(personalInfo: person(linkedin: link)), .exactly(CVData()), language: v.language))
            rows.append(row("a-reference-label-beside-the-person-gives-no-email-\(v.language)",
                            "the person is Maria Rossi, and the label names her reference: her name stays, the reference's email goes",
                            "\(v.person) \(label), \(email).", CVData(personalInfo: person(name: "Maria Rossi", email: email)),
                            .exactly(CVData(personalInfo: person(name: "Maria Rossi"))), language: v.language))
            rows.append(row("a-reference-label-with-the-references-name-gives-no-email-\(v.language)",
                            "the draft takes the reference's name for the person's, and the label still holds a reference: no email",
                            "\(label), \(email).", CVData(personalInfo: person(name: "Anna Verdi", email: email)),
                            .safe(never: [email], absent: ["personalInfo.email"]), language: v.language))
        }

        // Controls: a label of the person's own name, and one of contact words.
        rows.append(row("a-label-with-the-persons-name-keeps-the-email",
                        "the label holds the person's own name and an address: the name and the email stay",
                        "Maria Rossi, me@example.com.", CVData(personalInfo: person(name: "Maria Rossi", email: "me@example.com")), .unchanged))
        typealias Shape = (language: String, description: String)
        var contacts: [Shape] = []
        contacts.append(("en", "Contacts: me@example.com, +39 333 123 4567."))
        contacts.append(("it", "Contatti: me@example.com, +39 333 123 4567."))
        contacts.append(("de", "Kontakt: me@example.com, +39 333 123 4567."))
        contacts.append(("es", "Contactos: me@example.com, +39 333 123 4567."))
        contacts.append(("fr", "Contacts : me@example.com, +39 333 123 4567."))
        contacts.append(("pt", "Contatos: me@example.com, +39 333 123 4567."))
        for v in contacts {
            rows.append(row("a-label-of-contacts-keeps-the-email-and-the-phone-\(v.language)",
                            "a label of contact words: the email and the phone stay, the phone in the clause the comma splits off",
                            v.description, CVData(personalInfo: person(email: "me@example.com", phone: "+39 333 123 4567")), .unchanged,
                            language: v.language))
        }

        // The person is the object of the verb of contacting, but the clause names Anna, an intermediary.
        typealias Through = (language: String, lead: String, at: String, end: String)
        var throughAnna: [Through] = []
        throughAnna.append(("en", "You can reach me through Anna", "at", ""))
        throughAnna.append(("it", "Puoi contattarmi tramite Anna", "a", ""))
        throughAnna.append(("de", "Du kannst mich über Anna", "unter", " erreichen"))
        throughAnna.append(("es", "Puedes contactarme a través de Anna", "en", ""))
        throughAnna.append(("fr", "Vous pouvez me contacter par Anna", "à", ""))
        throughAnna.append(("pt", "Você pode me contatar através de Anna", "em", ""))
        for v in throughAnna {
            let before = "\(v.lead) \(v.at)"
            rows.append(row("reader-me-through-anna-\(v.language)", "the person is the object, but the clause names Anna: no email",
                            "\(before) \(email)\(v.end).", CVData(personalInfo: person(email: email)), .exactly(CVData()), language: v.language))
            rows.append(row("reader-me-through-anna-gives-no-phone-\(v.language)", "the person is the object, but the clause names Anna: no phone",
                            "\(before) \(phone)\(v.end).", CVData(personalInfo: person(phone: phone)), .exactly(CVData()), language: v.language))
            rows.append(row("reader-me-through-anna-gives-no-link-\(v.language)", "the person is the object, but the clause names Anna: no link",
                            "\(before) \(link)\(v.end).", CVData(personalInfo: person(linkedin: link)), .exactly(CVData()), language: v.language))
        }

        // Control: the person's own place is one of the person's quotes, and may stand beside the contact.
        typealias Placed = (language: String, description: String, city: String)
        var cities: [Placed] = []
        cities.append(("en", "You can reach me in Turin at me@example.com.", "Turin"))
        cities.append(("it", "Puoi contattarmi a Torino a me@example.com.", "Torino"))
        cities.append(("de", "Du kannst mich in Turin unter me@example.com erreichen.", "Turin"))
        cities.append(("es", "Puedes contactarme en Turín en me@example.com.", "Turín"))
        cities.append(("fr", "Vous pouvez me contacter à Turin à me@example.com.", "Turin"))
        cities.append(("pt", "Você pode me contatar em Turim em me@example.com.", "Turim"))
        for v in cities {
            rows.append(row("reader-me-in-my-own-city-keeps-the-email-\(v.language)",
                            "the city is the person's own quote: the email and the place stay",
                            v.description, CVData(personalInfo: person(email: "me@example.com", location: v.city)), .unchanged, language: v.language))
        }
        return rows
    }

    // MARK: References, and the person as reachable (b)

    /// From the first sentence that holds a reference word to the end of the description, no contact is the person's; a verbless
    /// contact (a label, an address on its own) is the person's only when the sentence before it names no other person. The third
    /// shape takes the person as the subject of being reachable ("I can be reached at ...", "Sono raggiungibile a ...").
    private static func referencesAndTheReachablePerson() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        typealias Language = (code: String, reference: String, references: String, label: String, manager: String, person: String,
                              title: String, available: String, nurse: String)
        var languages: [Language] = []
        languages.append(("en", "Reference:", "References.", "Email:", "manager at Acme", "I'm Maria Rossi.", "Software engineer",
                          "References available on request.", "Anna is a nurse."))
        languages.append(("it", "Referente:", "Referenze.", "Email:", "responsabile presso Acme", "Sono Maria Rossi.", "Ingegnere del software",
                          "Referenze disponibili su richiesta.", "Anna è infermiera."))
        languages.append(("de", "Referenz:", "Referenzen.", "E-Mail:", "Leiterin bei Acme", "Ich bin Maria Rossi.", "Softwareentwicklerin",
                          "Referenzen auf Anfrage.", "Anna ist Krankenschwester."))
        languages.append(("es", "Referencia:", "Referencias.", "Correo:", "gerente en Acme", "Soy Maria Rossi.", "Ingeniera de software",
                          "Referencias disponibles a petición.", "Anna es enfermera."))
        languages.append(("fr", "Référence :", "Références.", "Courriel :", "responsable chez Acme", "Je suis Maria Rossi.", "Ingénieure logiciel",
                          "Références sur demande.", "Anna est infirmière."))
        languages.append(("pt", "Referência:", "Referências.", "E-mail:", "gerente na Acme", "Sou Maria Rossi.", "Engenheira de software",
                          "Referências disponíveis mediante solicitação.", "Anna é enfermeira."))

        let anna = "anna@example.com", luca = "luca@acme.com", mine = "me@example.com"
        for v in languages {
            typealias Shape = (id: String, text: String, email: String)
            var shapes: [Shape] = []
            shapes.append(("a-reference-sentence-before-an-address", "\(v.reference) Anna Verdi. \(anna)", anna))
            shapes.append(("a-reference-sentence-before-a-label", "\(v.reference) Anna Verdi. \(v.label) \(anna).", anna))
            shapes.append(("a-references-section", "\(v.references) Anna Verdi, \(v.manager). Luca Bianchi. \(luca)", luca))
            for shape in shapes {
                rows.append(row("\(shape.id)-gives-no-email-\(v.code)",
                                "the address stands in the references, from their first sentence on: it is not the person's",
                                shape.text, CVData(personalInfo: person(email: shape.email)), .exactly(CVData()), language: v.code))
                rows.append(row("\(shape.id)-beside-the-person-gives-no-email-\(v.code)",
                                "the person is Maria Rossi, and the address stands in the references: her name stays, the email goes",
                                "\(v.person) \(shape.text)", CVData(personalInfo: person(name: "Maria Rossi", email: shape.email)),
                                .exactly(CVData(personalInfo: person(name: "Maria Rossi"))), language: v.code))
            }
            rows.append(row("a-label-after-a-sentence-about-anna-gives-no-email-\(v.code)",
                            "the sentence before the label speaks for Anna, another person: the label's email is not the person's",
                            "\(v.nurse) \(v.label) \(anna).", CVData(personalInfo: person(email: anna)), .exactly(CVData()), language: v.code))

            // Controls.
            rows.append(row("a-header-of-the-person-keeps-the-email-\(v.code)",
                            "a header of the person's name, title and address: the address alone in its sentence stays",
                            "Maria Rossi. \(v.title). \(mine)", CVData(personalInfo: person(name: "Maria Rossi", email: mine, title: v.title)),
                            .unchanged, language: v.code))
            rows.append(row("an-address-before-the-references-stays-\(v.code)",
                            "the address comes before the first reference word: it stays",
                            "\(v.label) \(mine). \(v.available)", CVData(personalInfo: person(email: mine)), .unchanged, language: v.code))
            rows.append(row("a-label-after-the-persons-sentence-keeps-the-email-\(v.code)",
                            "the sentence before the label is the person's: the email stays",
                            "\(v.person) \(v.label) \(mine).", CVData(personalInfo: person(name: "Maria Rossi", email: mine)), .unchanged,
                            language: v.code))
        }
        rows.append(row("a-label-after-a-sentence-about-my-sister-gives-no-email",
                        "the sentence before the label speaks for my sister: the label's email goes, a loss and not a leak (ADR 0023, (f))",
                        "My sister is a nurse. Email: me@example.com.", CVData(personalInfo: person(email: mine)), .exactly(CVData())))

        // The person as the subject of being reachable.
        typealias Reachable = (language: String, description: String, email: String?, phone: String?)
        var reachable: [Reachable] = []
        reachable.append(("en", "I can be reached at me@example.com.", mine, nil))
        reachable.append(("en", "I can be contacted at me@example.com.", mine, nil))
        reachable.append(("en", "I can be reached on +39 333 123 4567.", nil, "+39 333 123 4567"))
        reachable.append(("it", "Sono raggiungibile a me@example.com.", mine, nil))
        reachable.append(("it", "Sono reperibile al +39 333 123 4567.", nil, "+39 333 123 4567"))
        reachable.append(("de", "Ich bin unter me@example.com erreichbar.", mine, nil))
        reachable.append(("es", "Estoy localizable en me@example.com.", mine, nil))
        reachable.append(("fr", "Je suis joignable à me@example.com.", mine, nil))
        reachable.append(("fr", "Je suis joignable au +39 333 123 4567.", nil, "+39 333 123 4567"))
        reachable.append(("pt", "Estou contactável em me@example.com.", mine, nil))
        for (number, v) in reachable.enumerated() {
            rows.append(row("the-person-as-reachable-keeps-the-contact-\(v.language)-\(number + 1)",
                            "the person is the subject of being reachable: the contact stays",
                            v.description, CVData(personalInfo: person(email: v.email, phone: v.phone)), .unchanged, language: v.language))
        }

        var othersReachable: [(language: String, description: String, email: String)] = []
        othersReachable.append(("en", "My manager can be reached at boss@example.com.", "boss@example.com"))
        othersReachable.append(("en", "Anna can be reached at anna@example.com.", anna))
        othersReachable.append(("it", "Anna è raggiungibile a anna@example.com.", anna))
        othersReachable.append(("it", "Il mio responsabile è raggiungibile a boss@example.com.", "boss@example.com"))
        othersReachable.append(("de", "Mein Chef ist unter boss@example.com erreichbar.", "boss@example.com"))
        othersReachable.append(("es", "Mi jefe está localizable en boss@example.com.", "boss@example.com"))
        othersReachable.append(("fr", "Mon responsable est joignable à boss@example.com.", "boss@example.com"))
        othersReachable.append(("pt", "Meu chefe está contactável em boss@example.com.", "boss@example.com"))
        for (number, v) in othersReachable.enumerated() {
            rows.append(row("someone-else-as-reachable-gives-no-contact-\(v.language)-\(number + 1)",
                            "the subject of being reachable is another person: no email",
                            v.description, CVData(personalInfo: person(email: v.email)), .exactly(CVData()), language: v.language))
        }
        return rows
    }

    // MARK: A hobby is no skill (#202)

    /// The model lists the hobbies of the app's example (chess, hiking) as skills too: a skill claims an ability that the person
    /// never claimed, so a skill whose name is an interest of the same draft, whatever its case or accents, goes when the description
    /// mentions it only as leisure ("In my free time I like chess and hiking"). The interest stays, and so does a skill that only holds
    /// an interest's name.
    private static func hobbiesAreNoSkills() -> [GroundingRow] {
        typealias Variant = (language: String, interests: [String], skills: [String])
        var variants: [Variant] = []
        variants.append(("en", ["chess", "hiking"], ["Chess", "hiking"]))
        variants.append(("it", ["scacchi", "escursioni"], ["scacchi", "Escursioni"]))
        variants.append(("de", ["Schach", "Wandern"], ["schach", "Wandern"]))
        variants.append(("es", ["ajedrez", "senderismo"], ["Ajedrez", "senderismo"]))
        variants.append(("fr", ["échecs", "randonnée"], ["Echecs", "randonnee"]))
        variants.append(("pt", ["xadrez", "caminhadas"], ["xadrez", "Caminhadas"]))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("a-hobby-is-no-skill-\(v.language)",
                            "the skills are the interests of the same draft, in another case or without accents: they go, the interests stay",
                            AppExample.text(in: v.language),
                            CVData(skills: v.skills.map { Skill(name: $0, level: .beginner) }, interests: v.interests),
                            .exactly(CVData(interests: v.interests)), language: v.language))
        }
        rows.append(row("a-skill-that-holds-a-hobby-stays",
                        "chess coaching is a skill the person claims, though it holds the interest chess: it stays",
                        "My skills include chess coaching and first aid. In my free time I like chess.",
                        CVData(skills: [Skill(name: "chess coaching"), Skill(name: "first aid")], interests: ["chess"]), .unchanged))
        return rows
    }

    /// A skill that is also an interest of the draft stays when the description mentions it anywhere but in a clause of leisure: as an
    /// ability ("proficient in Python"), in a job's clause ("where I do portrait photography") or in a list of skills. An interest that
    /// the description never states as one removes no skill.
    private static func skillsTheDescriptionClaims() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        rows.append(row("a-skill-the-person-claims-stays-though-it-is-an-interest",
                        "Python is an ability the person claims (proficient, its level) before it is a pastime: the skill and its level stay",
                        "I am proficient in Python and enjoy Python programming.",
                        CVData(skills: [Skill(name: "Python", level: .advanced)], interests: ["Python"]), .unchanged))
        rows.append(row("a-skill-of-the-job-stays-though-it-is-a-hobby-en",
                        "photography is the person's work at Studio Luce as well as a hobby: the skill stays",
                        "I work as a photographer at Studio Luce, where I do portrait photography. In my free time I like photography and hiking.",
                        CVData(experience: [job("photographer", "Studio Luce")], skills: [Skill(name: "photography")],
                               interests: ["photography", "hiking"]), .unchanged))
        rows.append(row("a-skill-of-the-job-stays-though-it-is-a-hobby-it",
                        "fotografia is the person's work at Studio Luce as well as a hobby: the skill stays",
                        "Sono fotografa presso lo Studio Luce, dove faccio fotografia di ritratto. Nel tempo libero mi piacciono la fotografia e le escursioni.",
                        CVData(skills: [Skill(name: "fotografia")], interests: ["fotografia", "escursioni"]), .unchanged, language: "it"))
        rows.append(row("a-skill-of-the-job-stays-though-it-is-a-hobby-fr",
                        "photographie is the person's work at Studio Luce as well as a hobby: the skill stays",
                        "Je suis photographe au Studio Luce, où je fais de la photographie de portrait. Pendant mon temps libre, j'aime la photographie et la randonnée.",
                        CVData(skills: [Skill(name: "photographie")], interests: ["photographie", "randonnée"]), .unchanged, language: "fr"))
        rows.append(row("a-skill-in-a-list-of-skills-stays-though-it-is-a-hobby",
                        "chess stands in the list of skills as well as among the pastimes: the skill stays",
                        "My skills include chess and first aid. In my free time I like chess and hiking.",
                        CVData(skills: [Skill(name: "chess"), Skill(name: "first aid")], interests: ["chess", "hiking"]), .unchanged))
        rows.append(row("an-interest-the-description-does-not-state-removes-no-skill",
                        "the model makes ECG monitoring an interest too, though the description states no interest: the skill stays",
                        "I am good at ECG monitoring.",
                        CVData(skills: [Skill(name: "ECG monitoring")], interests: ["ECG monitoring"]), .unchanged))
        return rows
    }

    // MARK: A clause that denies, wishes or supposes claims no skill, interest or language (c)

    /// A skill, an interest or a language counts only in a clause of the person that claims it (#202): one that denies ("I have never
    /// used Python"), wishes ("I would like to learn Spanish") or supposes ("If I had time, I would play chess") claims nothing, and
    /// nor does a clause that follows a condition in its sentence. Ability and part still claim: "I can speak French", "I partly use
    /// Swift", "I mostly use Swift". The same item in a plain clause of the person stays.
    private static func factsTheDescriptionWithdraws() -> [GroundingRow] {
        typealias Variant = (
            language: String, denied: String, wished: String, supposed: String, skill: String, spoken: String, interest: String,
            affirmed: String
        )
        var variants: [Variant] = []
        variants.append(("en", "I have never used Python.", "I would like to learn Spanish.", "If I had time, I would play chess.",
                         "Python", "Spanish", "chess",
                         "I use Python. I have never used Python for games. I speak Spanish. I would like to speak Spanish better. "
                            + "I play chess. If I had time, I would play chess more."))
        variants.append(("it", "Non ho mai usato Python.", "Vorrei imparare lo spagnolo.", "Se avessi tempo, giocherei a scacchi.",
                         "Python", "spagnolo", "scacchi",
                         "Uso Python. Non ho mai usato Python per i videogiochi. Parlo spagnolo. Vorrei parlare meglio lo spagnolo. "
                            + "Gioco a scacchi. Se avessi tempo, giocherei di più a scacchi."))
        variants.append(("de", "Ich habe nie Python benutzt.", "Ich möchte Spanisch lernen.", "Wenn ich Zeit hätte, würde ich Schach spielen.",
                         "Python", "Spanisch", "Schach",
                         "Ich benutze Python. Ich habe nie Python für Spiele benutzt. Ich spreche Spanisch. Ich möchte besser Spanisch "
                            + "sprechen. Ich spiele Schach. Wenn ich Zeit hätte, würde ich mehr Schach spielen."))
        variants.append(("es", "Nunca he usado Python.", "Quiero aprender español.", "Si tuviera tiempo, jugaría al ajedrez.",
                         "Python", "español", "ajedrez",
                         "Uso Python. Nunca he usado Python para juegos. Hablo español. Quiero hablar mejor español. Juego al ajedrez. "
                            + "Si tuviera tiempo, jugaría más al ajedrez."))
        variants.append(("fr", "Je n'ai jamais utilisé Python.", "Je souhaite apprendre l'espagnol.",
                         "Si j'avais le temps, je jouerais aux échecs.", "Python", "espagnol", "échecs",
                         "J'utilise Python. Je n'ai jamais utilisé Python pour des jeux. Je parle espagnol. Je souhaite mieux parler "
                            + "espagnol. Je joue aux échecs. Si j'avais le temps, je jouerais plus aux échecs."))
        variants.append(("pt", "Nunca usei Python.", "Quero aprender espanhol.", "Se eu tivesse tempo, jogaria xadrez.",
                         "Python", "espanhol", "xadrez",
                         "Uso Python. Nunca usei Python para jogos. Falo espanhol. Quero falar melhor espanhol. Jogo xadrez. "
                            + "Se eu tivesse tempo, jogaria mais xadrez."))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("a-denied-skill-is-not-the-persons-\(v.language)", "the only clause that names the skill denies it: no skill",
                            v.denied, CVData(skills: [Skill(name: v.skill)]), .exactly(CVData()), language: v.language))
            rows.append(row("a-wished-language-is-not-the-persons-\(v.language)", "the only clause that names the language wishes it: no language",
                            v.wished, CVData(languages: [Language(name: v.spoken)]), .exactly(CVData()), language: v.language))
            rows.append(row("a-supposed-interest-is-not-the-persons-\(v.language)",
                            "the only clause that names the interest follows a condition: no interest",
                            v.supposed, CVData(interests: [v.interest]), .exactly(CVData()), language: v.language))
            rows.append(row("an-affirmed-skill-language-and-interest-stay-\(v.language)",
                            "each item also stands in a plain clause of the person, beside one that denies, wishes or supposes it: all stay",
                            v.affirmed,
                            CVData(skills: [Skill(name: v.skill)], languages: [Language(name: v.spoken)], interests: [v.interest]),
                            .unchanged, language: v.language))
        }

        rows.append(row("a-wished-language-is-not-the-persons-in-the-conditional-fr",
                        "j'aimerais only wishes the language: no language",
                        "J'aimerais apprendre l'espagnol.", CVData(languages: [Language(name: "espagnol")]), .exactly(CVData()),
                        language: "fr"))

        typealias Ability = (language: String, description: String, name: String)
        var abilities: [Ability] = []
        abilities.append(("en", "I can speak French.", "French"))
        abilities.append(("it", "Posso parlare francese.", "francese"))
        abilities.append(("de", "Ich kann Französisch sprechen.", "Französisch"))
        abilities.append(("es", "Puedo hablar francés.", "francés"))
        abilities.append(("fr", "Je peux parler espagnol.", "espagnol"))
        abilities.append(("pt", "Posso falar francês.", "francês"))
        for v in abilities {
            rows.append(row("an-ability-is-a-claim-\(v.language)", "can is an ability the person claims: the language stays",
                            v.description, CVData(languages: [Language(name: v.name)]), .unchanged, language: v.language))
        }

        typealias Part = (language: String, description: String)
        var parts: [Part] = []
        parts.append(("en", "I partly use Swift."))
        parts.append(("it", "Uso parzialmente Swift."))
        parts.append(("de", "Ich nutze teilweise Swift."))
        parts.append(("es", "Uso parcialmente Swift."))
        parts.append(("fr", "J'utilise partiellement Swift."))
        parts.append(("pt", "Uso parcialmente Swift."))
        for v in parts {
            rows.append(row("a-part-is-a-claim-\(v.language)", "partly qualifies the claim but does not withdraw it: the skill stays",
                            v.description, CVData(skills: [Skill(name: "Swift")]), .unchanged, language: v.language))
        }
        rows.append(row("most-is-a-claim", "mostly qualifies the claim but does not withdraw it: the skill stays",
                        "I mostly use Swift.", CVData(skills: [Skill(name: "Swift")]), .unchanged))
        return rows
    }

    /// Wishes said with a phrase, not one word (#202): English "'d like", "'d love", "'d prefer", "'d rather"; German "würde gern",
    /// "würde gerne", "würde lieber"; the verbs of dream with their complement ("sogno di", "sueño con", "rêve de", "sonho em",
    /// "träume davon"). The words alone keep their meaning: "I'd used Swift" and "Ich wurde in Python geschult" claim.
    private static func wishesInAPhrase() -> [GroundingRow] {
        typealias Wish = (id: String, language: String, description: String, name: String)
        var wishes: [Wish] = []
        wishes.append(("d-like-en", "en", "I'd like to learn Spanish.", "Spanish"))
        wishes.append(("d-love-en", "en", "I'd love to speak Spanish.", "Spanish"))
        wishes.append(("d-prefer-en", "en", "I'd prefer to speak French.", "French"))
        wishes.append(("d-rather-en", "en", "I'd rather learn German.", "German"))
        wishes.append(("wurde-gern-de", "de", "Ich würde gern Spanisch lernen.", "Spanisch"))
        wishes.append(("wurde-gerne-de", "de", "Ich würde gerne Italienisch lernen.", "Italienisch"))
        wishes.append(("wurde-lieber-de", "de", "Ich würde lieber Französisch sprechen.", "Französisch"))
        wishes.append(("traume-davon-de", "de", "Ich träume davon, Spanisch zu lernen.", "Spanisch"))
        wishes.append(("sogno-di-it", "it", "Sogno di imparare lo spagnolo.", "spagnolo"))
        wishes.append(("sueno-con-es", "es", "Sueño con hablar francés.", "francés"))
        wishes.append(("reve-d-fr", "fr", "Je rêve d'apprendre l'espagnol.", "espagnol"))
        wishes.append(("reve-de-fr", "fr", "Je rêve de parler italien.", "italien"))
        wishes.append(("sonho-em-pt", "pt", "Sonho em falar francês.", "francês"))
        wishes.append(("sonho-com-pt", "pt", "Sonho com aprender italiano.", "italiano"))

        var rows: [GroundingRow] = []
        for v in wishes {
            rows.append(row("a-wish-in-a-phrase-claims-no-language-\(v.id)", "the phrase only wishes the language: no language",
                            v.description, CVData(languages: [Language(name: v.name)]), .exactly(CVData()), language: v.language))
        }
        typealias Fronted = (word: String, description: String, name: String, person: String, title: String, place: String)
        var fronted: [Fronted] = []
        fronted.append(("gerne", "Gerne würde ich Spanisch lernen.", "Spanisch",
                        "Ich bin Maria Rossi. Gerne würde ich als Lehrerin in Berlin arbeiten.", "Lehrerin", "Berlin"))
        fronted.append(("gern", "Gern würde ich Italienisch lernen.", "Italienisch",
                        "Ich bin Maria Rossi. Gern würde ich als Krankenschwester in Turin arbeiten.", "Krankenschwester", "Turin"))
        fronted.append(("lieber", "Lieber würde ich Französisch sprechen.", "Französisch",
                        "Ich bin Maria Rossi. Lieber würde ich als Lehrer in Berlin arbeiten.", "Lehrer", "Berlin"))
        for v in fronted {
            rows.append(row("a-fronted-wish-claims-no-language-\(v.word)-de", "\(v.word) comes before würde, and it still only wishes: no language",
                            v.description, CVData(languages: [Language(name: v.name)]), .exactly(CVData()), language: "de"))
            rows.append(row("a-fronted-wish-gives-no-title-or-place-\(v.word)-de",
                            "\(v.word) comes before würde, and it still only wishes: the name stays, the title and the place go",
                            v.person, CVData(personalInfo: person(name: "Maria Rossi", location: v.place, title: v.title)),
                            .exactly(CVData(personalInfo: person(name: "Maria Rossi"))), language: "de"))
        }
        rows.append(row("a-fronted-dream-claims-no-language-de", "von comes before träume, and it still only dreams: no language",
                        "Von fließendem Spanisch träume ich.", CVData(languages: [Language(name: "Spanisch")]), .exactly(CVData()),
                        language: "de"))
        rows.append(row("a-fronted-gerne-before-a-past-is-an-accepted-loss-de",
                        "gerne before wurde reads as a wish, though here it is a past: the skill goes, an accepted loss",
                        "Gerne wurde ich in Python geschult.", CVData(skills: [Skill(name: "Python")]), .exactly(CVData()), language: "de"))
        rows.append(row("a-past-participle-after-d-is-a-claim", "I'd used is I had used: the skill stays",
                        "I'd used Swift for years.", CVData(skills: [Skill(name: "Swift")]), .unchanged))
        rows.append(row("wurde-without-gern-is-a-claim", "ich wurde geschult is a fact: the skill stays",
                        "Ich wurde in Python geschult.", CVData(skills: [Skill(name: "Python")]), .unchanged, language: "de"))
        return rows
    }

    /// Text typed without accents (#202, #249): the moods of supposition lose the mark that tells them from a fact. Spanish "seria"
    /// still withdraws through the Portuguese "seria" (would be), which also takes Spanish "seria" (serious): an accepted loss.
    /// "wurde" for "würde" reads as a past and keeps its item: an open residual risk that #249 must close (`notImplementedYet`).
    private static func textWithoutAccents() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        rows.append(row("a-conditional-typed-without-its-accent-claims-nothing-es",
                        "seria for sería still supposes: no language",
                        "Yo seria feliz aprendiendo aleman.", CVData(languages: [Language(name: "alemán")]), .exactly(CVData()), language: "es"))
        rows.append(row("a-konjunktiv-typed-without-its-umlaut-claims-nothing-de",
                        "wurde for würde still wishes: no language",
                        "Am liebsten wurde ich Spanisch lernen.", CVData(languages: [Language(name: "Spanisch")]), .exactly(CVData()),
                        language: "de"))
        rows.append(row("serious-in-spanish-is-an-accepted-loss",
                        "seria (serious) reads as the Portuguese would be: the clause and the one that shares it claim nothing, an accepted loss",
                        "Soy una persona seria y hablo alemán.", CVData(languages: [Language(name: "alemán")]), .exactly(CVData()),
                        language: "es"))
        return rows
    }

    /// A denied level keeps its item only when the level is high (#202): denying "expert" or "fluent" implies some knowledge, while
    /// denying a basic level, or knowledge itself, denies the item. "I'm not a beginner" denies a low level too, and loses its item:
    /// an accepted loss.
    private static func deniedLowLevels() -> [GroundingRow] {
        typealias Denial = (id: String, language: String, description: String, name: String)
        var denials: [Denial] = []
        denials.append(("no-basic-knowledge-en", "en", "I have no basic knowledge of German.", "German"))
        denials.append(("no-basic-en", "en", "I have no basic German.", "German"))
        denials.append(("no-knowledge-en", "en", "I have no knowledge of German.", "German"))
        denials.append(("not-even-basic-en", "en", "I have not even basic knowledge of German.", "German"))
        denials.append(("keine-grundkenntnisse-de", "de", "Ich habe keine Grundkenntnisse in Deutsch.", "Deutsch"))
        denials.append(("nicht-einmal-grundkenntnisse-de", "de", "Ich habe nicht einmal Grundkenntnisse in Deutsch.", "Deutsch"))
        denials.append(("keine-kenntnisse-de", "de", "Ich habe keine Kenntnisse in Deutsch.", "Deutsch"))
        denials.append(("nessuna-base-it", "it", "Non ho nessuna base di tedesco.", "tedesco"))
        denials.append(("nessuna-conoscenza-di-base-it", "it", "Non ho nessuna conoscenza di base del tedesco.", "tedesco"))
        denials.append(("ningun-conocimiento-basico-es", "es", "No tengo ningún conocimiento básico de alemán.", "alemán"))
        denials.append(("no-es-basico-es", "es", "Mi alemán no es básico.", "alemán"))
        denials.append(("aucune-notion-de-base-fr", "fr", "Je n'ai aucune notion de base en allemand.", "allemand"))
        denials.append(("pas-de-notions-fr", "fr", "Je n'ai pas de notions d'allemand.", "allemand"))
        denials.append(("nenhum-conhecimento-basico-pt", "pt", "Não tenho nenhum conhecimento básico de alemão.", "alemão"))
        denials.append(("nao-e-basico-pt", "pt", "O meu alemão não é básico.", "alemão"))

        var rows: [GroundingRow] = []
        for v in denials {
            rows.append(row("a-denied-low-level-gives-no-language-\(v.id)", "the negation denies a basic level or knowledge itself: no language",
                            v.description, CVData(languages: [Language(name: v.name)]), .exactly(CVData()), language: v.language))
        }
        rows.append(row("a-denied-beginner-level-is-an-accepted-loss",
                        "not a beginner denies a low level, which reads as no knowledge: the skill goes, an accepted loss",
                        "I'm not a beginner in Python.", CVData(skills: [Skill(name: "Python")]), .exactly(CVData())))
        return rows
    }

    /// A mood that only supposes or wishes is never a fact (#202): German Konjunktiv II ("würde", "hätte", "wäre", "müsste",
    /// "dürfte"), read with its umlaut, so the past "wurde", "hatte", "musste" and "durfte" stay facts; English "'d" before a verb's
    /// base form; the conditional of "to be", "to have", "to do" and of the verbs of liking in the other languages.
    private static func moodsOfSupposition() -> [GroundingRow] {
        typealias Supposed = (id: String, language: String, description: String, draft: CVData)
        var supposed: [Supposed] = []
        let maria = { (title: String, place: String) in CVData(personalInfo: person(name: "Maria Rossi", location: place, title: title)) }
        supposed.append(("am-liebsten-wurde-language-de", "de", "Am liebsten würde ich Spanisch lernen.",
                         CVData(languages: [Language(name: "Spanisch")])))
        supposed.append(("am-liebsten-wurde-title-and-place-de", "de", "Ich bin Maria Rossi. Am liebsten würde ich als Lehrer in Berlin arbeiten.",
                         maria("Lehrer", "Berlin")))
        supposed.append(("wurde-alone-de", "de", "Ich bin Maria Rossi. Ich würde als Lehrerin in Berlin arbeiten.", maria("Lehrerin", "Berlin")))
        supposed.append(("am-liebsten-hatte-de", "de", "Ich bin Maria Rossi. Am liebsten hätte ich eine Stelle als Lehrerin in Berlin.",
                         maria("Lehrerin", "Berlin")))
        supposed.append(("hatte-gern-de", "de", "Ich hätte gern Spanisch gelernt.", CVData(languages: [Language(name: "Spanisch")])))
        supposed.append(("ware-gern-de", "de", "Ich bin Maria Rossi. Ich wäre gern Lehrerin in Berlin.", maria("Lehrerin", "Berlin")))
        supposed.append(("d-work-en", "en", "I'm Maria Rossi. I'd work as a teacher in Berlin.", maria("teacher", "Berlin")))
        supposed.append(("d-be-en", "en", "I'd be happy to learn Spanish.", CVData(languages: [Language(name: "Spanish")])))
        supposed.append(("sarei-it", "it", "Sono Maria Rossi. Sarei felice di lavorare come infermiera a Torino.", maria("infermiera", "Torino")))
        supposed.append(("farei-it", "it", "Sono Maria Rossi. Farei l'infermiera a Torino.", maria("infermiera", "Torino")))
        supposed.append(("avrei-it", "it", "Avrei voluto imparare lo spagnolo.", CVData(languages: [Language(name: "spagnolo")])))
        supposed.append(("seria-es", "es", "Soy Maria Rossi. Sería feliz trabajando como enfermera en Turín.", maria("enfermera", "Turín")))
        supposed.append(("encantaria-es", "es", "Me encantaría aprender alemán.", CVData(languages: [Language(name: "alemán")])))
        supposed.append(("serais-fr", "fr", "Je suis Maria Rossi. Je serais heureuse de travailler comme infirmière à Turin.",
                         maria("infirmière", "Turin")))
        supposed.append(("adorerais-fr", "fr", "J'adorerais apprendre l'espagnol.", CVData(languages: [Language(name: "espagnol")])))
        supposed.append(("seria-pt", "pt", "Sou Maria Rossi. Seria feliz trabalhando como enfermeira em Turim.", maria("enfermeira", "Turim")))
        supposed.append(("adoraria-pt", "pt", "Adoraria aprender alemão.", CVData(languages: [Language(name: "alemão")])))
        supposed.append(("quereria-pt", "pt", "Quereria aprender espanhol.", CVData(languages: [Language(name: "espanhol")])))

        var rows: [GroundingRow] = []
        for v in supposed {
            let kept = v.draft.personalInfo.name.map { CVData(personalInfo: person(name: $0)) } ?? CVData()
            rows.append(row("a-mood-of-supposition-claims-nothing-\(v.id)", "the mood only supposes or wishes: nothing of the clause stays",
                            v.description, v.draft, .exactly(kept), language: v.language))
        }
        rows.append(row("hatte-in-the-past-is-a-fact-de", "hatte without an umlaut is the past: the language stays",
                        "Ich hatte Spanisch in der Schule.", CVData(languages: [Language(name: "Spanisch")]), .unchanged, language: "de"))
        rows.append(row("a-past-after-d-keeps-the-title-and-place-en", "I'd worked is I had worked: the title and the place stay",
                        "I'm Maria Rossi. I'd worked as a teacher in Berlin.", maria("teacher", "Berlin"), .unchanged))
        return rows
    }

    /// A question claims nothing (#202): a sentence that ends with a question mark, every clause of it. The sentence after it claims
    /// as usual, and a question the person answers loses its item: an accepted loss.
    private static func questionsClaimNothing() -> [GroundingRow] {
        typealias Question = (language: String, question: String, name: String, answered: String)
        var questions: [Question] = []
        questions.append(("en", "Do I speak French?", "French", "Do you need a translator? I speak French."))
        questions.append(("it", "Parlo francese?", "francese", "Cercate un traduttore? Parlo francese."))
        questions.append(("de", "Spreche ich Französisch?", "Französisch", "Suchen Sie einen Übersetzer? Ich spreche Französisch."))
        questions.append(("es", "¿Hablo francés?", "francés", "¿Busca un traductor? Hablo francés."))
        questions.append(("fr", "Est-ce que je parle français ?", "français", "Vous cherchez un traducteur ? Je parle français."))
        questions.append(("pt", "Falo francês?", "francês", "Procura um tradutor? Falo francês."))

        var rows: [GroundingRow] = []
        for v in questions {
            let draft = CVData(languages: [Language(name: v.name)])
            rows.append(row("a-question-claims-no-language-\(v.language)", "the person only asks: no language",
                            v.question, draft, .exactly(CVData()), language: v.language))
            rows.append(row("a-fact-after-a-question-keeps-its-language-\(v.language)",
                            "the question is the reader's; the sentence after it is a fact: the language stays",
                            v.answered, draft, .unchanged, language: v.language))
        }
        rows.append(row("a-sentence-that-ends-in-a-question-claims-nothing",
                        "the sentence ends with a question mark: neither language stays, not even the one before the comma",
                        "Parlo francese e tedesco, giusto?",
                        CVData(languages: [Language(name: "francese"), Language(name: "tedesco")]), .exactly(CVData()), language: "it"))
        rows.append(row("a-question-the-person-answers-is-an-accepted-loss",
                        "the item stands only in the question, and the answer does not name it: French goes, an accepted loss",
                        "Do I speak French? Yes, fluently.", CVData(languages: [Language(name: "French")]), .exactly(CVData())))
        return rows
    }

    /// What stands inside quotation marks claims nothing (#202): another person's words, or words the person only quotes. Every
    /// mark of the six languages counts, straight or typographic, and a quote may run over two sentences. An apostrophe inside a word
    /// is no mark, and a mark that nothing closes quotes nothing. A skill the person puts between quotation marks goes: an accepted
    /// loss.
    private static func quotedSpeechClaimsNothing() -> [GroundingRow] {
        typealias Message = (language: String, description: String, name: String)
        var messages: [Message] = []
        messages.append(("en", "A message from my colleague:\n“I speak French.”", "French"))
        messages.append(("it", "Messaggio del mio collega:\n«Parlo francese.»", "francese"))
        messages.append(("de", "Eine Nachricht meines Kollegen:\n„Ich spreche Französisch.“", "Französisch"))
        messages.append(("es", "Un mensaje de mi colega:\n«Hablo francés.»", "francés"))
        messages.append(("fr", "Un message de mon collègue :\n« Je parle français. »", "français"))
        messages.append(("pt", "Uma mensagem do meu colega:\n“Falo francês.”", "francês"))

        var rows: [GroundingRow] = []
        for v in messages {
            rows.append(row("a-quoted-message-claims-no-language-\(v.language)", "the language stands only inside quotation marks: no language",
                            v.description, CVData(languages: [Language(name: v.name)]), .exactly(CVData()), language: v.language))
        }
        let marks: [(id: String, open: String, close: String)] = [
            ("straight-double", "\"", "\""), ("straight-single", "'", "'"), ("curly-double", "“", "”"), ("curly-single", "‘", "’"),
            ("guillemets", "«", "»"), ("low-and-high", "„", "“"), ("low-and-curly", "„", "”"), ("reversed-guillemets", "»", "«"),
            ("single-guillemets", "‹", "›"),
        ]
        for mark in marks {
            rows.append(row("speech-in-\(mark.id)-marks-claims-nothing", "the whole description is a quote: no language",
                            "\(mark.open)I speak French.\(mark.close)", CVData(languages: [Language(name: "French")]), .exactly(CVData())))
        }
        rows.append(row("a-quote-of-two-sentences-claims-nothing",
                        "the quote runs over two sentences: neither language stays",
                        "Feedback from a client: “I speak French. I also speak German.”",
                        CVData(languages: [Language(name: "French"), Language(name: "German")]), .exactly(CVData())))
        rows.append(row("words-after-a-quote-still-claim",
                        "only the quoted words claim nothing: Swift stands after the closing mark, and stays",
                        "I use “clean code” principles with Swift every day.", CVData(skills: [Skill(name: "Swift")]), .unchanged))
        rows.append(row("typographic-apostrophes-are-no-quotation-marks-en",
                        "the apostrophes of I’m and I’ve are inside words: French and Swift stay",
                        "I’m fluent in French and I’ve used Swift.",
                        CVData(skills: [Skill(name: "Swift")], languages: [Language(name: "French")]), .unchanged))
        rows.append(row("typographic-apostrophes-are-no-quotation-marks-fr",
                        "the apostrophes of j’ai and l’anglais are inside words: Swift and English stay",
                        "J’ai utilisé Swift et je parle l’anglais.",
                        CVData(skills: [Skill(name: "Swift")], languages: [Language(name: "anglais")]), .unchanged, language: "fr"))
        rows.append(row("typographic-apostrophes-are-no-quotation-marks-it",
                        "the apostrophe of l’inglese is inside the word: English stays",
                        "Ho usato Swift e parlo l’inglese.",
                        CVData(skills: [Skill(name: "Swift")], languages: [Language(name: "inglese")]), .unchanged, language: "it"))
        rows.append(row("a-mark-nothing-closes-quotes-nothing",
                        "the opening mark has no closing one: it quotes nothing, and both languages stay",
                        "I speak “French and German.",
                        CVData(languages: [Language(name: "French"), Language(name: "German")]), .unchanged))
        rows.append(row("a-skill-in-quotation-marks-is-an-accepted-loss",
                        "the skill stands only inside quotation marks: Swift goes, an accepted loss",
                        "I work with “Swift” every day.", CVData(skills: [Skill(name: "Swift")]), .exactly(CVData())))
        rows += singleMarksAfterAWord()
        rows += marksAtTheEndOfALine()
        return rows
    }

    /// A mark at the end of a line opens a quote that goes on with the next lines (#202), when a mark may close it there: a speech
    /// introduced without a colon, its words on the next line ("Mon collègue a écrit '", then "Je parle français.'"), claims nothing.
    /// With nothing to close it, the mark opens nothing, and the next line claims as usual.
    private static func marksAtTheEndOfALine() -> [GroundingRow] {
        typealias Speech = (language: String, description: String, name: String)
        var speeches: [Speech] = []
        speeches.append(("en", "My colleague wrote \"\nI speak French.\"", "French"))
        speeches.append(("it", "Il mio collega ha scritto “\nParlo francese.”", "francese"))
        speeches.append(("de", "Mein Kollege schrieb „\nIch spreche Französisch.“", "Französisch"))
        speeches.append(("es", "Mi colega escribió \"\nHablo francés.\"", "francés"))
        speeches.append(("fr", "Mon collègue a écrit '\nJe parle français.'", "français"))
        speeches.append(("pt", "O meu colega escreveu ‘\nFalo francês.’", "francês"))

        var rows: [GroundingRow] = []
        for v in speeches {
            rows.append(row("a-mark-at-the-end-of-a-line-opens-a-quote-\(v.language)",
                            "the mark ends the colleague's line and the next line closes it: the quote is the colleague's, and no language",
                            v.description, CVData(languages: [Language(name: v.name)]), .exactly(CVData()), language: v.language))
        }
        rows.append(row("a-mark-at-the-end-of-a-line-opens-a-quote-that-only-a-word-may-close",
                        "the mark ends the colleague's line and only the possessive may close it: the next line is quoted to its end, and no language",
                        "My colleague wrote '\nI manage patients' records. I speak French.", CVData(languages: [Language(name: "French")]),
                        .exactly(CVData())))
        rows.append(row("a-mark-at-the-end-of-a-line-that-nothing-closes-opens-nothing",
                        "no mark closes the one that ends the first line: it opens nothing, and both languages stay",
                        "I speak French “\nI speak German.", CVData(languages: [Language(name: "French"), Language(name: "German")]), .unchanged))
        rows.append(row("a-possessive-at-the-end-of-a-line-opens-nothing",
                        "the mark after James is a possessive, no opening mark: French stays",
                        "I studied at St. James'\nI speak French.", CVData(languages: [Language(name: "French")]), .unchanged))
        return rows
    }

    /// A single mark right after a letter or a digit may end a word rather than a quote (#202): a possessive ("patients' records",
    /// "Hans’ Team"), an elision ("un po'", "all' università", "jusqu' à") or a prime ("a 5' de la oficina"), whatever follows it. It
    /// closes no quote: the quote runs to a mark that closes it for sure, after a punctuation mark, or, with none, to the end of the
    /// line of the last mark that may. An apostrophe outside a quote still claims as usual ("I'm", "l'inglese", "dell'università",
    /// "clients' apps"). A quote that such a mark closes takes the rest of its line with it, and so does an apostrophe that starts a
    /// word when a later one may close it ("the '90s"): accepted losses.
    private static func singleMarksAfterAWord() -> [GroundingRow] {
        typealias Passage = (id: String, language: String, description: String, name: String)
        var passages: [Passage] = []
        passages.append(("straight-possessive-en", "en", "My colleague said 'I manage patients' records. I speak French.'", "French"))
        passages.append(("curly-possessive-en", "en", "My colleague said ‘I manage patients’ records. I speak French.’", "French"))
        passages.append(("possessive-of-a-name-de", "de", "Mein Kollege sagte: ‚Ich leite Hans’ Team. Ich spreche Französisch.‘", "Französisch"))
        passages.append(("low-mark-as-an-apostrophe-de", "de", "Mein Kollege sagte: ‚Ich leite Hans‘ Team. Ich spreche Französisch.‘",
                         "Französisch"))
        passages.append(("straight-possessive-of-a-name-de", "de", "Mein Kollege sagte: 'Ich leite Hans' Team. Ich spreche Französisch.'",
                         "Französisch"))
        passages.append(("elision-before-a-word-it", "it", "Il mio collega ha detto: 'Parlo un po' di tedesco. Parlo francese.'", "francese"))
        passages.append(("elision-before-a-full-stop-it", "it", "Il mio collega ha detto: 'Parlo tedesco solo un po'. Parlo francese.'",
                         "francese"))
        passages.append(("elision-before-a-space-it", "it", "Il mio collega ha scritto: 'Ho studiato all' università. Parlo francese.'",
                         "francese"))
        passages.append(("elision-before-a-space-fr", "fr", "Mon collègue a écrit : 'Je travaille jusqu' à huit heures. Je parle français.'",
                         "français"))
        passages.append(("prime-es", "es", "Mi colega dijo: 'Vivo a 5' de la oficina. Hablo francés.'", "francés"))
        passages.append(("prime-pt", "pt", "O meu colega disse: 'Moro a 5' do escritório. Falo francês.'", "francês"))

        var rows: [GroundingRow] = []
        for v in passages {
            rows.append(row("a-quote-runs-past-a-\(v.id)",
                            "the mark after the word may end the word, not the quote: the quote runs to the mark after the full stop, and no language",
                            v.description, CVData(languages: [Language(name: v.name)]), .exactly(CVData()), language: v.language))
        }

        let unclosed: [Passage] = [
            ("straight-possessive-en", "en", "My colleague said 'I manage patients' records. I speak French.", "French"),
            ("curly-possessive-en", "en", "My colleague said ‘I manage patients’ records. I speak French.", "French"),
            ("possessive-of-a-name-de", "de", "Mein Kollege sagte: ‚Ich leite Hans’ Team. Ich spreche Französisch.", "Französisch"),
            ("elision-it", "it", "Il mio collega ha detto: 'Parlo un po' di tedesco. Parlo francese.", "francese"),
        ]
        for v in unclosed {
            rows.append(row("a-quote-only-a-word-could-close-runs-to-the-end-of-its-line-\(v.id)",
                            "nothing closes the quote for sure: it runs to the end of its line, and no language",
                            v.description, CVData(languages: [Language(name: v.name)]), .exactly(CVData()), language: v.language))
        }
        rows.append(row("a-quote-only-a-word-could-close-stops-at-the-end-of-its-line",
                        "the quote runs to the end of its line; the next line is the person's: German stays",
                        "My colleague said 'I manage patients' records. I speak French.\nI speak German.",
                        CVData(languages: [Language(name: "French"), Language(name: "German")]),
                        .exactly(CVData(languages: [Language(name: "German")]))))

        // No quote: the apostrophes and the possessives claim as usual.
        rows.append(row("straight-apostrophes-are-no-quotation-marks-en",
                        "the apostrophes of I'm and I've are inside words: French and Swift stay",
                        "I'm fluent in French and I've used Swift.",
                        CVData(skills: [Skill(name: "Swift")], languages: [Language(name: "French")]), .unchanged))
        rows.append(row("straight-apostrophes-are-no-quotation-marks-fr",
                        "the apostrophes of J'ai and l'anglais are inside words: Swift and English stay",
                        "J'ai utilisé Swift et je parle l'anglais.",
                        CVData(skills: [Skill(name: "Swift")], languages: [Language(name: "anglais")]), .unchanged, language: "fr"))
        rows.append(row("straight-apostrophes-are-no-quotation-marks-it",
                        "the apostrophes of dell'università and l'inglese are inside words: English stays",
                        "Ho una laurea dell'università di Bologna e parlo l'inglese.",
                        CVData(languages: [Language(name: "inglese")]), .unchanged, language: "it"))
        rows.append(row("a-possessive-outside-quotation-marks-claims-en",
                        "no mark opens a quote: the possessive is only a possessive, and Swift stays",
                        "I built my clients' apps with Swift.", CVData(skills: [Skill(name: "Swift")]), .unchanged))
        rows.append(row("a-possessive-outside-quotation-marks-claims-de",
                        "no mark opens a quote: the possessive is only a possessive, and Swift stays",
                        "Ich habe in Hans' Team mit Swift gearbeitet.", CVData(skills: [Skill(name: "Swift")]), .unchanged, language: "de"))
        rows.append(row("a-possessive-after-a-closed-quote-claims",
                        "the quote closed before the possessive: Swift stays",
                        "My motto is “clean code”. I built my clients' apps with Swift.", CVData(skills: [Skill(name: "Swift")]), .unchanged))

        // Accepted losses: a single mark that closes a quote right after a word may be an apostrophe, so the rest of its line goes.
        rows.append(row("words-after-a-single-mark-after-a-word-are-an-accepted-loss",
                        "the mark after code may be an apostrophe: the quote runs to the end of the line, and Swift goes, an accepted loss",
                        "I use 'clean code' principles with Swift every day.", CVData(skills: [Skill(name: "Swift")]), .exactly(CVData())))
        rows.append(row("a-sentence-after-a-single-mark-after-a-word-is-an-accepted-loss",
                        "the mark after French may be an apostrophe: the quote runs to the end of the line, and German goes too, an accepted loss",
                        "My colleague said 'I speak French'. I speak German.",
                        CVData(languages: [Language(name: "French"), Language(name: "German")]), .exactly(CVData())))
        rows.append(row("an-apostrophe-that-starts-a-word-before-a-possessive-is-an-accepted-loss",
                        "the apostrophe of '90s may open a quote that the possessive may close: both lines go, Swift with them, an accepted loss; French stays",
                        "I grew up in the '90s.\nI built my clients' apps with Swift.\nI speak French.",
                        CVData(skills: [Skill(name: "Swift")], languages: [Language(name: "French")]),
                        .exactly(CVData(languages: [Language(name: "French")]))))
        return rows
    }

    /// A line that ends with a colon and does not speak for the person introduces someone else's words: the line after it claims
    /// nothing, all its sentences (#202). The line after that claims as usual, and so does the line after a colon line that the
    /// person speaks ("My languages:", "Skills:", "I worked with my team on:"). Words without marks after the colon on its own line
    /// are read by their own clauses, and a sentence after the colon's keeps its item: an open residual risk that #249 must close
    /// (`notImplementedYet`).
    private static func speechAfterALineOfAnotherPerson() -> [GroundingRow] {
        typealias Speech = (language: String, description: String, name: String)
        var speeches: [Speech] = []
        speeches.append(("en", "My colleague wrote:\nI speak French.", "French"))
        speeches.append(("it", "Il mio collega ha scritto:\nParlo francese.", "francese"))
        speeches.append(("de", "Mein Kollege schrieb:\nIch spreche Französisch.", "Französisch"))
        speeches.append(("es", "Mi colega escribió:\nHablo francés.", "francés"))
        speeches.append(("fr", "Mon collègue a écrit :\nJe parle français.", "français"))
        speeches.append(("pt", "O meu colega escreveu:\nFalo francês.", "francês"))

        var rows: [GroundingRow] = []
        for v in speeches {
            rows.append(row("the-line-after-another-persons-colon-claims-nothing-\(v.language)",
                            "the colleague's line introduces the colleague's words: no language",
                            v.description, CVData(languages: [Language(name: v.name)]), .exactly(CVData()), language: v.language))
        }
        rows.append(row("every-sentence-of-the-introduced-line-claims-nothing",
                        "both sentences of the line after the colon are the colleague's; the next line is the person's: Italian stays",
                        "My colleague wrote:\nI speak French. I speak German.\nI speak Italian.",
                        CVData(languages: [Language(name: "French"), Language(name: "German"), Language(name: "Italian")]),
                        .exactly(CVData(languages: [Language(name: "Italian")]))))
        rows.append(row("speech-on-the-line-of-the-colon-claims-nothing",
                        "the colleague's words follow the colon on its own line: neither language stays",
                        "My colleague wrote: I speak French. I speak German.",
                        CVData(languages: [Language(name: "French"), Language(name: "German")]), .exactly(CVData())))
        rows.append(row("the-line-after-the-persons-own-colon-claims-en", "my languages are the person's: both languages stay",
                        "My languages:\nItalian and English.",
                        CVData(languages: [Language(name: "Italian"), Language(name: "English")]), .unchanged))
        rows.append(row("the-line-after-the-persons-own-colon-claims-it", "le mie lingue are the person's: both languages stay",
                        "Le mie lingue:\nitaliano e inglese.",
                        CVData(languages: [Language(name: "italiano"), Language(name: "inglese")]), .unchanged, language: "it"))
        rows.append(row("the-line-after-a-label-claims", "a label speaks for no one else: both skills stay",
                        "Skills:\nPython, Swift.", CVData(skills: [Skill(name: "Python"), Skill(name: "Swift")]), .unchanged))
        rows.append(row("the-line-after-the-persons-own-statement-claims", "the person speaks the colon line: both skills stay",
                        "I worked with my team on:\nSwift and Kotlin apps.",
                        CVData(skills: [Skill(name: "Swift"), Skill(name: "Kotlin")]), .unchanged))
        return rows
    }

    /// A relative pronoun or a subordinator that brings in another subject withdraws what follows it in its clause (#202): "I work with
    /// a colleague who speaks French" claims no French, nor "Ich leite ein Team, das Kotlin und Swift nutzt" Kotlin. When the person
    /// stays the subject ("which I use", "che uso", "das ich nutze", "que je parle"), or the item stands before the pronoun, the item
    /// stays. When the person is the subject that the pronoun brings in ("I am a developer who knows Swift"), the item goes: an
    /// accepted loss.
    private static func relativeClausesOfAnotherSubject() -> [GroundingRow] {
        typealias Variant = (
            language: String, colleague: String, spoken: String, team: String, before: String, person: String, languages: [String]
        )
        var variants: [Variant] = []
        variants.append(("en", "I work with a colleague who speaks French.", "French", "I manage a team that uses Kotlin and Swift.",
                         "I speak French, which I use every day.", "The languages that I speak are French and German.", ["French", "German"]))
        variants.append(("it", "Io lavoro con un collega che parla francese.", "francese", "Gestisco un team che usa Kotlin e Swift.",
                         "Parlo francese, che uso ogni giorno.", "Le lingue che parlo sono il francese e il tedesco.", ["francese", "tedesco"]))
        variants.append(("de", "Ich arbeite mit einem Kollegen, der Französisch spricht.", "Französisch",
                         "Ich leite ein Team, das Kotlin und Swift nutzt.", "Ich spreche Französisch, das ich täglich nutze.",
                         "Die Sprachen, die ich spreche, sind Französisch und Deutsch.", ["Französisch", "Deutsch"]))
        variants.append(("es", "Trabajo con un colega que habla francés.", "francés", "Dirijo un equipo que usa Kotlin y Swift.",
                         "Hablo francés, que uso cada día.", "Los idiomas que hablo son el francés y el alemán.", ["francés", "alemán"]))
        variants.append(("fr", "Je travaille avec un collègue qui parle français.", "français", "Je dirige une équipe qui utilise Kotlin et Swift.",
                         "Je parle français, que j'utilise tous les jours.", "Les langues que je parle sont le français et l'allemand.",
                         ["français", "allemand"]))
        variants.append(("pt", "Trabalho com um colega que fala francês.", "francês", "Coordeno uma equipe que usa Kotlin e Swift.",
                         "Falo francês, que uso todos os dias.", "As línguas que falo são o francês e o alemão.", ["francês", "alemão"]))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("a-colleagues-language-after-a-relative-is-not-the-persons-\(v.language)",
                            "the colleague speaks the language: no language", v.colleague, CVData(languages: [Language(name: v.spoken)]),
                            .exactly(CVData()), language: v.language))
            rows.append(row("a-teams-skills-after-a-relative-are-not-the-persons-\(v.language)",
                            "the team uses both skills, the one after the conjunction too: no skill", v.team,
                            CVData(skills: [Skill(name: "Kotlin"), Skill(name: "Swift")]), .exactly(CVData()), language: v.language))
            rows.append(row("an-item-before-a-relative-stays-\(v.language)",
                            "the person speaks the language before the pronoun, and uses it after: the language stays", v.before,
                            CVData(languages: [Language(name: v.spoken)]), .unchanged, language: v.language))
            rows.append(row("the-person-after-a-relative-keeps-the-items-\(v.language)",
                            "the person is the subject after the pronoun: both languages stay", v.person,
                            CVData(languages: v.languages.map { Language(name: $0) }), .unchanged, language: v.language))
        }
        rows.append(row("a-clause-of-the-person-after-a-relative-claims",
                        "the colleague speaks French; the person speaks German in a clause of their own: German stays",
                        "I work with a colleague who speaks French, and I speak German.",
                        CVData(languages: [Language(name: "French"), Language(name: "German")]),
                        .exactly(CVData(languages: [Language(name: "German")]))))
        rows.append(row("a-relative-after-the-item-keeps-it",
                        "Python stands before which, and the person knows it: the skill stays",
                        "I work with Python, which I know well.", CVData(skills: [Skill(name: "Python")]), .unchanged))
        rows.append(row("a-friends-skill-in-a-relative-is-no-skill-of-the-person",
                        "the friend teaches chess; the person only likes it in her free time: the skill goes, the interest stays",
                        "In my free time I like chess. I have a friend who teaches chess.",
                        CVData(skills: [Skill(name: "chess")], interests: ["chess"]), .exactly(CVData(interests: ["chess"]))))
        rows.append(row("a-demonstrative-that-is-no-relative",
                        "that before a noun points at the role: Python stays", "In that role I used Python.",
                        CVData(skills: [Skill(name: "Python")]), .unchanged))
        rows.append(row("a-demonstrative-that-after-a-preposition-is-no-relative",
                        "that after on points at the project: Swift stays", "I worked on that project with Swift.",
                        CVData(skills: [Skill(name: "Swift")]), .unchanged))
        rows.append(row("que-before-an-infinitive-brings-in-no-subject",
                        "tengo que hablar has no other subject: English stays", "Tengo que hablar inglés en el trabajo.",
                        CVData(languages: [Language(name: "inglés")]), .unchanged, language: "es"))
        rows.append(row("the-person-as-the-subject-of-who-is-an-accepted-loss",
                        "the developer who knows Swift is the person, but who reads as another subject: Swift goes, an accepted loss",
                        "I am a developer who knows Swift.", CVData(skills: [Skill(name: "Swift")]), .exactly(CVData())))
        rows.append(row("the-person-as-the-subject-of-che-is-an-accepted-loss",
                        "the person who loves photography is the person, but che reads as another subject: the interest goes, an accepted loss",
                        "Sono una persona che ama la fotografia.", CVData(interests: ["fotografia"]), .exactly(CVData()), language: "it"))
        rows.append(row("a-thing-that-uses-a-skill-is-an-accepted-loss-en",
                        "the apps use Swift and the person builds them, but that reads as another subject: Swift goes, an accepted loss",
                        "I build apps that use Swift.", CVData(skills: [Skill(name: "Swift")]), .exactly(CVData())))
        rows.append(row("a-thing-that-uses-a-skill-is-an-accepted-loss-it",
                        "the apps use Swift and the person builds them, but che reads as another subject: Swift goes, an accepted loss",
                        "Sviluppo app che usano Swift.", CVData(skills: [Skill(name: "Swift")]), .exactly(CVData()), language: "it"))
        rows.append(row("lo-que-before-the-item-is-an-accepted-loss",
                        "what I like most is the person's, but que reads as bringing in another subject: the interest goes, an accepted loss",
                        "Lo que más me gusta es el ajedrez.", CVData(interests: ["ajedrez"]), .exactly(CVData()), language: "es"))
        rows += infinitivesAfterARelative()
        return rows
    }

    /// A word after a relative that ends the way an infinitive does keeps no person by its ending (#202): it is often a finite form of
    /// the subject the relative brings in ("qui prépare", "qui offre", "che appare", "que requer", "quem souber"). The person stays
    /// the subject of an infinitive after "que" only in the periphrasis of obligation, after a form of Spanish "tener" or Portuguese
    /// "ter" that the person can say ("tengo que hablar", "he tenido que", "tenho que falar"). Any other infinitive after a relative
    /// claims nothing: "hay que hablar inglés" says what a job needs, and "un team con cui parlare inglese" loses English, accepted
    /// losses.
    private static func infinitivesAfterARelative() -> [GroundingRow] {
        typealias Variant = (id: String, language: String, description: String, skill: String)
        var finite: [Variant] = []
        finite.append(("prepare-fr", "fr", "Je travaille avec une collègue qui prépare des cours de Python.", "Python"))
        finite.append(("assure-fr", "fr", "Je travaille avec une collègue qui assure les cours de Python.", "Python"))
        finite.append(("offre-fr", "fr", "Je travaille avec un collègue qui offre des formations en Python.", "Python"))
        finite.append(("decouvre-fr", "fr", "Je travaille avec un collègue qui découvre Kotlin.", "Kotlin"))
        finite.append(("appare-it", "it", "Lavoro con un collega che appare spesso nei video su Python.", "Python"))
        finite.append(("compare-it", "it", "Lavoro con un collega che compare in tutti i video di Python.", "Python"))
        finite.append(("requer-pt", "pt", "Trabalho com uma equipe que requer Python.", "Python"))
        finite.append(("souber-pt", "pt", "Trabalho com quem souber Kotlin.", "Kotlin"))

        var rows: [GroundingRow] = []
        for v in finite {
            rows.append(row("a-finite-form-that-ends-like-an-infinitive-after-a-relative-is-another-subjects-\(v.id)",
                            "the verb after the relative is a finite form of another subject, though it ends like an infinitive: the skill goes",
                            v.description, CVData(skills: [Skill(name: v.skill)]), .exactly(CVData()), language: v.language))
        }
        rows.append(row("an-infinitive-after-a-relative-outside-an-obligation-claims-nothing-es",
                        "que follows a quantity, not a form of tener: the infinitive says what is left to learn, and Python goes",
                        "Tengo mucho que aprender de Python.", CVData(skills: [Skill(name: "Python")]), .exactly(CVData()), language: "es"))
        rows.append(row("an-impersonal-obligation-is-an-accepted-loss-es",
                        "hay que says what the job needs, not what the person speaks: English goes, an accepted loss",
                        "En mi trabajo hay que hablar inglés.", CVData(languages: [Language(name: "inglés")]), .exactly(CVData()), language: "es"))
        rows.append(row("an-infinitive-after-a-relative-is-an-accepted-loss-it",
                        "the person speaks English with the team, but cui reads as bringing in another subject: English goes, an accepted loss",
                        "Ho trovato un team con cui parlare inglese ogni giorno.", CVData(languages: [Language(name: "inglese")]), .exactly(CVData()),
                        language: "it"))

        // The periphrasis of obligation with a form of tener or ter that the person can say: the infinitive is the person's.
        let obligations: [(id: String, language: String, description: String, name: String)] = [
            ("tuve-es", "es", "Tuve que hablar inglés en el trabajo.", "inglés"),
            ("tenia-es", "es", "Tenía que hablar inglés en el trabajo.", "inglés"),
            ("he-tenido-es", "es", "He tenido que hablar inglés en el trabajo.", "inglés"),
            ("tenho-pt", "pt", "Tenho que falar inglês no trabalho.", "inglês"),
            ("tive-pt", "pt", "Tive que falar inglês no trabalho.", "inglês"),
            ("tinha-pt", "pt", "Tinha que falar inglês no trabalho.", "inglês"),
        ]
        for v in obligations {
            rows.append(row("que-in-an-obligation-of-the-person-brings-in-no-subject-\(v.id)",
                            "que after the person's form of tener or ter brings in no subject: the language stays",
                            v.description, CVData(languages: [Language(name: v.name)]), .unchanged, language: v.language))
        }
        return rows
    }

    /// The person's title and place come from a clause that claims them, but nothing tells whose they are inside it (ADR 0023,
    /// Consequences): "Io lavoro con un infermiere a Torino" gives the person the nurse's title. An open residual risk that #249 must
    /// close (`notImplementedYet`).
    private static func titlesOfAnotherPersonInAClaim() -> [GroundingRow] {
        typealias Variant = (language: String, description: String, title: String)
        var variants: [Variant] = []
        variants.append(("it", "Io lavoro con un infermiere a Torino.", "infermiere"))
        variants.append(("en", "I work with a nurse in Turin.", "nurse"))
        variants.append(("de", "Ich arbeite mit einem Krankenpfleger in Turin.", "Krankenpfleger"))
        variants.append(("es", "Trabajo con un enfermero en Turín.", "enfermero"))
        variants.append(("fr", "Je travaille avec un infirmier à Turin.", "infirmier"))
        variants.append(("pt", "Trabalho com um enfermeiro em Turim.", "enfermeiro"))

        return variants.map { v in
            row("the-title-of-a-person-the-claim-names-is-not-the-persons-\(v.language)",
                "the person works with a nurse: the title is the nurse's, and goes", v.description,
                CVData(personalInfo: person(title: v.title)), .exactly(CVData()), language: v.language)
        }
    }

    /// "plan", "plans" and "planning" say an intention only as verbs (#202): with "to", "on", an article or a possessive after them, or a
    /// subject, a form of "to be", an auxiliary or a possessive before them ("I am planning to learn Rust", "I'm also planning a move",
    /// "My plan is to"). After a content word, an article or a preposition they name an activity, and withdraw nothing: "route
    /// planning", "care plans", "responsible for planning". The other languages name the activity with a noun of its own
    /// ("pianificazione", "Routenplanung", "planificación", "planification", "planejamento"). A mention still needs a factual verb and
    /// an explained lead-in (rule (c)): "Since 2018 I have done route planning at Acme" gives no entry.
    private static func intentionWordsAsNouns() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        rows.append(row("care-plans-name-an-activity", "care plans names what the person wrote: the clause after it claims Python",
                        "I wrote care plans for 12 patients and I know Python.", CVData(skills: [Skill(name: "Python")]), .unchanged))
        rows.append(row("route-planning-in-a-job-clause-gives-the-entry",
                        "route planning names an activity: the clause mentions Acme as a fact, and the entry stays",
                        "Since 2018 I have worked in route planning at Acme.", CVData(experience: [job("", "Acme")]), .unchanged))
        rows.append(row("route-planning-before-the-name-after-done-is-an-accepted-loss",
                        "done is no verb of a CV and route planning stands unexplained before the name: no factual mention, an accepted loss",
                        "Since 2018 I have done route planning at Acme.", CVData(experience: [job("", "Acme")]), .exactly(CVData())))
        rows.append(row("planning-to-learn-claims-nothing", "planning to is an intention: no skill",
                        "I am planning to learn Rust.", CVData(skills: [Skill(name: "Rust")]), .exactly(CVData())))
        rows.append(row("route-planning-is-a-skill-the-person-claims",
                        "route planning is a skill, and team leadership shares its clause: the three skills stay",
                        "I am good at SAP, route planning and team leadership.",
                        CVData(skills: [Skill(name: "SAP"), Skill(name: "route planning"), Skill(name: "team leadership")]), .unchanged))
        rows.append(row("planning-after-a-preposition-names-the-work", "responsible for planning names the work: budgeting stays",
                        "I was responsible for planning and budgeting.", CVData(skills: [Skill(name: "budgeting")]), .unchanged))
        rows.append(row("planning-in-a-list-of-skills-is-a-skill", "a list of skills names planning: the three skills stay",
                        "Skills: planning, budgeting and Excel.",
                        CVData(skills: [Skill(name: "planning"), Skill(name: "budgeting"), Skill(name: "Excel")]), .unchanged))
        rows.append(row("my-plan-is-an-intention", "a possessive before plan makes it the person's intention: no language",
                        "My plan is to learn Spanish.", CVData(languages: [Language(name: "Spanish")]), .exactly(CVData())))
        rows.append(row("planning-a-move-is-an-intention", "planning before an article plans a move: the place goes, the name stays",
                        "I'm Maria Rossi. I'm also planning a move to Berlin.",
                        CVData(personalInfo: person(name: "Maria Rossi", location: "Berlin")),
                        .exactly(CVData(personalInfo: person(name: "Maria Rossi")))))
        rows.append(row("planning-on-is-an-intention", "planning on is an intention: no skill",
                        "I'm planning on a Rust course.", CVData(skills: [Skill(name: "Rust")]), .exactly(CVData())))

        typealias Planning = (language: String, activity: String, intention: String)
        var others: [Planning] = []
        others.append(("it", "Mi occupo della pianificazione dei percorsi e conosco Python.", "Intendo imparare Rust."))
        others.append(("de", "Ich bin für die Routenplanung zuständig und kenne Python.", "Ich beabsichtige, Rust zu lernen."))
        others.append(("es", "Me encargo de la planificación de rutas y conozco Python.", "Planeo aprender Rust."))
        others.append(("fr", "Je m'occupe de la planification des itinéraires et je connais Python.", "Je prévois d'apprendre Rust."))
        others.append(("pt", "Cuido do planejamento de rotas e conheço Python.", "Planeio aprender Rust."))
        for v in others {
            rows.append(row("a-noun-of-planning-withdraws-nothing-\(v.language)", "the noun names the work: Python stays",
                            v.activity, CVData(skills: [Skill(name: "Python")]), .unchanged, language: v.language))
            rows.append(row("a-verb-of-planning-claims-nothing-\(v.language)", "the person only plans to learn it: no skill",
                            v.intention, CVData(skills: [Skill(name: "Rust")]), .exactly(CVData()), language: v.language))
        }
        return rows
    }

    /// An intention said by a phrase claims nothing (#202), like a wish: "Ho intenzione di", "Tengo la intención de", "J'ai l'intention
    /// d'", "Tenho a intenção de", "I have the intention of"; German "Ich plane" and "vorhaben", whose "vor" ends its clause ("Ich habe
    /// vor, Rust zu lernen", "das habe ich vor"). A "vor" before a time is none ("vor 5 Jahren"), and "Plan", "Pläne" after a content
    /// word or an article are nouns.
    private static func intentionsInAPhrase() -> [GroundingRow] {
        typealias Intention = (id: String, language: String, description: String)
        var intentions: [Intention] = []
        intentions.append(("intenzione-di-it", "it", "Ho intenzione di imparare Rust."))
        intentions.append(("intencion-de-es", "es", "Tengo la intención de aprender Rust."))
        intentions.append(("intention-d-fr", "fr", "J'ai l'intention d'apprendre Rust."))
        intentions.append(("intention-de-fr", "fr", "J'ai l'intention de suivre un cours de Rust."))
        intentions.append(("intencao-de-pt", "pt", "Tenho a intenção de aprender Rust."))
        intentions.append(("intention-of-en", "en", "I have the intention of learning Rust."))
        intentions.append(("ich-plane-de", "de", "Ich plane, Rust zu lernen."))
        intentions.append(("plane-ich-de", "de", "Nächstes Jahr plane ich, Rust zu lernen."))
        intentions.append(("habe-vor-de", "de", "Ich habe vor, Rust zu lernen."))
        intentions.append(("das-habe-ich-vor-de", "de", "Rust zu lernen, das habe ich vor."))

        var rows: [GroundingRow] = []
        for v in intentions {
            rows.append(row("an-intention-in-a-phrase-claims-nothing-\(v.id)", "the person only intends to learn it: no skill",
                            v.description, CVData(skills: [Skill(name: "Rust")]), .exactly(CVData()), language: v.language))
        }
        rows.append(row("an-intended-place-is-not-the-persons-fr", "the person only intends to work there: the name stays, the place goes",
                        "Je suis Maria Rossi. J'ai l'intention de travailler à Berlin.",
                        CVData(personalInfo: person(name: "Maria Rossi", location: "Berlin")),
                        .exactly(CVData(personalInfo: person(name: "Maria Rossi"))), language: "fr"))
        rows.append(row("vor-before-a-time-keeps-the-entry-de", "vor 5 Jahren is a time, no intention: the entry stays",
                        "Ich habe vor 5 Jahren bei Acme gearbeitet.", CVData(experience: [job("", "Acme")]), .unchanged, language: "de"))
        rows.append(row("a-plan-after-an-article-is-a-noun-de", "einen Plan names what the person made: Python stays",
                        "Ich habe einen Plan erstellt und kenne Python.", CVData(skills: [Skill(name: "Python")]), .unchanged, language: "de"))
        rows.append(row("plans-after-a-verb-are-a-noun-de", "Pläne names what the person made: Python stays",
                        "Ich habe Pläne für 30 Baustellen erstellt und kenne Python.", CVData(skills: [Skill(name: "Python")]), .unchanged,
                        language: "de"))
        rows.append(row("my-plan-is-an-intention-de", "a possessive before Plan makes it the person's intention: no skill",
                        "Mein Plan ist, Rust zu lernen.", CVData(skills: [Skill(name: "Rust")]), .exactly(CVData()), language: "de"))
        rows.append(row("an-intention-without-its-preposition-is-no-intention-it",
                        "intenzione without di names the client's: Python stays",
                        "Ho capito l'intenzione del cliente e uso Python.", CVData(skills: [Skill(name: "Python")]), .unchanged, language: "it"))
        return rows
    }

    /// A negation keeps its item only when it governs the word of level (#202): "not an expert", "never been fluent". A negation of
    /// the ability itself withdraws the claim, though a word of level stands later in the clause: "I cannot speak German even at a
    /// basic level", "I have never used Python at any level".
    private static func negationsOfTheAbility() -> [GroundingRow] {
        typealias Variant = (language: String, cannotSpeak: String, spoken: String, neverUsed: String)
        var variants: [Variant] = []
        variants.append(("en", "I cannot speak German even at a basic level.", "German", "I have never used Python at any level."))
        variants.append(("it", "Non so parlare tedesco nemmeno a livello base.", "tedesco", "Non ho mai usato Python a nessun livello."))
        variants.append(("de", "Ich kann nicht einmal auf einfachem Niveau Deutsch sprechen.", "Deutsch",
                         "Ich habe Python nie auf irgendeinem Niveau benutzt."))
        variants.append(("es", "No puedo hablar alemán ni siquiera a nivel básico.", "alemán", "Nunca he usado Python a ningún nivel."))
        variants.append(("fr", "Je ne sais pas parler allemand même à un niveau de base.", "allemand",
                         "Je n'ai jamais utilisé Python à aucun niveau."))
        variants.append(("pt", "Não consigo falar alemão nem em nível básico.", "alemão", "Nunca usei Python em nenhum nível."))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("a-denied-ability-beside-a-level-gives-no-language-\(v.language)",
                            "the negation denies speaking, not a level: no language",
                            v.cannotSpeak, CVData(languages: [Language(name: v.spoken)]), .exactly(CVData()), language: v.language))
            rows.append(row("a-denied-use-beside-a-level-gives-no-skill-\(v.language)",
                            "the negation denies the use, not a level: no skill",
                            v.neverUsed, CVData(skills: [Skill(name: "Python")]), .exactly(CVData()), language: v.language))
        }
        return rows
    }

    /// The readings of the claim rule that ADR 0023 accepts as they are (Consequences): a negation that governs a word of level denies
    /// the level only, a condition at the start of a clause makes the rest of its sentence a supposition, and "could" withdraws a claim.
    private static func acceptedReadingsOfAClaim() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        rows.append(row("a-negation-beside-a-level-keeps-the-language",
                        "never fluent denies the level only: German stays, without a level",
                        "I have never been fluent in German.", CVData(languages: [Language(name: "German")]), .unchanged))
        rows.append(row("a-condition-makes-a-habit-a-supposition",
                        "the condition opens the sentence: playing chess is supposed, and no interest stays",
                        "If I have time, I play chess.", CVData(interests: ["chess"]), .exactly(CVData())))
        rows.append(row("could-withdraws-a-claim",
                        "could withdraws the claim: an accepted loss, and no language stays",
                        "I could already read Latin at school.", CVData(languages: [Language(name: "Latin")]), .exactly(CVData())))
        return rows
    }

    /// A clause that states nothing as a fact (no verb, or none factual: "Spanisch zu lernen") and is not a fragment of a factual
    /// clause shares the withdrawal of the clause after it in its sentence (#202): "Spanisch zu lernen, davon träume ich" gives no
    /// Spanish. A factual clause before a later wish keeps its item.
    private static func wishesAfterTheItem() -> [GroundingRow] {
        typealias Wish = (id: String, language: String, description: String, name: String)
        var wishes: [Wish] = []
        wishes.append(("de", "de", "Spanisch zu lernen, davon träume ich.", "Spanisch"))
        wishes.append(("en", "en", "Learning Spanish, that's what I'd like.", "Spanish"))
        wishes.append(("verbless-en", "en", "Spanish, that's what I'd like to learn.", "Spanish"))
        wishes.append(("it", "it", "Imparare lo spagnolo, è quello che vorrei.", "spagnolo"))
        wishes.append(("lo-sogno-it", "it", "Imparare lo spagnolo: lo sogno da sempre.", "spagnolo"))
        wishes.append(("es", "es", "Aprender alemán, eso es lo que quiero.", "alemán"))
        wishes.append(("lo-sueno-es", "es", "Hablar francés, lo sueño desde niña.", "francés"))
        wishes.append(("fr", "fr", "Apprendre l'espagnol, voilà ce que je voudrais.", "espagnol"))
        wishes.append(("en-reve-fr", "fr", "Parler italien, j'en rêve.", "italien"))
        wishes.append(("pt", "pt", "Aprender espanhol, é o que eu quero.", "espanhol"))

        var rows: [GroundingRow] = []
        for v in wishes {
            rows.append(row("a-wish-after-the-item-claims-no-language-\(v.id)",
                            "the clause of the language states nothing as a fact, and the clause after it only wishes: no language",
                            v.description, CVData(languages: [Language(name: v.name)]), .exactly(CVData()), language: v.language))
        }
        rows.append(row("a-fact-before-a-later-wish-keeps-its-language-de",
                        "ich spreche Spanisch is a fact: the dream that follows takes nothing from it",
                        "Ich spreche Spanisch, und davon träume ich nicht mehr.", CVData(languages: [Language(name: "Spanisch")]),
                        .unchanged, language: "de"))
        rows.append(row("a-fact-before-a-later-wish-keeps-its-language-en",
                        "I speak Spanish is a fact; French stands only in the wish: Spanish stays, French goes",
                        "I speak Spanish, and I'd like to learn French.",
                        CVData(languages: [Language(name: "Spanish"), Language(name: "French")]),
                        .exactly(CVData(languages: [Language(name: "Spanish")]))))
        rows.append(row("the-fragments-of-a-fact-keep-their-languages-before-a-wish",
                        "English and French belong to I speak: the wish to improve them takes nothing away",
                        "I speak Italian, English and French, which I'd like to improve.",
                        CVData(languages: [Language(name: "Italian"), Language(name: "English"), Language(name: "French")]), .unchanged))
        rows.append(row("a-coordinated-item-before-a-wish-claims-no-language",
                        "learning German states nothing as a fact, and Spanish is what the person would like: neither language stays",
                        "Learning German and Spanish is what I'd like.",
                        CVData(languages: [Language(name: "German"), Language(name: "Spanish")]), .exactly(CVData())))
        rows.append(row("a-verbless-line-before-a-wish-is-an-accepted-loss-en",
                        "fluent in English has no verb, and the wish after it withdraws it: English goes too, an accepted loss",
                        "Fluent in English, and I'd love to learn German.",
                        CVData(languages: [Language(name: "English"), Language(name: "German")]), .exactly(CVData())))
        rows.append(row("a-verbless-list-of-skills-before-a-wish-is-an-accepted-loss",
                        "the list of skills has no verb, and the wish after it withdraws it: Python and SQL go too, an accepted loss",
                        "Skills: Python and SQL, but I would like to learn Rust.",
                        CVData(skills: [Skill(name: "Python"), Skill(name: "SQL"), Skill(name: "Rust")]), .exactly(CVData())))
        rows.append(row("a-verbless-title-before-a-wish-is-an-accepted-loss",
                        "the line of the title has no verb, and the wish after it withdraws it: the title goes with the place, an accepted loss",
                        "Teacher at Acme since 2016, and I would like to move to Berlin.",
                        CVData(personalInfo: person(location: "Berlin", title: "Teacher")), .exactly(CVData())))
        rows.append(row("a-verbless-list-before-a-wish-is-an-accepted-loss",
                        "a list with no verb states nothing as a fact, and the wish after it withdraws it: the languages go, an accepted loss",
                        "Languages: Italian, English and French, which I'd like to improve.",
                        CVData(languages: [Language(name: "Italian"), Language(name: "English"), Language(name: "French")]),
                        .exactly(CVData())))
        return rows
    }

    /// The person's headline title and place count only in a clause that claims them (#202), like a skill: "I would like to work as a
    /// nurse in Turin" gives neither nurse nor Turin. The name stays wherever the person gives it.
    private static func personalFieldsOfAClaim() -> [GroundingRow] {
        typealias Variant = (language: String, wished: String, claimed: String, title: String, wishedTitle: String, place: String)
        var variants: [Variant] = []
        variants.append(("en", "I'm Maria Rossi, a teacher. I would like to work as a nurse in Turin.",
                         "I'm Maria Rossi. I work as a nurse in Turin.", "teacher", "nurse", "Turin"))
        variants.append(("it", "Sono Maria Rossi, insegnante. Vorrei lavorare come infermiera a Torino.",
                         "Sono Maria Rossi. Lavoro come infermiera a Torino.", "insegnante", "infermiera", "Torino"))
        variants.append(("de", "Ich bin Maria Rossi, Lehrerin. Ich möchte als Krankenschwester in Turin arbeiten.",
                         "Ich bin Maria Rossi. Ich arbeite als Krankenschwester in Turin.", "Lehrerin", "Krankenschwester", "Turin"))
        variants.append(("es", "Soy Maria Rossi, maestra. Quiero trabajar como enfermera en Turín.",
                         "Soy Maria Rossi. Trabajo como enfermera en Turín.", "maestra", "enfermera", "Turín"))
        variants.append(("fr", "Je suis Maria Rossi, enseignante. Je voudrais travailler comme infirmière à Turin.",
                         "Je suis Maria Rossi. Je travaille comme infirmière à Turin.", "enseignante", "infirmière", "Turin"))
        variants.append(("pt", "Sou Maria Rossi, professora. Quero trabalhar como enfermeira em Turim.",
                         "Sou Maria Rossi. Trabalho como enfermeira em Turim.", "professora", "enfermeira", "Turim"))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("a-wished-place-is-not-the-persons-\(v.language)",
                            "the title is the person's; the place stands only in a wish: the name and the title stay, the place goes",
                            v.wished, CVData(personalInfo: person(name: "Maria Rossi", location: v.place, title: v.title)),
                            .exactly(CVData(personalInfo: person(name: "Maria Rossi", title: v.title))), language: v.language))
            rows.append(row("a-wished-title-is-not-the-persons-\(v.language)",
                            "the title and the place stand only in a wish: the name stays, the title and the place go",
                            v.wished, CVData(personalInfo: person(name: "Maria Rossi", location: v.place, title: v.wishedTitle)),
                            .exactly(CVData(personalInfo: person(name: "Maria Rossi"))), language: v.language))
            rows.append(row("a-claimed-title-and-place-stay-\(v.language)",
                            "the person works as a nurse in the place: the name, the title and the place stay",
                            v.claimed, CVData(personalInfo: person(name: "Maria Rossi", location: v.place, title: v.wishedTitle)),
                            .unchanged, language: v.language))
        }
        return rows
    }

    /// Only the person's own clauses tell a hobby from a skill, as the grounding attributes them: another person's clause neither
    /// keeps the skill nor drops it. A clause of the person that denies, doubts or only wishes claims no ability, so it keeps no
    /// skill either.
    private static func hobbiesOfThePersonAlone() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        let chess = CVData(skills: [Skill(name: "chess")], interests: ["chess"])
        rows.append(row("a-hobby-is-no-skill-though-another-person-has-it-en",
                        "the sister teaches chess; the person only likes it in her free time: the skill goes, the interest stays",
                        "In my free time I like chess. My sister teaches chess.", chess, .exactly(CVData(interests: ["chess"]))))
        rows.append(row("a-hobby-is-no-skill-though-another-person-has-it-it",
                        "the sister teaches chess; the person only likes it in her free time: the skill goes, the interest stays",
                        "Nel tempo libero mi piacciono gli scacchi. Mia sorella insegna scacchi.",
                        CVData(skills: [Skill(name: "scacchi")], interests: ["scacchi"]), .exactly(CVData(interests: ["scacchi"])),
                        language: "it"))
        rows.append(row("a-hobby-is-no-skill-though-a-shared-subject-has-it",
                        "teaches chess shares the sister as its subject: it is hers, and the person's skill goes",
                        "In my free time I like chess. My sister is a coach and teaches chess.", chess,
                        .exactly(CVData(interests: ["chess"]))))
        rows.append(row("a-skill-of-the-job-stays-though-another-person-has-it-too",
                        "the person's own job clause claims photography; the sister's clause neither keeps nor drops it: the skill stays",
                        "I work as a photographer at Studio Luce, where I do portrait photography. My sister loves photography. "
                            + "In my free time I like photography.",
                        CVData(skills: [Skill(name: "photography")], interests: ["photography"]), .unchanged))
        rows.append(row("a-skill-the-person-claims-stays-though-another-person-likes-it",
                        "the sister's clause of leisure is not the person's; the person coaches chess: the skill stays",
                        "My sister loves chess. I coach chess at the Acme club.", chess, .unchanged))
        rows.append(row("a-denied-mention-claims-no-skill",
                        "I don't play chess claims no ability: the skill goes",
                        "In my free time I don't play chess.", chess, .safe(never: [], absent: ["skills[0].name"])))
        rows.append(row("a-hedged-mention-claims-no-skill",
                        "I almost never play chess claims no ability: the skill goes",
                        "In my free time I like chess, but I almost never play chess.", chess,
                        .safe(never: [], absent: ["skills[0].name"])))
        rows.append(row("a-skill-the-person-can-teach-stays-though-it-is-a-hobby",
                        "I can teach chess claims the ability, can and all: the skill stays",
                        "I can teach chess. In my free time I like chess.", chess, .unchanged))
        rows.append(row("a-skill-the-person-partly-teaches-stays-though-it-is-a-hobby-de",
                        "ich unterrichte teilweise Schach claims the ability, though partly: the skill stays",
                        "Ich unterrichte teilweise Schach. In meiner Freizeit mag ich Schach.",
                        CVData(skills: [Skill(name: "Schach")], interests: ["Schach"]), .unchanged, language: "de"))
        rows.append(row("a-wish-claims-no-skill",
                        "I would like to learn Python claims no ability: the skill goes",
                        "I would like to learn Python.", CVData(skills: [Skill(name: "Python")], interests: ["Python"]),
                        .safe(never: [], absent: ["skills[0].name"])))
        return rows
    }

    // MARK: Every fact is the person's (c)

    /// Languages and their levels, skills, interests, certifications and the person's own fields need a clause that speaks for
    /// the person, or a verbless list ("Languages: Italian (native), French (C2)"). A clause about a sister, a colleague or a
    /// manager gives none of them, and does not hold back what the person's own clauses give.
    private static func everyFactIsThePersons() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        typealias Fact = (language: String, theirs: String, mine: String, value: String)
        func theirs(_ id: String, _ reason: String, _ draft: (Fact) -> CVData, _ facts: [Fact], to rows: inout [GroundingRow]) {
            for v in facts {
                rows.append(row("\(id)-\(v.language)", reason, v.theirs, draft(v), .exactly(CVData()), language: v.language))
            }
        }
        func mine(_ id: String, _ reason: String, _ draft: (Fact) -> CVData, _ facts: [Fact], to rows: inout [GroundingRow]) {
            for v in facts {
                rows.append(row("\(id)-\(v.language)", reason, v.mine, draft(v), .unchanged, language: v.language))
            }
        }

        // Languages and their levels.
        var german: [Fact] = []
        german.append(("en", "My colleague speaks German (B2).", "I speak German (B2).", "German"))
        german.append(("it", "La mia collega parla tedesco (B2).", "Parlo tedesco (B2).", "tedesco"))
        german.append(("de", "Meine Kollegin spricht Deutsch (B2).", "Ich spreche Deutsch (B2).", "Deutsch"))
        german.append(("es", "Mi colega habla alemán (B2).", "Hablo alemán (B2).", "alemán"))
        german.append(("fr", "Ma collègue parle allemand (B2).", "Je parle allemand (B2).", "allemand"))
        german.append(("pt", "Minha colega fala alemão (B2).", "Falo alemão (B2).", "alemão"))
        theirs("a-language-of-someone-else-goes", "the subject is my colleague: the clause speaks for someone else, so no German and no B2",
               { CVData(languages: [Language(name: $0.value, proficiency: .b2)]) }, german, to: &rows)
        mine("a-language-of-the-person-stays", "the same clause with the person as subject: the language and its level stay",
             { CVData(languages: [Language(name: $0.value, proficiency: .b2)]) }, german, to: &rows)

        typealias Pair = (language: String, description: String, value: String)
        var levels: [Pair] = []
        levels.append(("en", "I speak German (A2). My colleague speaks German (B2).", "German"))
        levels.append(("it", "Parlo tedesco (A2). La mia collega parla tedesco (B2).", "tedesco"))
        levels.append(("de", "Ich spreche Deutsch (A2). Meine Kollegin spricht Deutsch (B2).", "Deutsch"))
        levels.append(("es", "Hablo alemán (A2). Mi colega habla alemán (B2).", "alemán"))
        levels.append(("fr", "Je parle allemand (A2). Ma collègue parle allemand (B2).", "allemand"))
        levels.append(("pt", "Falo alemão (A2). Minha colega fala alemão (B2).", "alemão"))
        for v in levels {
            rows.append(row("the-level-of-someone-else-is-not-the-persons-\(v.language)",
                            "the person speaks the language at A2, the colleague at B2: B2 is backed by no clause of the person, so the language goes",
                            v.description, CVData(languages: [Language(name: v.value, proficiency: .b2)]), .exactly(CVData()), language: v.language))
            rows.append(row("the-level-of-the-person-stays-beside-someone-elses-\(v.language)",
                            "the same two clauses: A2 is the person's own, so the language and its level stay",
                            v.description, CVData(languages: [Language(name: v.value, proficiency: .a2)]), .unchanged, language: v.language))
        }

        // Skills.
        var swift: [Fact] = []
        swift.append(("en", "My brother knows Swift.", "I know Swift.", "Swift"))
        swift.append(("it", "Mio fratello conosce Swift.", "Conosco Swift.", "Swift"))
        swift.append(("de", "Mein Bruder kennt Swift.", "Ich kenne Swift.", "Swift"))
        swift.append(("es", "Mi hermano conoce Swift.", "Conozco Swift.", "Swift"))
        swift.append(("fr", "Mon frère connaît Swift.", "Je connais Swift.", "Swift"))
        swift.append(("pt", "Meu irmão conhece Swift.", "Conheço Swift.", "Swift"))
        theirs("a-skill-of-someone-else-goes", "the subject is my brother: the clause speaks for someone else, so no Swift",
               { CVData(skills: [Skill(name: $0.value)]) }, swift, to: &rows)
        mine("a-skill-of-the-person-stays", "the same clause with the person as subject: the skill stays",
             { CVData(skills: [Skill(name: $0.value)]) }, swift, to: &rows)

        // Interests.
        var chess: [Fact] = []
        chess.append(("en", "My wife loves chess.", "I love chess.", "chess"))
        chess.append(("it", "Mia moglie ama gli scacchi.", "Amo gli scacchi.", "scacchi"))
        chess.append(("de", "Meine Frau liebt Schach.", "Ich liebe Schach.", "Schach"))
        chess.append(("es", "Mi esposa ama el ajedrez.", "Amo el ajedrez.", "ajedrez"))
        chess.append(("fr", "Ma femme aime les échecs.", "J'aime les échecs.", "échecs"))
        chess.append(("pt", "Minha esposa ama xadrez.", "Amo xadrez.", "xadrez"))
        theirs("an-interest-of-someone-else-goes", "the subject is my wife: the clause speaks for someone else, so no chess",
               { CVData(interests: [$0.value]) }, chess, to: &rows)
        mine("an-interest-of-the-person-stays", "the same clause with the person as subject: the interest stays",
             { CVData(interests: [$0.value]) }, chess, to: &rows)

        // Certifications.
        var bls: [Fact] = []
        bls.append(("en", "My sister holds a BLS.", "I hold a BLS.", "BLS"))
        bls.append(("it", "Mia sorella ha un BLS.", "Ho un BLS.", "BLS"))
        bls.append(("de", "Meine Schwester hat ein BLS.", "Ich habe ein BLS.", "BLS"))
        bls.append(("es", "Mi hermana tiene un BLS.", "Tengo un BLS.", "BLS"))
        bls.append(("fr", "Ma sœur a un BLS.", "J'ai un BLS.", "BLS"))
        bls.append(("pt", "Minha irmã tem um BLS.", "Tenho um BLS.", "BLS"))
        theirs("a-certification-of-someone-else-goes", "the subject is my sister: the clause speaks for someone else, so no BLS",
               { CVData(certifications: [Certification(name: $0.value)]) }, bls, to: &rows)
        mine("a-certification-of-the-person-stays", "the same clause with the person as subject: the certification stays",
             { CVData(certifications: [Certification(name: $0.value)]) }, bls, to: &rows)

        // The person's own fields.
        var emails: [Fact] = []
        emails.append(("en", "My sister's email is anna@example.com.", "Email: me@example.com", "anna@example.com"))
        emails.append(("it", "La email di mia sorella è anna@example.com.", "Email: me@example.com", "anna@example.com"))
        emails.append(("de", "Die E-Mail meiner Schwester ist anna@example.com.", "E-Mail: me@example.com", "anna@example.com"))
        emails.append(("es", "El correo de mi hermana es anna@example.com.", "Correo: me@example.com", "anna@example.com"))
        emails.append(("fr", "Le courriel de ma sœur est anna@example.com.", "Courriel: me@example.com", "anna@example.com"))
        emails.append(("pt", "O e-mail da minha irmã é anna@example.com.", "E-mail: me@example.com", "anna@example.com"))
        theirs("an-email-of-someone-else-goes", "the email is my sister's: the clause speaks for someone else, so no email",
               { CVData(personalInfo: person(email: $0.value)) }, emails, to: &rows)
        mine("an-email-in-a-verbless-clause-stays", "a verbless clause with no owner speaks for the person: the email stays",
             { _ in CVData(personalInfo: person(email: "me@example.com")) }, emails, to: &rows)

        var cities: [Fact] = []
        cities.append(("en", "My manager lives in Rome.", "I live in Rome.", "Rome"))
        cities.append(("it", "Il mio responsabile vive a Roma.", "Vivo a Roma.", "Roma"))
        cities.append(("de", "Mein Chef wohnt in Rom.", "Ich wohne in Rom.", "Rom"))
        cities.append(("es", "Mi jefe vive en Roma.", "Vivo en Roma.", "Roma"))
        cities.append(("fr", "Mon responsable habite à Rome.", "J'habite à Rome.", "Rome"))
        cities.append(("pt", "Meu chefe mora em Roma.", "Moro em Roma.", "Roma"))
        theirs("a-place-of-someone-else-goes", "the subject is my manager: the clause speaks for someone else, so no Rome",
               { CVData(personalInfo: person(location: $0.value)) }, cities, to: &rows)
        mine("a-place-of-the-person-stays", "the same clause with the person as subject: the place stays",
             { CVData(personalInfo: person(location: $0.value)) }, cities, to: &rows)

        var titles: [Fact] = []
        titles.append(("en", "My sister is a nurse.", "I am a nurse.", "nurse"))
        titles.append(("it", "Mia sorella è infermiera.", "Sono infermiera.", "infermiera"))
        titles.append(("de", "Meine Schwester ist Krankenschwester.", "Ich bin Krankenschwester.", "Krankenschwester"))
        titles.append(("es", "Mi hermana es enfermera.", "Soy enfermera.", "enfermera"))
        titles.append(("fr", "Ma sœur est infirmière.", "Je suis infirmière.", "infirmière"))
        titles.append(("pt", "Minha irmã é enfermeira.", "Sou enfermeira.", "enfermeira"))
        theirs("a-title-of-someone-else-goes", "the subject is my sister: the clause speaks for someone else, so her title is not the person's",
               { CVData(personalInfo: person(title: $0.value)) }, titles, to: &rows)
        mine("a-title-of-the-person-stays", "the same clause with the person as subject: the title stays",
             { CVData(personalInfo: person(title: $0.value)) }, titles, to: &rows)

        // A verbless list speaks for the person.
        typealias Listed = (language: String, languages: String, skills: String)
        var lists: [Listed] = []
        lists.append(("en", "Languages: Italian (native), French (C2).", "Skills: Swift, SwiftUI."))
        lists.append(("it", "Lingue: italiano (madrelingua), francese (C2).", "Competenze: Swift, SwiftUI."))
        lists.append(("de", "Sprachen: Italienisch (Muttersprache), Französisch (C2).", "Kenntnisse: Swift, SwiftUI."))
        lists.append(("es", "Idiomas: italiano (nativo), francés (C2).", "Habilidades: Swift, SwiftUI."))
        lists.append(("fr", "Langues: italien (langue maternelle), français (C2).", "Compétences: Swift, SwiftUI."))
        lists.append(("pt", "Idiomas: italiano (nativo), francês (C2).", "Competências: Swift, SwiftUI."))
        let tongues: [String: (first: String, second: String)] = [
            "en": ("Italian", "French"), "it": ("italiano", "francese"), "de": ("Italienisch", "Französisch"),
            "es": ("italiano", "francés"), "fr": ("italien", "français"), "pt": ("italiano", "francês"),
        ]
        for v in lists {
            let tongue = tongues[v.language] ?? tongues["en"]!
            rows.append(row("a-list-of-languages-stays-\(v.language)",
                            "a verbless list speaks for the person: both languages and their levels stay",
                            v.languages,
                            CVData(languages: [Language(name: tongue.first, proficiency: .native), Language(name: tongue.second, proficiency: .c2)]),
                            .unchanged, language: v.language))
            rows.append(row("a-list-of-skills-stays-\(v.language)",
                            "a verbless list speaks for the person: both skills stay",
                            v.skills, CVData(skills: [Skill(name: "Swift"), Skill(name: "SwiftUI")]), .unchanged, language: v.language))
        }

        // The person's clause and someone else's side by side: the person's stays, the other goes.
        typealias Side = (language: String, languages: String, withLevel: String, skills: String, mine: String, theirs: String)
        var sides: [Side] = []
        sides.append(("en", "I speak Italian; my sister speaks French (C2).", "I speak Italian (native); my sister speaks French (C2).",
                      "I know Swift; my brother knows Kotlin.", "Italian", "French"))
        sides.append(("it", "Parlo italiano; mia sorella parla francese (C2).", "Parlo italiano (madrelingua); mia sorella parla francese (C2).",
                      "Conosco Swift; mio fratello conosce Kotlin.", "italiano", "francese"))
        sides.append(("de", "Ich spreche Italienisch; meine Schwester spricht Französisch (C2).",
                      "Ich spreche Italienisch (Muttersprache); meine Schwester spricht Französisch (C2).",
                      "Ich kenne Swift; mein Bruder kennt Kotlin.", "Italienisch", "Französisch"))
        sides.append(("es", "Hablo italiano; mi hermana habla francés (C2).", "Hablo italiano (nativo); mi hermana habla francés (C2).",
                      "Conozco Swift; mi hermano conoce Kotlin.", "italiano", "francés"))
        sides.append(("fr", "Je parle italien; ma sœur parle français (C2).", "Je parle italien (langue maternelle); ma sœur parle français (C2).",
                      "Je connais Swift; mon frère connaît Kotlin.", "italien", "français"))
        sides.append(("pt", "Falo italiano; minha irmã fala francês (C2).", "Falo italiano (nativo); minha irmã fala francês (C2).",
                      "Conheço Swift; meu irmão conhece Kotlin.", "italiano", "francês"))
        for v in sides {
            rows.append(row("mixed-languages-keep-the-persons-\(v.language)",
                            "the person speaks Italian, the sister French (C2): Italian stays, French and C2 go",
                            v.languages,
                            CVData(languages: [Language(name: v.mine), Language(name: v.theirs, proficiency: .c2)]),
                            .exactly(CVData(languages: [Language(name: v.mine)])), language: v.language))
            rows.append(row("mixed-languages-with-levels-keep-the-persons-\(v.language)",
                            "the person speaks Italian (native), the sister French (C2): Italian and its level stay, French goes",
                            v.withLevel,
                            CVData(languages: [Language(name: v.mine, proficiency: .native), Language(name: v.theirs, proficiency: .c2)]),
                            .exactly(CVData(languages: [Language(name: v.mine, proficiency: .native)])), language: v.language))
            rows.append(row("mixed-skills-keep-the-persons-\(v.language)",
                            "the person knows Swift, the brother Kotlin: Swift stays, Kotlin goes",
                            v.skills,
                            CVData(skills: [Skill(name: "Swift"), Skill(name: "Kotlin")]),
                            .exactly(CVData(skills: [Skill(name: "Swift")])), language: v.language))
        }
        return rows
    }

    // MARK: A year written once backs one date (c)

    private static func oneYearOneDate() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        rows.append(row("one-year-one-date-of-a-job",
                        "2012 is written once: a job keeps it as its start date, not as its end",
                        "I worked as a nurse at Acme in 2012.",
                        CVData(experience: [job("nurse", "Acme", from: "2012", to: "2012")]),
                        .exactly(CVData(experience: [job("nurse", "Acme", from: "2012")]))))
        rows.append(row("one-year-one-date-of-a-study",
                        "2012 is written once: a study keeps it as its end date, not as its start",
                        "I studied Nursing at Alpha University in 2012.",
                        CVData(education: [study("Nursing", at: "Alpha University", from: "2012", to: "2012")]),
                        .exactly(CVData(education: [study("Nursing", at: "Alpha University", to: "2012")]))))
        rows.append(row("one-year-written-twice-backs-two-dates",
                        "2012 is written twice: both dates of the job keep it",
                        "I worked as a nurse at Acme from 2012 to 2012.",
                        CVData(experience: [job("nurse", "Acme", from: "2012", to: "2012")]),
                        .unchanged))
        return rows
    }

    // MARK: Dates of one job stay with it (c)

    private static func datesOfJobs() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        rows.append(row("dates-shared-title",
                        "two nurses: the title backs nothing, so Beta's 2023 and Beta's figure are not Acme's; the figure joins Beta's clause",
                        "I worked as a nurse at Acme from 2012 to 2016. I worked as a nurse at Beta from 2019 to 2023 and trained 3 nurses.",
                        CVData(experience: [job("nurse", "Acme", from: "2012", to: "2023", current: true, description: "Trained 3 nurses.",
                                                achievements: ["Trained 3 nurses"]),
                                            job("nurse", "Beta", from: "2019", to: "2023", achievements: ["Trained 3 nurses"])]),
                        .exactly(CVData(experience: [job("nurse", "Acme", from: "2012"),
                                                     job("nurse", "Beta", from: "2019", to: "2023", achievements: ["Trained 3 nurses"])]))))
        rows.append(row("dates-swapped-between-jobs-with-the-same-title",
                        "the dates of the other nurse are not this nurse's",
                        "I worked as a nurse at Acme from 2012 to 2016. I worked as a nurse at Beta from 2019 to 2023.",
                        CVData(experience: [job("nurse", "Acme", from: "2019", to: "2023"), job("nurse", "Beta", from: "2012", to: "2016")]),
                        .exactly(CVData(experience: [job("nurse", "Acme"), job("nurse", "Beta")]))))
        rows.append(row("dates-two-employers-in-a-sentence",
                        "in a sentence that names two employers each date belongs to the clause it stands in",
                        "I worked at Acme from 2012 to 2016 and at Beta from 2019 to 2023.",
                        CVData(experience: [job("", "Acme", from: "2012", to: "2023"), job("", "Beta", from: "2012", to: "2023")]),
                        .exactly(CVData(experience: [job("", "Acme", from: "2012"), job("", "Beta", to: "2023")]))))
        rows.append(row("dates-of-employers-listed-together",
                        "Acme and Beta share a clause: its dates are neither's",
                        "I worked at Acme and Beta from 2012 to 2019.",
                        CVData(experience: [job("", "Acme", from: "2012", to: "2019")]),
                        .exactly(CVData(experience: [job("", "Acme")]))))
        rows.append(row("dates-of-employers-listed-together-it",
                        "the same in Italian: Acme e Beta share a clause, and its dates are neither's",
                        "Ho lavorato presso Acme e Beta dal 2012 al 2019.",
                        CVData(experience: [job("", "Acme", from: "2012", to: "2019")]),
                        .exactly(CVData(experience: [job("", "Acme")])),
                        language: "it"))
        rows.append(row("dates-of-employers-listed-together-de",
                        "the same in German: Acme und Beta share a clause, and its dates are neither's",
                        "Ich habe bei Acme und Beta von 2012 bis 2019 gearbeitet.",
                        CVData(experience: [job("", "Acme", from: "2012", to: "2019")]),
                        .exactly(CVData(experience: [job("", "Acme")])),
                        language: "de"))
        rows.append(row("dates-in-a-clause-between-two-employers",
                        "a clause of dates next to the clauses of two employers joins neither: the middle years are not Acme's",
                        "At Acme I worked, from 2012 to 2016, and at Beta I worked, from 2019 to 2023.",
                        CVData(experience: [job("", "Acme", from: "2012", to: "2016")]),
                        .exactly(CVData(experience: [job("", "Acme")]))))
        rows.append(row("dates-in-a-clause-between-two-employers-for-beta",
                        "the same for Beta: the middle years are not Beta's",
                        "At Acme I worked, from 2012 to 2016, and at Beta I worked, from 2019 to 2023.",
                        CVData(experience: [job("", "Beta", from: "2012", to: "2016")]),
                        .exactly(CVData(experience: [job("", "Beta")]))))
        rows.append(row("dates-in-a-clause-beyond-another-employer",
                        "the years after Beta's clause stand next to Beta's, not to Acme's, and the middle years are nobody's",
                        "At Acme I worked, from 2012 to 2016, and at Beta I worked, from 2019 to 2023.",
                        CVData(experience: [job("", "Acme", from: "2012", to: "2023")]),
                        .exactly(CVData(experience: [job("", "Acme")]))))
        rows.append(row("dates-in-a-clause-next-to-one-employer",
                        "the years after Beta's clause stand next to Beta's alone: they join it",
                        "At Acme I worked, from 2012 to 2016, and at Beta I worked, from 2019 to 2023.",
                        CVData(experience: [job("", "Beta", from: "2019", to: "2023")]),
                        .unchanged))
        return rows
    }

    // MARK: A job left out of the draft cannot lend its facts (c)

    /// The facts of the omitted employer are Beta's, however the sentence names Beta. Words that the closed vocabulary
    /// surely holds (worked, for, years) keep what stays exact. A value the model writes that quotes Beta (a location, an
    /// achievement) does not make Beta's clause Acme's: Beta stays another employer.
    private static func omittedEmployers() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        let acme = job("", "Acme", from: "2012", to: "2019", current: true, description: "Worked for 5 years.",
                       achievements: ["Worked for 3 years", "Worked for 5 years"])
        // "Worked for 3 years" leaves out the start of its clause (At Acme in 2012 I): it is no quote, and the draft's own
        // achievement goes with the foreign one.
        let ownFacts = CVData(experience: [job("", "Acme", from: "2012")])

        rows.append(row("omitted-employer-after-a-conjunction",
                        "Beta's 2019 and 5 years are not Acme's when the draft leaves Beta out",
                        "At Acme in 2012 I worked for 3 years and at Beta in 2019 I worked for 5 years.",
                        CVData(experience: [acme]), .exactly(ownFacts)))
        rows.append(row("omitted-employer-figures-without-dates",
                        "the same for a figure with no date: Beta's 5 years are not Acme's",
                        "At Acme I worked for 3 years and at Beta I worked for 5 years.",
                        CVData(experience: [job("", "Acme", achievements: ["Worked for 3 years", "Worked for 5 years"])]),
                        .exactly(CVData(experience: [job("", "Acme")]))))
        rows.append(row("omitted-employer-own-achievement-quoted",
                        "the whole clause of Acme is a quote and stays; Beta's 5 years are not Acme's",
                        "At Acme I worked for 3 years and at Beta I worked for 5 years.",
                        CVData(experience: [job("", "Acme", achievements: ["At Acme I worked for 3 years", "Worked for 5 years"])]),
                        .exactly(CVData(experience: [job("", "Acme", achievements: ["At Acme I worked for 3 years"])]))))
        rows.append(row("omitted-employer-with-no-preposition",
                        "Beta employed me names an employer without at or for",
                        "At Acme in 2012 I worked for 3 years and Beta employed me in 2019 for 5 years.",
                        CVData(experience: [acme]), .exactly(ownFacts)))
        rows.append(row("omitted-employer-in-lower-case",
                        "beta in lower case is an employer as well",
                        "At Acme in 2012 I worked for 3 years and beta employed me in 2019 for 5 years.",
                        CVData(experience: [acme]), .exactly(ownFacts)))
        rows.append(row("omitted-employer-first-word-of-a-sentence",
                        "a sentence that starts with Beta is Beta's",
                        "Beta employed me in 2019 for 5 years. At Acme I worked for 3 years in 2012.",
                        CVData(experience: [acme]), .exactly(ownFacts)))
        rows.append(row("omitted-employer-clause-quoted-by-the-draft",
                        "a draft that quotes Beta's clause in an achievement does not make the clause Acme's: Beta is another employer",
                        "At Acme in 2012 I worked for 3 years and at Beta in 2019 I worked for 5 years.",
                        CVData(experience: [job("", "Acme", from: "2012", to: "2019", achievements: ["at Beta in 2019 I worked for 5 years"])]),
                        .exactly(CVData(experience: [job("", "Acme", from: "2012")]))))
        rows.append(row("omitted-employer-location-of-the-job",
                        "a job location Beta, given by the model, does not hide Beta as an employer",
                        "At Acme in 2012 I worked for 3 years and at Beta in 2019 I worked for 5 years.",
                        CVData(experience: [job("", "Acme", from: "2012", to: "2019", location: "Beta")]),
                        .exactly(CVData(experience: [job("", "Acme", from: "2012")]))))
        rows.append(row("omitted-employer-location-of-the-person",
                        "a person location Beta, given by the model, does not hide Beta as an employer (Beta is a quote)",
                        "At Acme in 2012 I worked for 3 years and at Beta in 2019 I worked for 5 years.",
                        CVData(personalInfo: person(location: "Beta"), experience: [job("", "Acme", from: "2012", to: "2019")]),
                        .exactly(CVData(personalInfo: person(location: "Beta"), experience: [job("", "Acme", from: "2012")]))))

        let longer = CVData(experience: [job("", "Acme", from: "2012", to: "2019", current: true)])
        rows.append(row("omitted-longer-name",
                        "Acme is not Acme Labs: the clause of Acme Labs, which the draft leaves out, is not Acme's",
                        "I worked at Acme in 2012. I work at Acme Labs since 2019.",
                        longer, .exactly(CVData(experience: [job("", "Acme", from: "2012")]))))
        rows.append(row("omitted-longer-name-in-lower-case",
                        "the same when the longer name is written in lower case",
                        "I worked at acme in 2012. I work at acme labs since 2019.",
                        CVData(experience: [job("", "acme", from: "2012", to: "2019", current: true)]),
                        .exactly(CVData(experience: [job("", "acme", from: "2012")]))))
        rows.append(row("longer-name-in-the-draft",
                        "with Acme Labs in the draft, each of the two keeps only its own clause",
                        "I worked at Acme in 2012. I work at Acme Labs since 2019.",
                        CVData(experience: [job("", "Acme", from: "2012", to: "2019", current: true), job("", "Acme Labs", from: "2012", current: true)]),
                        .exactly(CVData(experience: [job("", "Acme", from: "2012"), job("", "Acme Labs", current: true)]))))
        return rows
    }

    /// The same finding in the six languages, in words that the ADR leaves to its lists: only what must not be there is
    /// asserted. Beta's year and Beta's figure are never Acme's, and Acme is not current.
    private static func omittedEmployersInManyWords() -> [GroundingRow] {
        typealias Variant = (id: String, language: String, description: String, own: String, foreign: String, figure: String)
        var variants: [Variant] = []

        variants.append(("en", "en", "At Acme in 2012 I trained 3 nurses and at Beta in 2019 I trained 5 nurses.",
                         "Trained 3 nurses", "Trained 5 nurses", "5"))
        variants.append(("it", "it", "Presso Acme nel 2012 ho formato 3 infermieri e presso Beta nel 2019 ho formato 5 infermieri.",
                         "Formati 3 infermieri", "Formati 5 infermieri", "5"))
        variants.append(("de", "de", "Bei Acme habe ich 2012 3 Pflegekräfte eingearbeitet und bei Beta habe ich 2019 5 Pflegekräfte eingearbeitet.",
                         "3 Pflegekräfte eingearbeitet", "5 Pflegekräfte eingearbeitet", "5"))
        variants.append(("es", "es", "En Acme en 2012 formé a 3 enfermeras y en Beta en 2019 formé a 5 enfermeras.",
                         "Formé a 3 enfermeras", "Formé a 5 enfermeras", "5"))
        variants.append(("fr", "fr", "Chez Acme en 2012 j'ai formé 3 infirmières et chez Beta en 2019 j'ai formé 5 infirmières.",
                         "Formé 3 infirmières", "Formé 5 infirmières", "5"))
        variants.append(("pt", "pt", "Na Acme em 2012 formei 3 enfermeiras e na Beta em 2019 formei 5 enfermeiras.",
                         "Formei 3 enfermeiras", "Formei 5 enfermeiras", "5"))

        variants.append(("employed-en", "en", "At Acme in 2012 I trained 3 nurses and Beta employed me in 2019 to train 5 nurses.",
                         "Trained 3 nurses", "Trained 5 nurses", "5"))
        variants.append(("employed-it", "it", "Presso Acme nel 2012 ho formato 3 infermieri e Beta mi ha assunta nel 2019 per formare 5 infermieri.",
                         "Formati 3 infermieri", "Formati 5 infermieri", "5"))
        variants.append(("employed-de", "de",
                         "Bei Acme habe ich 2012 3 Pflegekräfte eingearbeitet und Beta hat mich 2019 eingestellt, um 5 Pflegekräfte auszubilden.",
                         "3 Pflegekräfte eingearbeitet", "5 Pflegekräfte eingearbeitet", "5"))
        variants.append(("employed-es", "es", "En Acme en 2012 formé a 3 enfermeras y Beta me contrató en 2019 para formar a 5 enfermeras.",
                         "Formé a 3 enfermeras", "Formé a 5 enfermeras", "5"))
        variants.append(("employed-fr", "fr", "Chez Acme en 2012 j'ai formé 3 infirmières et Beta m'a embauchée en 2019 pour former 5 infirmières.",
                         "Formé 3 infirmières", "Formé 5 infirmières", "5"))
        variants.append(("employed-pt", "pt", "Na Acme em 2012 formei 3 enfermeiras e a Beta me contratou em 2019 para formar 5 enfermeiras.",
                         "Formei 3 enfermeiras", "Formei 5 enfermeiras", "5"))

        variants.append(("first-word-en", "en", "Beta trained 9 nurses in 2019. At Acme I trained 3 nurses in 2012.",
                         "Trained 3 nurses", "Trained 9 nurses", "9"))
        variants.append(("first-word-it", "it", "Beta ha formato 9 infermieri nel 2019. Presso Acme ho formato 3 infermieri nel 2012.",
                         "Formati 3 infermieri", "Formati 9 infermieri", "9"))
        variants.append(("first-word-de", "de", "Beta hat 2019 9 Pflegekräfte ausgebildet. Bei Acme habe ich 2012 3 Pflegekräfte eingearbeitet.",
                         "3 Pflegekräfte eingearbeitet", "9 Pflegekräfte ausgebildet", "9"))

        variants.append(("lower-case-en", "en", "At Acme in 2012 I trained 3 nurses and beta employed me in 2019 to train 9 nurses.",
                         "Trained 3 nurses", "Trained 9 nurses", "9"))
        variants.append(("lower-case-it", "it", "Presso Acme nel 2012 ho formato 3 infermieri e beta mi ha assunta nel 2019 per formare 9 infermieri.",
                         "Formati 3 infermieri", "Formati 9 infermieri", "9"))
        variants.append(("lower-case-de", "de",
                         "Bei Acme habe ich 2012 3 Pflegekräfte eingearbeitet und beta hat mich 2019 eingestellt, um 9 Pflegekräfte auszubilden.",
                         "3 Pflegekräfte eingearbeitet", "9 Pflegekräfte ausgebildet", "9"))

        return variants.map { variant in
            let acme = job("", "Acme", from: "2012", to: "2019", current: true, description: variant.foreign + ".",
                           achievements: [variant.own, variant.foreign])
            return row("omitted-employer-\(variant.id)",
                       "the year and the figure of the employer the draft leaves out are not Acme's (\(variant.language))",
                       variant.description, CVData(experience: [acme]),
                       .safe(never: ["2019", variant.figure], absent: ["experience[0].current"], keeping: ["experience[0].company": "Acme"]),
                       language: variant.language)
        }
    }

    // MARK: A title or a degree is the entry's own

    /// ADR 0023 makes a title a quote and says no more. A title the description gives for another job is a quote too, and
    /// moves a fact between two jobs: the rows expect it to go.
    private static func titlesOfOthers() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        rows.append(row("title-of-another-job",
                        "head nurse is Beta's title; the description says Acme's was cook",
                        "I was head nurse at Beta in 2019. I was a cook at Acme in 2012.",
                        CVData(experience: [job("head nurse", "Acme")]),
                        .exactly(CVData(experience: [job("", "Acme")]))))
        rows.append(row("title-of-another-job-both-drafted",
                        "with both jobs in the draft, head nurse stays with Beta and goes from Acme",
                        "I was head nurse at Beta in 2019. I was a cook at Acme in 2012.",
                        CVData(experience: [job("head nurse", "Acme"), job("head nurse", "Beta")]),
                        .exactly(CVData(experience: [job("", "Acme"), job("head nurse", "Beta")]))))
        rows.append(row("degree-of-another-school",
                        "Law is the degree of Beta University; the description says Alpha University gave Nursing",
                        "I studied Nursing at Alpha University in 2010. I studied Law at Beta University in 2015.",
                        CVData(education: [study("Law", at: "Alpha University")]),
                        .exactly(CVData(education: [study(at: "Alpha University")]))))
        return rows
    }

    // MARK: An employer or a school keeps no leading indefinite article (#202)

    /// The model copies the article of "in a nursery" into the employer: a CV names the place, so a leading indefinite article goes,
    /// in each language, and what is left is the same quote without it. An article written with a capital is part of a name ("UNA
    /// Hotels", "A Plus Consulting"), and a name that is no quote stays no quote.
    private static func entryNamesWithoutAnArticle() -> [GroundingRow] {
        typealias Variant = (id: String, language: String, description: String, written: String, kept: String)
        var variants: [Variant] = []
        variants.append(("a-en", "en", "I worked as an assistant in a nursery.", "a nursery", "nursery"))
        variants.append(("an-en", "en", "I worked at an orphanage.", "an orphanage", "orphanage"))
        variants.append(("un-it", "it", "Ho lavorato come assistente in un asilo nido.", "un asilo nido", "asilo nido"))
        variants.append(("una-it", "it", "Ho lavorato in una scuola.", "una scuola", "scuola"))
        variants.append(("uno-it", "it", "Ho lavorato in uno studio legale.", "uno studio legale", "studio legale"))
        variants.append(("un-elided-it", "it", "Ho lavorato in un'azienda agricola.", "un'azienda agricola", "azienda agricola"))
        variants.append(("einer-de", "de", "Ich habe in einer Kinderkrippe gearbeitet.", "einer Kinderkrippe", "Kinderkrippe"))
        variants.append(("einem-de", "de", "Ich habe in einem Krankenhaus gearbeitet.", "einem Krankenhaus", "Krankenhaus"))
        variants.append(("ein-de", "de", "Ich habe für ein Pflegeheim gearbeitet.", "ein Pflegeheim", "Pflegeheim"))
        variants.append(("una-es", "es", "Trabajé como auxiliar en una guardería.", "una guardería", "guardería"))
        variants.append(("un-es", "es", "Trabajé en un hospital.", "un hospital", "hospital"))
        variants.append(("une-fr", "fr", "J'ai travaillé comme assistante dans une crèche.", "une crèche", "crèche"))
        variants.append(("un-fr", "fr", "J'ai travaillé dans un hôpital.", "un hôpital", "hôpital"))
        variants.append(("uma-pt", "pt", "Trabalhei como auxiliar em uma creche.", "uma creche", "creche"))
        variants.append(("um-pt", "pt", "Trabalhei em um hospital.", "um hospital", "hospital"))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("an-employer-keeps-no-leading-article-\(v.id)", "the article of the employer goes; the rest is the same quote",
                            v.description, CVData(experience: [job("", v.written)]), .exactly(CVData(experience: [job("", v.kept)])),
                            language: v.language))
        }
        rows.append(row("a-school-keeps-no-leading-article-en", "the article of the school goes; the degree and the rest of the school stay",
                        "I studied Nursing at a community college.", CVData(education: [study("Nursing", at: "a community college")]),
                        .exactly(CVData(education: [study("Nursing", at: "community college")]))))
        rows.append(row("a-school-keeps-no-leading-article-it", "the article of the school goes; the degree and the rest of the school stay",
                        "Ho studiato Ragioneria in un istituto tecnico.", CVData(education: [study("Ragioneria", at: "un istituto tecnico")]),
                        .exactly(CVData(education: [study("Ragioneria", at: "istituto tecnico")])), language: "it"))
        rows.append(row("a-capitalised-article-is-part-of-a-name-it", "UNA Hotels is a name: its article stays",
                        "Dal 2016 lavoro presso UNA Hotels.", CVData(experience: [job("", "UNA Hotels", from: "2016", current: true)]),
                        .unchanged, language: "it"))
        rows.append(row("a-capitalised-article-is-part-of-a-name-en", "A Plus Consulting is a name: its article stays",
                        "Since 2016 I have worked at A Plus Consulting.",
                        CVData(experience: [job("", "A Plus Consulting", from: "2016", current: true)]), .unchanged))
        rows.append(row("an-employer-that-is-no-quote-stays-no-quote", "the description says the nursery: a nursery is no quote, and nursery is not made one",
                        "I worked at the nursery.", CVData(experience: [job("", "a nursery")]), .exactly(CVData())))
        return rows
    }

    // MARK: A degree that only says graduating names no degree (#202)

    /// "diplôme", "Abschluss", "laurea" or "my degree" alone say that the person graduated, not in what: the degree goes, and the
    /// school stays. A degree with its field of study stays.
    private static func degreesThatNameNoDegree() -> [GroundingRow] {
        typealias Variant = (language: String, description: String, degree: String, school: String)
        var variants: [Variant] = []
        variants.append(("en", "I got my degree at the University of Bologna.", "degree", "University of Bologna"))
        variants.append(("it", "Ho una laurea all'Università di Bologna.", "laurea", "Università di Bologna"))
        variants.append(("de", AppExample.de, "Abschluss", "Universität Bologna"))
        variants.append(("es", "Obtuve mi título en la Universidad de Bolonia.", "título", "Universidad de Bolonia"))
        variants.append(("fr", AppExample.fr, "diplôme", "université de Bologne"))
        variants.append(("pt", "Recebi o meu diploma na Universidade de Bolonha.", "diploma", "Universidade de Bolonha"))

        var rows: [GroundingRow] = []
        for v in variants {
            rows.append(row("a-word-for-graduating-names-no-degree-\(v.language)", "the degree only says graduating: it goes, and the school stays",
                            v.description, CVData(education: [study(v.degree, at: v.school)]),
                            .exactly(CVData(education: [study(at: v.school)])), language: v.language))
        }
        rows.append(row("a-degree-with-its-field-stays-it", "laurea in Scienze della Formazione names its field: it stays",
                        "Ho una laurea in Scienze della Formazione all'Università di Bologna.",
                        CVData(education: [study("laurea in Scienze della Formazione", at: "Università di Bologna")]), .unchanged, language: "it"))
        rows.append(row("a-word-for-graduating-without-a-school-leaves-nothing-it", "the degree only says graduating, and there is no school: the study goes",
                        "Ho la laurea.", CVData(education: [study("laurea")]), .exactly(CVData()), language: "it"))
        return rows
    }

    // MARK: Schools and certifications follow the clauses of their own name

    /// ADR 0023 words its clause rule for jobs. The sanitiser applies it to schools and certifications as well, and a
    /// date or an issuer moving between two of them is the same defect.
    private static func schoolsAndCertifications() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        let certificates = "I have a BLS from the Italian Resuscitation Council in 2023 and a PALS from the American Heart Association in 2019."

        rows.append(row("school-omitted-school-lends-its-dates",
                        "Beta University's 2014 is not Alpha University's when the draft leaves Beta out",
                        "At Alpha University in 2010 I graduated and at Beta University in 2014 I did a master.",
                        CVData(education: [study(at: "Alpha University", from: "2010", to: "2014")]),
                        .exactly(CVData(education: [study(at: "Alpha University", from: "2010")]))))
        rows.append(row("school-joined-clause-after",
                        "graduated in 2012 is a graduation phrase: it joins the clause of the school next to it and gives the degree its year",
                        "I studied Education Sciences at the University of Bologna and graduated in 2012.",
                        CVData(education: [study("Education Sciences", at: "University of Bologna", to: "2012")]),
                        .unchanged))
        rows.append(row("school-joined-time-phrase-after",
                        "until 2012 is a pure time phrase: it joins the clause of the school next to it and gives the year",
                        "I studied Education Sciences at the University of Bologna, until 2012.",
                        CVData(education: [study("Education Sciences", at: "University of Bologna", to: "2012")]),
                        .unchanged))
        rows.append(row("school-neighbour-with-an-unexplained-word",
                        "won a prize in 2014 holds the word prize, which nothing explains: it joins nothing",
                        "I studied Nursing at Alpha University and won a prize in 2014.",
                        CVData(education: [study("Nursing", at: "Alpha University", to: "2014")]),
                        .exactly(CVData(education: [study("Nursing", at: "Alpha University")]))))
        rows.append(row("certification-joined-clause-after",
                        "in 2023 names no certification, but joins the clause of the BLS next to it: the date stays",
                        "I have a BLS from the Italian Resuscitation Council, in 2023.",
                        CVData(certifications: [Certification(name: "BLS", issuer: "Italian Resuscitation Council", date: "2023")]),
                        .unchanged))
        rows.append(row("certification-own-issuer-and-date",
                        "the issuer and the date in the clause of the certification stay",
                        certificates,
                        CVData(certifications: [Certification(name: "BLS", issuer: "Italian Resuscitation Council", date: "2023")]),
                        .unchanged))
        rows.append(row("certification-issuer-and-date-of-another",
                        "the issuer and the date of the PALS are not the BLS's, whether or not the draft has the PALS",
                        certificates,
                        CVData(certifications: [Certification(name: "BLS", issuer: "American Heart Association", date: "2019")]),
                        .exactly(CVData(certifications: [Certification(name: "BLS")]))))
        return rows
    }

    // MARK: The app's example description, six languages, with a faithful draft

    /// A draft that quotes the example as a good model would. ADR 0023 keeps all of it but the second sentence of the
    /// summary, which holds a number (a summary holds none). In particular:
    /// - the title of the first job, which is a quote, though it stands only in the sentence about the person;
    /// - the years of the jobs, though they stand in clauses of their own between commas ("Before that, from 2012 to 2016,
    ///   I...", "Depuis 2016,"): such a clause joins the clause that names the employer;
    /// - the 3 new teachers, which stand in the clause after the comma: the draft quotes them, so the clause joins;
    /// The year of the degree ("and graduated in 2012") stays: a graduation phrase is a pure time phrase with words of
    /// graduating, and it joins an education entry and gives it its end date.
    /// - the achievement quote begins with a CV verb and has no employer preposition ("a" of the Spanish "formé a 3
    ///   nuevos maestros" is not one). The German quote cannot begin with its verb, which stands last: it explains nothing,
    ///   and the German draft loses its achievement.
    private static func faithfulExample(
        _ language: String, summary: (kept: String, dropped: String), schoolJob: Experience, nurseryJob: Experience,
        degree: Education, person: PersonalInfo, languages: [Language], interests: [String], drops: [Drop] = [],
        summaryIsAQuote: Bool = true
    ) -> GroundingRow {
        let draft = CVData(personalInfo: person, summary: summary.kept + " " + summary.dropped, experience: [schoolJob, nurseryJob],
                           education: [degree], languages: languages, interests: interests)
        let summaryOutcome = summaryIsAQuote
            ? (drops: drops, rewrites: [Rewrite("summary", to: summary.kept, "a summary holds no number: its second sentence goes")])
            : (drops: drops + [Drop("summary", "its first sentence leaves out the a that starts its clause: no quote; the second holds a number")],
               rewrites: [Rewrite]())
        return row("example-\(language)",
                   "a faithful draft keeps names, titles, years, languages, interests and the clauses it quotes; the prose that is no quote goes",
                   AppExample.text(in: language), draft, .keeping(summaryOutcome.drops, rewriting: summaryOutcome.rewrites),
                   kind: .faithful, language: language)
    }

    private static func faithfulExamples() -> [GroundingRow] {
        var rows: [GroundingRow] = []

        let enSchoolJob = job("primary school teacher", "Don Milani school", from: "2016", current: true,
                              description: "Taught at the Don Milani school.", achievements: ["Trained 3 new teachers"])
        let enNurseryJob = job("assistant", "nursery", from: "2012", to: "2016", description: "Worked as an assistant in a nursery.")
        rows.append(faithfulExample(
            "en", summary: ("Primary school teacher from Bologna.", "Taught at the Don Milani school since 2016."),
            schoolJob: enSchoolJob, nurseryJob: enNurseryJob,
            degree: study("Education Sciences", at: "University of Bologna", to: "2012"),
            person: person(name: "Maria Rossi", location: "Bologna", title: "primary school teacher"),
            languages: [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .b2)],
            interests: ["chess", "hiking"],
            drops: [Drop("experience[0].description", "the role text leaves out since 2016 (I have), which start its clause: it is no quote")],
            summaryIsAQuote: false))

        let itSchoolJob = job("insegnante di scuola primaria", "scuola Don Milani", from: "2016", current: true,
                              description: "Insegno alla scuola Don Milani.", achievements: ["Ho formato 3 nuovi insegnanti"])
        let itNurseryJob = job("assistente", "asilo nido", from: "2012", to: "2016", description: "Ho lavorato come assistente in un asilo nido.")
        rows.append(faithfulExample(
            "it", summary: ("Insegnante di scuola primaria a Bologna.", "Ho formato 3 nuovi insegnanti."),
            schoolJob: itSchoolJob, nurseryJob: itNurseryJob,
            degree: study("Scienze della Formazione", at: "Università di Bologna", to: "2012"),
            person: person(name: "Maria Rossi", location: "Bologna", title: "insegnante di scuola primaria"),
            languages: [Language(name: "italiano", proficiency: .native), Language(name: "inglese", proficiency: .b2)],
            interests: ["scacchi", "escursioni"],
            drops: [Drop("experience[0].description", "the role text leaves out dal 2016, which starts its clause: it is no quote")]))

        let deSchoolJob = job("Grundschullehrerin", "Schule Don Milani", from: "2016", current: true,
                              description: "Ich unterrichte an der Schule Don Milani.", achievements: ["3 neue Lehrkräfte eingearbeitet"])
        let deNurseryJob = job("Betreuerin", "Kinderkrippe", from: "2012", to: "2016",
                               description: "Ich habe als Betreuerin in einer Kinderkrippe gearbeitet.")
        rows.append(faithfulExample(
            "de", summary: ("Grundschullehrerin aus Bologna.", "Ich habe 3 neue Lehrkräfte eingearbeitet."),
            schoolJob: deSchoolJob, nurseryJob: deNurseryJob,
            degree: study("Erziehungswissenschaften", at: "Universität Bologna", to: "2012"),
            person: person(name: "Maria Rossi", location: "Bologna", title: "Grundschullehrerin"),
            languages: [Language(name: "Italienisch", proficiency: .native), Language(name: "Englisch", proficiency: .b2)],
            interests: ["Schach", "Wandern"],
            drops: [Drop("experience[0].achievements[0]", "the German quote begins with a number, not with a CV verb: it explains nothing"),
                    Drop("experience[0].description", "the role text puts ich after the verb and leaves out seit 2016: it is no quote"),
                    Drop("experience[1].description", "the role text leaves out davor habe ich von 2012 bis 2016 and reorders the rest: no quote")]))

        let esSchoolJob = job("maestra de primaria", "escuela Don Milani", from: "2016", current: true,
                              description: "Enseño en la escuela Don Milani.", achievements: ["Formé a 3 nuevos maestros"])
        let esNurseryJob = job("auxiliar", "guardería", from: "2012", to: "2016", description: "Trabajé como auxiliar en una guardería.")
        rows.append(faithfulExample(
            "es", summary: ("Maestra de primaria en Bolonia.", "Formé a 3 nuevos maestros."),
            schoolJob: esSchoolJob, nurseryJob: esNurseryJob,
            degree: study("Ciencias de la Educación", at: "Universidad de Bolonia", to: "2012"),
            person: person(name: "Maria Rossi", location: "Bolonia", title: "maestra de primaria"),
            languages: [Language(name: "italiano", proficiency: .native), Language(name: "inglés", proficiency: .b2)],
            interests: ["ajedrez", "senderismo"],
            drops: [Drop("experience[0].description", "the role text leaves out desde 2016, which starts its clause: it is no quote")]))

        let frSchoolJob = job("institutrice", "école Don Milani", from: "2016", current: true,
                              description: "J'enseigne à l'école Don Milani.", achievements: ["formé 3 nouveaux enseignants"])
        let frNurseryJob = job("assistante", "crèche", from: "2012", to: "2016", description: "J'ai travaillé comme assistante dans une crèche.")
        rows.append(faithfulExample(
            "fr", summary: ("Institutrice dans une école primaire de Bologne.", "J'ai formé 3 nouveaux enseignants."),
            schoolJob: frSchoolJob, nurseryJob: frNurseryJob,
            degree: study("sciences de l'éducation", at: "université de Bologne", to: "2012"),
            person: person(name: "Maria Rossi", location: "Bologne", title: "institutrice"),
            languages: [Language(name: "italien", proficiency: .native), Language(name: "anglais", proficiency: .b2)],
            interests: ["échecs", "randonnée"]))

        let ptSchoolJob = job("professora do ensino fundamental", "escola Don Milani", from: "2016", current: true,
                              description: "Leciono na escola Don Milani.", achievements: ["Formei 3 novos professores"])
        let ptNurseryJob = job("auxiliar", "creche", from: "2012", to: "2016", description: "Trabalhei como auxiliar em uma creche.")
        rows.append(faithfulExample(
            "pt", summary: ("Professora do ensino fundamental em Bolonha.", "Formei 3 novos professores."),
            schoolJob: ptSchoolJob, nurseryJob: ptNurseryJob,
            degree: study("Ciências da Educação", at: "Universidade de Bolonha", to: "2012"),
            person: person(name: "Maria Rossi", location: "Bolonha", title: "professora do ensino fundamental"),
            languages: [Language(name: "italiano", proficiency: .native), Language(name: "inglês", proficiency: .b2)],
            interests: ["xadrez", "caminhadas"],
            drops: [Drop("experience[0].description", "the role text leaves out desde 2016, which starts its clause: it is no quote")]))
        return rows
    }

    // MARK: A verbless contact leans on explained clauses (b)

    /// Every verbless clause that a verbless contact leans on, before it in its sentence or in the sentence before it, is explained:
    /// contact or field words, numbers, function or time words, or the person's own quotes. A bare name is none: "Anna Verdi. Email:
    /// anna@example.com" gives no email, with no draft name, with the draft name Maria Rossi, and after "I'm Maria Rossi.".
    private static func bareNamesBeforeAVerblessContact() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        typealias Language = (code: String, email: String, phone: String, person: String)
        var languages: [Language] = []
        languages.append(("en", "Email:", "Phone:", "I'm Maria Rossi."))
        languages.append(("it", "Email:", "Telefono:", "Sono Maria Rossi."))
        languages.append(("de", "E-Mail:", "Telefon:", "Ich bin Maria Rossi."))
        languages.append(("es", "Correo:", "Teléfono:", "Soy Maria Rossi."))
        languages.append(("fr", "Courriel :", "Téléphone :", "Je suis Maria Rossi."))
        languages.append(("pt", "E-mail:", "Telefone:", "Sou Maria Rossi."))

        let email = "anna@example.com", phone = "+39 333 123 4567", link = "linkedin.com/in/anna-verdi"
        typealias Shape = (id: String, text: (Language) -> String, info: PersonalInfo, isWordless: Bool)
        var shapes: [Shape] = []
        shapes.append(("a-bare-name-before-a-label-in-its-sentence-gives-no-email", { "Anna Verdi; \($0.email) \(email)." }, person(email: email), false))
        shapes.append(("a-bare-name-before-a-label-in-its-sentence-gives-no-phone", { "Anna Verdi; \($0.phone) \(phone)." }, person(phone: phone), false))
        shapes.append(("a-bare-name-before-a-label-in-its-sentence-gives-no-link", { _ in "Anna Verdi; LinkedIn: \(link)." }, person(linkedin: link), true))
        shapes.append(("a-bare-name-sentence-before-a-label-gives-no-email", { "Anna Verdi. \($0.email) \(email)." }, person(email: email), false))
        shapes.append(("a-bare-name-sentence-before-an-address-gives-no-email", { _ in "Anna Verdi. \(email)" }, person(email: email), true))

        func withName(_ info: PersonalInfo) -> PersonalInfo {
            PersonalInfo(name: "Maria Rossi", email: info.email, phone: info.phone, linkedin: info.linkedin)
        }
        for v in languages {
            for shape in shapes {
                // A text with no word of a language reads the same in all six: it runs once, in English.
                if !shape.isWordless || v.code == "en" {
                    let suffix = shape.isWordless ? "" : "-\(v.code)"
                    rows.append(row("\(shape.id)\(suffix)", "the contact leans on a bare name, which nothing explains: it is not the person's",
                                    shape.text(v), CVData(personalInfo: shape.info), .exactly(CVData()), language: v.code))
                    rows.append(row("\(shape.id)-with-a-draft-name\(suffix)",
                                    "the draft names Maria Rossi, whom the description does not name, and the contact leans on a bare name: nothing stays",
                                    shape.text(v), CVData(personalInfo: withName(shape.info)), .exactly(CVData()), language: v.code))
                }
                rows.append(row("\(shape.id)-after-the-person-\(v.code)",
                                "the person is Maria Rossi, and the contact leans on another bare name: her name stays, the contact goes",
                                "\(v.person) \(shape.text(v))", CVData(personalInfo: withName(shape.info)),
                                .exactly(CVData(personalInfo: person(name: "Maria Rossi"))), language: v.code))
            }

            // Control: the person's own name before the label.
            rows.append(row("a-name-of-the-person-before-a-label-keeps-the-email-\(v.code)",
                            "the clause before the label is the person's own name: the name and the email stay",
                            "Maria Rossi; \(v.email) me@example.com.", CVData(personalInfo: person(name: "Maria Rossi", email: "me@example.com")),
                            .unchanged, language: v.code))
        }
        return rows
    }

    // MARK: A fragment before a verbless contact names no one else (b)

    /// A verbless fragment after a clause with a verb belongs to that clause, and may hold the person's own words ("I'm Anna Verdi, a
    /// nurse in Turin."). A capitalised word in it, not the first of its sentence, must be a quote of the draft that the description
    /// backs, or a contact or field word: "I'm Maria Rossi, a friend of Anna Verdi. Email: anna@example.com." names someone else.
    private static func namesInAFragmentBeforeAContact() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        typealias Language = (code: String, person: String, label: String, friend: String, colleague: String, assistant: String)
        var languages: [Language] = []
        languages.append(("en", "I'm Maria Rossi,", "Email:", "a friend of", "a colleague of", "the assistant of"))
        languages.append(("it", "Sono Maria Rossi,", "Email:", "un'amica di", "una collega di", "l'assistente di"))
        languages.append(("de", "Ich bin Maria Rossi,", "E-Mail:", "eine Freundin von", "eine Kollegin von", "die Assistentin von"))
        languages.append(("es", "Soy Maria Rossi,", "Correo:", "una amiga de", "una colega de", "la asistente de"))
        languages.append(("fr", "Je suis Maria Rossi,", "Courriel :", "une amie d'", "une collègue d'", "l'assistante d'"))
        languages.append(("pt", "Sou Maria Rossi,", "E-mail:", "uma amiga de", "uma colega de", "a assistente de"))

        let email = "anna@example.com"
        for v in languages {
            let relations = [("a-friend-of-a-named-person", v.friend), ("a-colleague-of-a-named-person", v.colleague),
                             ("the-assistant-of-a-named-person", v.assistant)]
            for (id, relation) in relations {
                let joiner = relation.hasSuffix("'") ? "" : " "
                rows.append(row("\(id)-gives-no-email-\(v.code)",
                                "the fragment after the person's clause names Anna Verdi, whom the draft does not quote: her name stays, the email goes",
                                "\(v.person) \(relation)\(joiner)Anna Verdi. \(v.label) \(email).",
                                CVData(personalInfo: person(name: "Maria Rossi", email: email)),
                                .exactly(CVData(personalInfo: person(name: "Maria Rossi"))), language: v.code))
            }
        }

        // Residual risks (ADR 0023, Consequences; see `residualRisks`): the desired output gives no email, and the sanitiser keeps it. A
        // lowercase name is no capitalised word; German capitalises the noun before it ("Freundin"), so there the row holds.
        var lowercase: [(code: String, description: String)] = []
        lowercase.append(("en", "I'm Maria Rossi, a friend of anna verdi. Email: anna@example.com."))
        lowercase.append(("it", "Sono Maria Rossi, un'amica di anna verdi. Email: anna@example.com."))
        lowercase.append(("de", "Ich bin Maria Rossi, eine Freundin von anna verdi. E-Mail: anna@example.com."))
        lowercase.append(("es", "Soy Maria Rossi, una amiga de anna verdi. Correo: anna@example.com."))
        lowercase.append(("fr", "Je suis Maria Rossi, une amie d'anna verdi. Courriel : anna@example.com."))
        lowercase.append(("pt", "Sou Maria Rossi, uma amiga de anna verdi. E-mail: anna@example.com."))
        for v in lowercase {
            rows.append(row("a-lowercase-name-in-a-fragment-gives-no-email-\(v.code)",
                            "the fragment names anna verdi in lowercase: the email is hers, and should go",
                            v.description, CVData(personalInfo: person(name: "Maria Rossi", email: email)),
                            .safe(never: [], absent: ["personalInfo.email"]), language: v.code))
        }
        rows.append(row("a-name-equal-to-an-employer-in-a-fragment-gives-no-email-en",
                        "the fragment names Anna Verdi, who is also the employer the draft quotes: the email is hers, and should go",
                        "I worked at Anna Verdi. I'm Maria Rossi, a friend of Anna Verdi. Email: anna@example.com.",
                        CVData(personalInfo: person(name: "Maria Rossi", email: email), experience: [job("", "Anna Verdi")]),
                        .safe(never: [], absent: ["personalInfo.email"])))

        // Control: the capitalised words of the fragment are quotes of the draft (the job's title and employer).
        typealias Gemelli = (code: String, description: String, title: String)
        var gemelli: [Gemelli] = []
        gemelli.append(("en", "I'm Maria Rossi, a nurse at Policlinico Gemelli. Email: me@example.com.", "nurse"))
        gemelli.append(("it", "Sono Maria Rossi, infermiera al Policlinico Gemelli. Email: me@example.com.", "infermiera"))
        gemelli.append(("de", "Ich bin Maria Rossi, Krankenschwester am Policlinico Gemelli. E-Mail: me@example.com.", "Krankenschwester"))
        gemelli.append(("es", "Soy Maria Rossi, enfermera en el Policlinico Gemelli. Correo: me@example.com.", "enfermera"))
        gemelli.append(("fr", "Je suis Maria Rossi, infirmière au Policlinico Gemelli. Courriel : me@example.com.", "infirmière"))
        gemelli.append(("pt", "Sou Maria Rossi, enfermeira no Policlinico Gemelli. E-mail: me@example.com.", "enfermeira"))
        for v in gemelli {
            rows.append(row("a-fragment-of-quoted-words-keeps-the-email-\(v.code)",
                            "the fragment's capitalised words are the employer the draft gives: the name and the email stay",
                            v.description,
                            CVData(personalInfo: person(name: "Maria Rossi", email: "me@example.com"), experience: [job(v.title, "Policlinico Gemelli")]),
                            .safe(never: [], keeping: ["personalInfo.name": "Maria Rossi", "personalInfo.email": "me@example.com"]),
                            language: v.code))
        }
        return rows
    }

    // MARK: The app's example keeps every fact

    /// The example the AI screen shows (`ai.generation.example_text`, the same text as `AppExample`, see
    /// `exampleDescriptionsAreTheApps`) is a model of how to write a description: every fact of it passes ADR 0023. The draft holds
    /// exactly its facts, with no prose, and all of them stay.
    private static func theAppExampleKeepsEveryFact() -> [GroundingRow] {
        typealias Facts = (language: String, person: PersonalInfo, school: Experience, nursery: Experience, degree: Education,
                           languages: [Language], interests: [String])
        var facts: [Facts] = []
        facts.append(("en", person(name: "Maria Rossi", location: "Bologna", title: "primary school teacher"),
                      job("primary school teacher", "Don Milani school", from: "2016", current: true), job("assistant", "nursery", from: "2012", to: "2016"),
                      study("Education Sciences", at: "University of Bologna", to: "2012"),
                      [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .b2)], ["chess", "hiking"]))
        facts.append(("it", person(name: "Maria Rossi", location: "Bologna", title: "insegnante di scuola primaria"),
                      job("insegnante di scuola primaria", "scuola Don Milani", from: "2016", current: true),
                      job("assistente", "asilo nido", from: "2012", to: "2016"),
                      study("Scienze della Formazione", at: "Università di Bologna", to: "2012"),
                      [Language(name: "italiano", proficiency: .native), Language(name: "inglese", proficiency: .b2)], ["scacchi", "escursioni"]))
        facts.append(("de", person(name: "Maria Rossi", location: "Bologna", title: "Grundschullehrerin"),
                      job("Grundschullehrerin", "Schule Don Milani", from: "2016", current: true),
                      job("Betreuerin", "Kinderkrippe", from: "2012", to: "2016"),
                      study("Erziehungswissenschaften", at: "Universität Bologna", to: "2012"),
                      [Language(name: "Italienisch", proficiency: .native), Language(name: "Englisch", proficiency: .b2)], ["Schach", "Wandern"]))
        facts.append(("es", person(name: "Maria Rossi", location: "Bolonia", title: "maestra de primaria"),
                      job("maestra de primaria", "escuela Don Milani", from: "2016", current: true), job("auxiliar", "guardería", from: "2012", to: "2016"),
                      study("Ciencias de la Educación", at: "Universidad de Bolonia", to: "2012"),
                      [Language(name: "italiano", proficiency: .native), Language(name: "inglés", proficiency: .b2)], ["ajedrez", "senderismo"]))
        facts.append(("fr", person(name: "Maria Rossi", location: "Bologne", title: "institutrice"),
                      job("institutrice", "école Don Milani", from: "2016", current: true), job("assistante", "crèche", from: "2012", to: "2016"),
                      study("sciences de l'éducation", at: "université de Bologne", to: "2012"),
                      [Language(name: "italien", proficiency: .native), Language(name: "anglais", proficiency: .b2)], ["échecs", "randonnée"]))
        facts.append(("pt", person(name: "Maria Rossi", location: "Bolonha", title: "professora do ensino fundamental"),
                      job("professora do ensino fundamental", "escola Don Milani", from: "2016", current: true),
                      job("auxiliar", "creche", from: "2012", to: "2016"),
                      study("Ciências da Educação", at: "Universidade de Bolonha", to: "2012"),
                      [Language(name: "italiano", proficiency: .native), Language(name: "inglês", proficiency: .b2)], ["xadrez", "caminhadas"]))

        return facts.map { v in
            let draft = CVData(personalInfo: v.person, experience: [v.school, v.nursery], education: [v.degree], languages: v.languages,
                               interests: v.interests)
            return row("the-app-example-keeps-every-fact-\(v.language)",
                       "the app's example is a model of a description: every fact of it stays",
                       AppExample.text(in: v.language), draft, .exactly(draft), kind: .faithful, language: v.language)
        }
    }

    // MARK: Drafts a real model wrote

    // Each draft below is the raw answer of the on-device model to a description of the app, as the probe recorded it. Each
    // row says what ADR 0023 keeps of it and, in its drops, what it takes out by design. Where ADR 0023 is unclear, the
    // reason says so.

    private static func realModelProbes() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        rows.append(probeEN())
        rows.append(probeIT())
        rows.append(probeDE())
        rows.append(probeES())
        rows.append(probeFR())
        rows.append(probePT())
        rows.append(probeLongEN())
        rows.append(probeContactsEN())
        rows.append(probeSparseEN())
        rows.append(probeSparseIT())
        rows += firstRunOnTheRealModel()
        return rows
    }

    /// The model writes 2016-01-01 for "since 2016". ADR 0023 cuts such a date to what the description wrote: the year.
    private static func isoDate(_ path: String, _ year: String) -> Rewrite {
        Rewrite(path, to: year, "the model wrote an ISO date; it is cut to the year, which is what the description wrote")
    }

    private static func probeEN() -> GroundingRow {
        var jobs: [Experience] = []
        jobs.append(Experience(title: "Primary School Teacher", company: "Don Milani School", location: "Bologna", startDate: "2016-01-01",
                               endDate: null, current: true, description: "Trained 3 new teachers and taught at the Don Milani School.",
                               achievements: ["Trained 3 new teachers"]))
        jobs.append(Experience(title: "Assistant", company: "Nursery", location: "Bologna", startDate: "2012-01-01", endDate: "2016-01-01",
                               description: "Worked as an assistant in a nursery.", achievements: ["Worked as an assistant in a nursery"]))
        var studies: [Education] = []
        studies.append(Education(degree: "Education Sciences", institution: "University of Bologna", startDate: "2012-01-01",
                                 endDate: "2012-12-31", description: "Graduated in 2012."))
        var languages: [Language] = []
        languages.append(Language(name: "Italian", proficiency: .native))
        languages.append(Language(name: "English", proficiency: .b2))
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", email: null, phone: null, location: "Bologna", website: null, linkedin: null,
                                       github: null, title: "Primary School Teacher"),
            summary: "Primary school teacher with 4 years of experience, specializing in education sciences.",
            experience: jobs, education: studies, languages: languages, interests: ["Chess", "Hiking"])

        var drops = Drop.nulls(in: draft)
        drops.append(Drop("summary", "a number, and words (years, experience, specializing) the description does not use"))
        drops.append(Drop("experience[0].location", "Bologna stands in the sentence about the person, not in the clause that names the school"))
        drops.append(Drop("experience[0].description", "its 3 and its teachers come from a clause that gives the achievement alone"))
        drops.append(Drop("experience[1].location", "Bologna is not in the clause that names the nursery"))
        drops.append(Drop("education[0].startDate", "the year 2012 is written once and backs one date of a study: its end"))
        let rewrites = [
            isoDate("experience[0].startDate", "2016"),
            isoDate("experience[1].startDate", "2012"),
            isoDate("experience[1].endDate", "2016"),
            Rewrite("education[0].endDate", to: "2012", "the model wrote an ISO date; the graduation phrase gives the year as the end date"),
        ]
        return row("probe-en",
                   "kept: all but the summary, the places of the jobs, the role text of the school job and the start of the study; the 3 new teachers and the year of the degree stay",
                   AppExample.en, draft, .keeping(drops, rewriting: rewrites), kind: .probe, language: "en")
    }

    private static func probeIT() -> GroundingRow {
        var jobs: [Experience] = []
        jobs.append(Experience(title: "Insegnante di scuola primaria", company: "Scuola Don Milani", location: "Bologna", startDate: "2016",
                               endDate: "present", current: true, description: "Formato 3 nuovi insegnanti e gestito le attività scolastiche.",
                               achievements: ["Formazione di nuovi insegnanti"]))
        jobs.append(Experience(title: "Assistente in asilo nido", company: null, location: null, startDate: "2012", endDate: "2016",
                               description: "Supportato le attività quotidiane e le attività educative.",
                               achievements: ["Supporto alle attività educative"]))
        var studies: [Education] = []
        studies.append(Education(degree: "Scienze della Formazione", institution: "Università di Bologna", startDate: "2012", endDate: "2012",
                                 description: "Laurea in Scienze della Formazione."))
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", email: null, phone: null, location: "Bologna", website: null, linkedin: null,
                                       github: null, title: "Insegnante di scuola primaria"),
            summary: "Insegnante di scuola primaria con esperienza in formazione e assistenza.",
            experience: jobs, education: studies, languages: [Language(name: "Italiano", proficiency: .native)],
            interests: ["Scacchi", "Escursioni"])

        var drops = Drop.nulls(in: draft)
        drops.append(Drop("summary", "con, esperienza and assistenza are words the description does not use"))
        drops.append(Drop("experience[0].location", "Bologna is not in the clause that names the school"))
        drops.append(Drop("experience[0].endDate", "present is not a word of the description"))
        drops.append(Drop("experience[0].description", "its 3 and its words stand in the clause after the comma, which names no employer"))
        drops.append(Drop("experience[0].achievements[0]", "the same clause after the comma"))
        drops += Drop.entry("experience[1]", in: draft,
                            because: "the title is not a quote (the description says: assistente in un asilo nido) and the employer is the word null")
        drops.append(Drop("education[0].startDate", "the year 2012 is written once and backs one date of a study: its end"))
        drops.append(Drop("education[0].description", "laurea is a word of studying that the description does not use (it says laureata)"))
        return row("probe-it",
                   "kept: name, place, title, the school job (employer, title, year, current), the degree and its year, language, interests; the second job goes",
                   AppExample.it, draft, .keeping(drops), kind: .probe, language: "it")
    }

    private static func probeDE() -> GroundingRow {
        var jobs: [Experience] = []
        jobs.append(Experience(title: "Grundschullehrerin", company: "Schule Don Milani", location: "Bologna", startDate: "2016-01-01",
                               endDate: "Present", current: true,
                               description: "Unterrichte 3 neue Lehrkräfte und arbeite an der Schule Don Milani.",
                               achievements: ["3 neue Lehrkräfte eingearbeitet"]))
        jobs.append(Experience(title: "Betreuerin", company: "Kinderkrippe", location: "Bologna", startDate: "2012-01-01", endDate: "2016-01-01",
                               description: "Arbeitete als Betreuerin in einer Kinderkrippe."))
        var studies: [Education] = []
        studies.append(Education(degree: "Erziehungswissenschaften", institution: "Universität Bologna", startDate: "2012-01-01",
                                 endDate: "2016-01-01", description: "Studium abgeschlossen."))
        var languages: [Language] = []
        languages.append(Language(name: "Italienisch", proficiency: .native))
        languages.append(Language(name: "Englisch", proficiency: .b2))
        let kept = "Sie hat Erziehungswissenschaften an der Universität Bologna studiert und spricht Italienisch (Muttersprache) und "
            + "Englisch (B2). In ihrer Freizeit mag sie Schach und Wandern."
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bologna", title: "Grundschullehrerin"),
            summary: "Maria Rossi, Grundschullehrerin aus Bologna, mit 3 Jahren Erfahrung als Lehrerin an der Schule Don Milani. " + kept,
            experience: jobs, education: studies, languages: languages, interests: ["Schach", "Wandern"])

        var drops: [Drop] = []
        drops.append(Drop("experience[0].location", "Bologna is not in the clause that names the school"))
        drops.append(Drop("experience[0].endDate", "Present is not a word of the description"))
        drops.append(Drop("experience[0].description", "its 3 and its words come from a clause that no quote of the draft can explain"))
        drops.append(Drop("experience[0].achievements[0]", "the quote begins with a number, not with a CV verb: it explains nothing"))
        drops.append(Drop("experience[1].location", "Bologna is not in the clause that names the Kinderkrippe"))
        drops.append(Drop("education[0].endDate", "2016 is not a year of the studies: the description gives 2012"))
        drops.append(Drop("education[0].description", "Studium and abgeschlossen are words of studying that the description does not use"))
        drops.append(Drop("education[0].startDate", "2012 meinen Abschluss gemacht gives a degree its end date, and the end date of the draft is 2016"))
        drops.append(Drop("experience[1].description", "arbeitete comes first, but gearbeitet comes last in the clause of the description: the order differs"))
        drops.append(Drop("summary", "the first sentence holds a number; sie hat and spricht are not the forms of the clauses (ich habe, ich spreche)"))
        let rewrites = [
            isoDate("experience[0].startDate", "2016"),
            isoDate("experience[1].startDate", "2012"),
            isoDate("experience[1].endDate", "2016"),
        ]
        return row("probe-de",
                   "kept: name, place, title, both jobs with their years and current, the degree; the summary is no quote, and goes",
                   AppExample.de, draft, .keeping(drops, rewriting: rewrites), kind: .probe, language: "de")
    }

    private static func probeES() -> GroundingRow {
        var jobs: [Experience] = []
        jobs.append(Experience(title: "Maestra de primaria", company: "Escuela Don Milani", location: "Bolonia", startDate: "2016-01-01",
                               endDate: null, current: true,
                               description: "Enseño a estudiantes de primaria, desarrollando sus habilidades académicas y sociales.",
                               achievements: ["Formé a 3 nuevos maestros."]))
        jobs.append(Experience(title: "Auxiliar en guardería", company: null, location: null, startDate: "2012-01-01", endDate: "2016-01-01",
                               description: "Ayudé en las actividades diarias de los niños y supervisé su seguridad.",
                               achievements: ["Mejoré mis habilidades de comunicación y trabajo en equipo."]))
        var studies: [Education] = []
        studies.append(Education(degree: "Ciencias de la Educación", institution: "Universidad de Bolonia", startDate: "2012-01-01",
                                 endDate: "2012-12-31", description: "Estudié para obtener mi título de maestra de primaria."))
        var languages: [Language] = []
        languages.append(Language(name: "Italiano", proficiency: .native))
        languages.append(Language(name: "Inglés", proficiency: .b2))
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", email: null, phone: null, location: "Bolonia", website: null, linkedin: null,
                                       github: null, title: "Maestra de primaria"),
            summary: "Maestra de primaria con 10 años de experiencia, formada en Ciencias de la Educación en la Universidad de Bolonia. "
                + "He trabajado como auxiliar en una guardería antes de enseñar en la escuela Don Milani.",
            experience: jobs, education: studies, languages: languages, interests: ["Ajedrez", "Senderismo"])

        var drops = Drop.nulls(in: draft)
        drops.append(Drop("experience[0].location", "Bolonia is not in the clause that names the school"))
        drops.append(Drop("experience[0].description", "estudiantes, desarrollando, habilidades are words the description does not use"))
        drops += Drop.entry("experience[1]", in: draft,
                            because: "the title is not a quote (the description says: auxiliar en una guardería) and the employer is the word null")
        drops.append(Drop("education[0].startDate", "the year 2012 is written once and backs one date of a study: its end"))
        drops.append(Drop("education[0].description", "maestra de primaria is neither a word of the lists nor of the clauses of the studies"))
        drops.append(Drop("summary", "its first sentence holds a number (10 años); the second takes its words from three clauses of the description"))
        let rewrites = [
            isoDate("experience[0].startDate", "2016"),
            Rewrite("education[0].endDate", to: "2012", "the model wrote an ISO date; the graduation phrase gives the year as the end date"),
        ]
        return row("probe-es",
                   "kept: name, place, title, the school job (employer, title, year, current, the 3 new teachers), the degree and its year, languages, interests",
                   AppExample.es, draft, .keeping(drops, rewriting: rewrites), kind: .probe, language: "es")
    }

    private static func probeFR() -> GroundingRow {
        var jobs: [Experience] = []
        jobs.append(Experience(title: "Assistant", company: null, location: null, startDate: "2012-2016", endDate: null,
                               description: "Worked as an assistant in a crèche, contributing to the educational and developmental needs of young children.",
                               achievements: ["Contributed to the daily activities and learning environment of the children."]))
        jobs.append(Experience(title: "Institutrice", company: "Don Milani", location: "Bologne", startDate: "2016-present", endDate: null,
                               current: true,
                               description: "Instructional role at Don Milani school, focusing on teaching primary school students.",
                               achievements: ["Formed 3 new teachers."]))
        var studies: [Education] = []
        studies.append(Education(degree: "Sciences of Education", institution: "University of Bologna", startDate: "2012", endDate: "2016",
                                 description: "Completed a degree in sciences of education, preparing her for a career in teaching."))
        var languages: [Language] = []
        languages.append(Language(name: "italien", proficiency: .native))
        languages.append(Language(name: "anglais", proficiency: .b2))
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", email: null, phone: null, location: null, website: null, linkedin: null,
                                       github: null, title: null),
            summary: "Maria Rossi, a dedicated educator with a passion for teaching, has been an integral part of the Don Milani school since 2016. "
                + "She has successfully trained three new teachers and has a strong background in education, having studied sciences of "
                + "education at the University of Bologna.",
            experience: jobs, education: studies, languages: languages, interests: ["Échecs", "Randonnée"])

        var drops = Drop.nulls(in: draft)
        drops.append(Drop("summary", "written in English for a French description: not one of its words is the description's"))
        drops += Drop.entry("experience[0]", in: draft, because: "English text, a title the description does not use, an employer that is the word null")
        drops.append(Drop("experience[1].location", "Bologne is not in the clause that names the school"))
        drops.append(Drop("experience[1].description", "written in English: not one of its words is the description's"))
        drops.append(Drop("experience[1].achievements[0]", "written in English, and its 3 stands in the clause after the comma"))
        drops += Drop.entry("education[0]", in: draft, because: "English names: neither the degree nor the university is a quote")
        let rewrites = [
            Rewrite("experience[1].startDate", to: "2016",
                    "2016-present is cut to the year, which the clause Depuis 2016, gives: it joins the clause of the school"),
        ]
        return row("probe-fr",
                   "kept: name, the school job (employer, title, year, current), languages, interests; the English text and the first job go",
                   AppExample.fr, draft, .keeping(drops, rewriting: rewrites), kind: .probe, language: "fr")
    }

    private static func probePT() -> GroundingRow {
        var jobs: [Experience] = []
        jobs.append(Experience(title: "Professora de ensino fundamental", company: "Escola Don Milani", location: "Bolonha", startDate: "2016-01-01",
                               endDate: null, description: "Leciono desde 2016, formando 3 novos professores.",
                               achievements: ["Formação de professores"]))
        jobs.append(Experience(title: "Auxiliar em creche", company: null, location: null, startDate: "2012-01-01", endDate: "2016-01-01",
                               description: "Trabalhei como auxiliar em uma creche.", achievements: ["Trabalho em equipe"]))
        var studies: [Education] = []
        studies.append(Education(degree: "Ciências da Educação", institution: "Universidade de Bolonha", startDate: "2012-01-01",
                                 endDate: "2016-01-01", description: "Estudei Ciências da Educação na Universidade de Bolonha."))
        var languages: [Language] = []
        languages.append(Language(name: "Italiano", proficiency: .native))
        languages.append(Language(name: "Inglês", proficiency: .b2))
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", email: null, phone: null, location: "Bolonha", website: null, linkedin: null,
                                       github: null, title: "Professora"),
            summary: "Professora de ensino fundamental em Bolonha, com 3 anos de experiência em formação de professores.",
            experience: jobs, education: studies, languages: languages, interests: ["Xadrez", "Caminhadas"])

        var drops = Drop.nulls(in: draft)
        drops.append(Drop("summary", "a number (3 anos), and words the description does not use"))
        drops.append(Drop("experience[0].title", "not a quote: the description says professora do ensino fundamental"))
        drops.append(Drop("experience[0].location", "Bolonha is not in the clause that names the school"))
        drops.append(Drop("experience[0].description", "its 3 and its professores stand in the clause after the comma, which names no employer"))
        drops.append(Drop("experience[0].achievements[0]", "formação is not a word of the description"))
        drops += Drop.entry("experience[1]", in: draft,
                            because: "the title is not a quote (the description says: auxiliar em uma creche) and the employer is the word null")
        drops.append(Drop("education[0].endDate", "2016 is not a year of the studies: the description gives 2012"))
        drops.append(Drop("education[0].startDate", "me formei em 2012 gives a degree its end date, and the end date of the draft is 2016"))
        let rewrites = [isoDate("experience[0].startDate", "2016")]
        return row("probe-pt",
                   "kept: name, place, title, the school (employer, year), the degree, a study text made of one clause's words, languages, interests",
                   AppExample.pt, draft, .keeping(drops, rewriting: rewrites), kind: .probe, language: "pt")
    }

    private static let longDescription = """
        I'm Giulia Ferrari, a registered nurse from Turin. \
        You can reach me at giulia.ferrari@example.com or on +39 340 555 1234, and my profile is linkedin.com/in/giulia-ferrari. \
        I started in 2009 as a nursing assistant at the Mauriziano hospital, where I stayed until 2012. \
        From 2012 to 2018 I worked as a ward nurse in the cardiology department of the Molinette hospital in Turin, caring for up to 14 \
        patients per shift and training 6 new nurses. \
        In 2018 I moved to the Humanitas clinic in Milan as a senior nurse in intensive care, where I coordinated a team of 9 nurses until 2021. \
        Since 2021 I have been the head nurse of the emergency department at San Giovanni Bosco hospital in Turin, managing 25 staff members \
        and introducing a triage protocol that cut waiting times. \
        I graduated in Nursing at the University of Turin in 2009 with 108 out of 110, and in 2015 I completed a Master in Critical Care \
        Nursing at the University of Milan. \
        I hold BLS and ACLS certifications from the Italian Resuscitation Council, renewed in 2023, and a PALS certificate from 2019. \
        My skills include triage, wound care, ventilator management, patient education and electronic health records. \
        I speak Italian (native), English (C1) and French (B1). \
        Outside work I like trail running, photography and volunteering for the Red Cross, where I have been active since 2010. \
        I am looking for a leadership role in an emergency or intensive care unit.
        """

    /// Four jobs, whose clauses hold words like cardiology, department, intensive: ADR 0023 backs the dates of one only.
    private static func probeLongEN() -> GroundingRow {
        var jobs: [Experience] = []
        jobs.append(Experience(title: "Head Nurse", company: "San Giovanni Bosco Hospital", location: "Turin", startDate: "2021-01-01",
                               endDate: "present", current: true,
                               description: "Manages 25 staff members and implements a triage protocol that reduces waiting times.",
                               achievements: ["Introduced a triage protocol that cut waiting times by 20%."]))
        jobs.append(Experience(title: "Senior Nurse", company: "Humanitas Clinic", location: "Milan", startDate: "2018-01-01", endDate: "2021-12-31",
                               description: "Coordinated a team of 9 nurses in intensive care.", achievements: ["Improved patient outcomes by 15%."]))
        jobs.append(Experience(title: "Ward Nurse", company: "Molinette Hospital", location: "Turin", startDate: "2012-01-01", endDate: "2018-12-31",
                               description: "Cared for up to 14 patients per shift and trained 6 new nurses.",
                               achievements: ["Trained 6 new nurses."]))
        jobs.append(Experience(title: "Nursing Assistant", company: "Mauriziano Hospital", location: "Turin", startDate: "2009-01-01",
                               endDate: "2012-12-31", description: "Assisted in patient care and administrative tasks.",
                               achievements: ["Provided patient care and administrative support."]))
        var studies: [Education] = []
        studies.append(Education(degree: "Nursing", institution: "University of Turin", startDate: "2009-01-01", endDate: "2012-12-31",
                                 description: "Graduated with 108 out of 110."))
        var skills: [Skill] = []
        skills.append(Skill(name: "Triage", level: .advanced))
        skills.append(Skill(name: "Wound Care", level: .expert))
        skills.append(Skill(name: "Ventilator Management", level: .expert))
        skills.append(Skill(name: "Patient Education", level: .expert))
        skills.append(Skill(name: "Electronic Health Records", level: .expert))
        var languages: [Language] = []
        languages.append(Language(name: "Italian", proficiency: .native))
        languages.append(Language(name: "English", proficiency: .c1))
        languages.append(Language(name: "French", proficiency: .b1))
        var certifications: [Certification] = []
        certifications.append(Certification(name: "BLS", issuer: "Italian Resuscitation Council", date: "2023-01-01",
                                            url: "https://www.irs.it/certificazioni/bls"))
        certifications.append(Certification(name: "ACLS", issuer: "Italian Resuscitation Council", date: "2023-01-01",
                                            url: "https://www.irs.it/certificazioni/acls"))
        certifications.append(Certification(name: "PALS", issuer: "Italian Resuscitation Council", date: "2019-01-01",
                                            url: "https://www.irs.it/certificazioni/pals"))
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Giulia Ferrari", email: "giulia.ferrari@example.com", phone: "+39 340 555 1234", location: "Turin",
                                       linkedin: "linkedin.com/in/giulia-ferrari"),
            summary: "Registered nurse with over a decade of experience in emergency and intensive care units, specializing in patient care, "
                + "triage, and team coordination.",
            experience: jobs, education: studies, skills: skills, languages: languages, certifications: certifications,
            interests: ["Trail running", "Photography", "Volunteering for the Red Cross"])

        var drops: [Drop] = []
        drops.append(Drop("summary", "a decade is not a word of the description, and neither are specializing or coordination"))
        let noBacking = "the clause that names the employer holds words (department, intensive, cardiology) that nothing explains: it backs nothing"
        for index in 0...2 {
            drops.append(Drop("experience[\(index)].location", noBacking))
            drops.append(Drop("experience[\(index)].startDate", noBacking))
            drops.append(Drop("experience[\(index)].endDate", noBacking))
            drops.append(Drop("experience[\(index)].description", noBacking))
            drops.append(Drop("experience[\(index)].achievements[0]", noBacking))
        }
        drops.append(Drop("experience[0].current", noBacking))
        drops.append(Drop("experience[3].location", "Turin is not in the clause that names the Mauriziano hospital"))
        drops.append(Drop("experience[3].endDate", "where I stayed until 2012 joins nothing: it holds the word stayed, which nothing explains"))
        drops.append(Drop("experience[3].description", "assisted, administrative and tasks are words the description does not use"))
        drops.append(Drop("experience[3].achievements[0]", "the same words"))
        drops.append(Drop("education[0].endDate", "2012 is the end of another job; the clause of the studies gives 2009"))
        for index in 0..<5 {
            drops.append(Drop("skills[\(index)].level", "the description names the skills and says nothing of their level"))
        }
        for (index, name) in ["BLS", "ACLS", "PALS"].enumerated() {
            let clause = "the clause of the \(name) holds words (certifications, certificate, renewed) that nothing explains"
            drops.append(Drop("certifications[\(index)].issuer", clause))
            drops.append(Drop("certifications[\(index)].date", clause))
            drops.append(Drop("certifications[\(index)].url", "an address the description never gives"))
        }
        drops.append(Drop("education[0].description",
                          "it leaves out in Nursing at the University of Turin in 2009 from its clause: no quote"))
        drops += Drop.entry("certifications[2]", in: draft,
                            because: "a PALS certificate from 2019 is a verbless clause split off by and: it belongs to renewed in 2023, whose verb is not a listed one")
        let rewrites = [
            Rewrite("experience[3].startDate", to: "2009", "I started in 2009 as a nursing assistant at the Mauriziano hospital is explained"),
            Rewrite("education[0].startDate", to: "2009", "the year the clause of the studies gives (it is the year of the degree: the ADR does not tell them apart)"),
        ]
        return row("probe-long-en",
                   "kept: the contacts, name, place, the four employers and titles, the Mauriziano start, the degree, skills, languages, interests, BLS and ACLS",
                   longDescription, draft, .keeping(drops, rewriting: rewrites), kind: .probe, language: "en")
    }

    private static func probeContactsEN() -> GroundingRow {
        var jobs: [Experience] = []
        jobs.append(Experience(title: "Nurse", company: "Hospital Name", location: "Turin", startDate: "2020-01-01", endDate: "Present", current: true,
                               description: "Providing comprehensive patient care and support in a busy hospital setting.",
                               achievements: ["Improved patient satisfaction scores by 15%",
                                              "Led a team of nurses in implementing a new patient management system"]))
        var languages: [Language] = []
        languages.append(Language(name: "Italian", proficiency: .native))
        languages.append(Language(name: "English", proficiency: .b2))
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Anna Verdi", email: "anna.verdi@example.com", phone: "+39 333 123 4567", location: "Turin",
                                       website: "https://www.annaverdi.dev/", linkedin: "linkedin.com/in/anna-verdi"),
            summary: "Nurse in Turin with a strong background in patient care and a passion for healthcare.",
            experience: jobs, languages: languages, interests: ["Traveling", "Reading"])

        var drops: [Drop] = []
        drops.append(Drop("summary", "strong, background, passion and healthcare are words the description does not use"))
        drops += Drop.entry("experience[0]", in: draft,
                            because: "Hospital Name is no quote and 2020 is not a year of the description: a title alone is the person's own")
        drops.append(Drop("interests[0]", "the description names no interest"))
        drops.append(Drop("interests[1]", "the description names no interest"))
        let description = "I'm Anna Verdi, a nurse in Turin. Email anna.verdi@example.com, phone +39 333 123 4567, "
            + "LinkedIn linkedin.com/in/anna-verdi, website https://www.annaverdi.dev/. I speak Italian (native) and English (B2)."
        return row("probe-contacts-en",
                   "kept: every contact detail the description gives in full, name, place, languages; the invented employer and interests go",
                   description, draft, .keeping(drops), kind: .probe, language: "en")
    }

    private static func probeSparseEN() -> GroundingRow {
        var jobs: [Experience] = []
        jobs.append(Experience(title: "Nurse", company: "Healthcare Facility", location: "City, State", startDate: "2023-01-01", endDate: null,
                               current: true,
                               description: "Provide patient care, monitor health status, and assist with medical procedures.",
                               achievements: ["Improved patient satisfaction scores by 15%.", "Trained new nurses in patient care protocols."]))
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Nurse", email: null, phone: null, location: null, website: null, linkedin: null, github: null,
                                       title: "Nurse"),
            summary: "Nurse with experience in patient care and healthcare administration.",
            experience: jobs,
            interests: ["Volunteering at local hospitals", "Reading medical journals", "Participating in healthcare workshops"])

        var drops = Drop.nulls(in: draft)
        drops.append(Drop("personalInfo.name", "Nurse is the person's title, not a name (the ADR is silent; a quote alone would keep it)"))
        drops.append(Drop("summary", "experience, healthcare and administration are words the description does not use"))
        drops += Drop.entry("experience[0]", in: draft, because: "Healthcare Facility and 2023 are not in the description; a title alone is not a job")
        for index in 0..<3 {
            drops.append(Drop("interests[\(index)]", "the description names no interest"))
        }
        return row("probe-sparse-en", "kept: only the title the person gave; a sparse description gives a sparse draft",
                   "I'm a nurse.", draft, .keeping(drops), kind: .probe, language: "en")
    }

    private static func probeSparseIT() -> GroundingRow {
        var jobs: [Experience] = []
        jobs.append(Experience(title: "Infermiera", company: null, current: true,
                               achievements: ["Mi occupo di prendermi cura delle persone.", "Sono sempre pronta ad aiutare."]))
        jobs.append(Experience(title: "Infermiera", company: null,
                               achievements: ["Mi occupo di prendermi cura delle persone.", "Sono sempre pronta ad aiutare."]))
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Infermiera", email: null, phone: null, location: null, website: null, linkedin: null, github: null,
                                       title: "Infermiera"),
            summary: "Sono infermiera e mi occupo di prendermi cura delle persone.",
            experience: jobs, interests: ["Infermieristica"])

        var drops = Drop.nulls(in: draft)
        drops.append(Drop("personalInfo.name", "Infermiera is the person's title, not a name (the ADR is silent; a quote alone would keep it)"))
        drops.append(Drop("summary", "occupo, prendermi, cura and persone are words the description does not use"))
        drops += Drop.entry("experience[0]", in: draft, because: "no employer, no date: a title alone is not a job")
        drops += Drop.entry("experience[1]", in: draft, because: "no employer, no date: a title alone is not a job")
        drops.append(Drop("interests[0]", "Infermieristica is not a word of the description"))
        return row("probe-sparse-it", "kept: only the title the person gave; a sparse description gives a sparse draft",
                   "Sono infermiera.", draft, .keeping(drops), kind: .probe, language: "it")
    }

    // MARK: The first run on the real on-device model (#202)

    // The raw answers of the on-device model on 2026-10-18 (macOS 27.0.1, Apple Intelligence on), run 1 of each description: the
    // app's six examples and a nurse in Turin. The three runs of each description gave the same draft. Each row expects the whole
    // grounded draft, in the model's order of the jobs: the use case then puts the current job first (see `JobOrder`).

    private static let nurseInTurin = """
        My name is Giulia Bianchi and I am a registered nurse living in Turin. \
        My email is giulia.bianchi@example.com and my phone number is +39 333 123 4567. \
        Since March 2019 I have worked as a ward nurse in the cardiology department of the Molinette hospital in Turin, where I look \
        after up to 12 patients per shift and train new colleagues. \
        From 2016 to 2019 I worked as a home care nurse for the Il Sorriso cooperative in Moncalieri. \
        I graduated in Nursing from the University of Turin in 2016. \
        I speak Italian (native), English (B2) and French (A2). \
        I am good at ECG monitoring, wound care and patient education. \
        In my free time I sing in a choir and go cycling.
        """

    private static func firstRunOnTheRealModel() -> [GroundingRow] {
        var rows: [GroundingRow] = []
        rows.append(firstRunEN())
        rows.append(firstRunIT())
        rows.append(firstRunDE())
        rows.append(firstRunES())
        rows.append(firstRunFR())
        rows.append(firstRunPT())
        rows.append(firstRunNurseEN())
        return rows
    }

    private static func firstRunEN() -> GroundingRow {
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bologna"),
            summary: "I am a primary school teacher from Bologna. Since 2016 I have taught at Don Milani school and trained 3 new teachers. "
                + "Before that, from 2012 to 2016, I worked as an assistant in a nursery.",
            experience: [
                Experience(title: "assistant", company: "a nursery", location: "Bologna", startDate: "2012", endDate: "2016",
                           description: "I worked as an assistant in a nursery"),
                Experience(title: "primary school teacher", company: "Don Milani school", location: "Bologna", startDate: "2016", endDate: null,
                           current: true, description: "I taught at Don Milani school and trained 3 new teachers",
                           achievements: ["trained 3 new teachers"]),
            ],
            education: [
                Education(degree: "Education Sciences", institution: "University of Bologna", startDate: "2012", endDate: "2012",
                          description: "I studied Education Sciences at the University of Bologna and graduated in 2012"),
            ],
            skills: [Skill(name: "chess", level: .beginner)],
            languages: [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .b2)],
            interests: ["chess", "hiking"])
        let expected = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bologna"),
            experience: [
                Experience(title: "assistant", company: "nursery", startDate: "2012", endDate: "2016",
                           description: "I worked as an assistant in a nursery"),
                Experience(title: "primary school teacher", company: "Don Milani school", startDate: "2016", current: true,
                           achievements: ["trained 3 new teachers"]),
            ],
            education: [
                Education(degree: "Education Sciences", institution: "University of Bologna", endDate: "2012",
                          description: "I studied Education Sciences at the University of Bologna and graduated in 2012"),
            ],
            languages: [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .b2)],
            interests: ["chess", "hiking"])
        return row("first-run-on-the-real-model-example-en",
                   "kept: name, place, both jobs with titles and years, the 3 new teachers, the degree and its year, languages, interests; "
                       + "chess is a hobby and no skill, and a nursery loses its article",
                   AppExample.en, draft, .exactly(expected), kind: .probe, language: "en")
    }

    private static func firstRunIT() -> GroundingRow {
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bologna"),
            summary: "Sono insegnante di scuola primaria a Bologna. Dal 2016 insegno alla scuola Don Milani, dove ho formato 3 nuovi insegnanti. "
                + "Prima, dal 2012 al 2016, ho lavorato come assistente in un asilo nido.",
            experience: [
                Experience(title: "insegnante", company: "scuola Don Milani", location: "Bologna", current: true,
                           description: "insegno alla scuola Don Milani", achievements: ["ho formato 3 nuovi insegnanti"]),
                Experience(title: "assistente", company: "asilo nido", location: "Bologna",
                           description: "ho lavorato come assistente in un asilo nido"),
            ],
            education: [
                Education(degree: "Scienze della Formazione", institution: "Università di Bologna", startDate: "2012", endDate: "2012",
                          description: "mi sono laureata nel 2012"),
            ],
            skills: [Skill(name: "scacchi", level: .beginner), Skill(name: "escursioni", level: .beginner)],
            languages: [Language(name: "italiano", proficiency: .native), Language(name: "inglese", proficiency: .b2)],
            interests: ["scacchi", "escursioni"])
        let expected = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bologna"),
            experience: [
                Experience(title: "insegnante", company: "scuola Don Milani", current: true, achievements: ["ho formato 3 nuovi insegnanti"]),
                Experience(title: "assistente", company: "asilo nido", description: "ho lavorato come assistente in un asilo nido"),
            ],
            education: [
                Education(degree: "Scienze della Formazione", institution: "Università di Bologna", endDate: "2012",
                          description: "mi sono laureata nel 2012"),
            ],
            languages: [Language(name: "italiano", proficiency: .native), Language(name: "inglese", proficiency: .b2)],
            interests: ["scacchi", "escursioni"])
        return row("first-run-on-the-real-model-example-it",
                   "kept: name, place, both jobs with their titles, the 3 new teachers, the degree and its year, languages, interests; "
                       + "chess and hiking are hobbies and no skills",
                   AppExample.it, draft, .exactly(expected), kind: .probe, language: "it")
    }

    private static func firstRunDE() -> GroundingRow {
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bologna", title: "Grundschullehrerin"),
            summary: "Ich bin Grundschullehrerin aus Bologna. Seit 2016 unterrichte ich an der Schule Don Milani, wo ich 3 neue Lehrkräfte "
                + "eingearbeitet habe. Davor habe ich von 2012 bis 2016 als Betreuerin in einer Kinderkrippe gearbeitet.",
            experience: [
                Experience(title: "Betreuerin", company: "Kinderkrippe", location: "Bologna",
                           description: "von 2012 bis 2016 als Betreuerin in einer Kinderkrippe gearbeitet"),
                Experience(title: "Grundschullehrerin", company: "Schule Don Milani", location: "Bologna", current: true,
                           description: "3 neue Lehrkräfte eingearbeitet", achievements: ["3 neue Lehrkräfte eingearbeitet"]),
            ],
            education: [
                Education(degree: "Erziehungswissenschaften", institution: "Universität Bologna", startDate: "2012", endDate: "2012",
                          description: "2012 meinen Abschluss gemacht"),
            ],
            languages: [Language(name: "Italienisch", proficiency: .native), Language(name: "Englisch", proficiency: .b2)],
            interests: ["Schach", "Wandern"])
        let expected = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bologna", title: "Grundschullehrerin"),
            experience: [
                Experience(title: "Betreuerin", company: "Kinderkrippe"),
                Experience(title: "Grundschullehrerin", company: "Schule Don Milani", current: true),
            ],
            education: [
                Education(degree: "Erziehungswissenschaften", institution: "Universität Bologna", endDate: "2012",
                          description: "2012 meinen Abschluss gemacht"),
            ],
            languages: [Language(name: "Italienisch", proficiency: .native), Language(name: "Englisch", proficiency: .b2)],
            interests: ["Schach", "Wandern"])
        return row("first-run-on-the-real-model-example-de",
                   "kept: name, place, title, both jobs with their titles, the degree and its year, languages, interests; the achievement "
                       + "begins with a number, not with a CV verb, and goes",
                   AppExample.de, draft, .exactly(expected), kind: .probe, language: "de")
    }

    private static func firstRunES() -> GroundingRow {
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bolonia"),
            summary: "Soy maestra de primaria en Bolonia. Desde 2016 enseño en la escuela Don Milani, donde formé a 3 nuevos maestros. "
                + "Antes, de 2012 a 2016, trabajé como auxiliar en una guardería.",
            experience: [
                Experience(title: "maestra de primaria", company: "escuela Don Milani", location: "Bolonia", current: true,
                           description: "enseño en la escuela Don Milani", achievements: ["formé a 3 nuevos maestros"]),
                Experience(title: "auxiliar", company: "una guardería", location: "Bolonia", description: "trabajé como auxiliar en una guardería"),
            ],
            education: [
                Education(degree: "Ciencias de la Educación", institution: "Universidad de Bolonia", startDate: "2012", endDate: "2012",
                          description: "estudié Ciencias de la Educación en la Universidad de Bolonia y me gradué en 2012"),
            ],
            skills: [Skill(name: "ajedrez", level: .beginner), Skill(name: "senderismo", level: .beginner)],
            languages: [Language(name: "italiano", proficiency: .native), Language(name: "inglés", proficiency: .b2)],
            interests: ["ajedrez", "senderismo"])
        let expected = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bolonia"),
            experience: [
                Experience(title: "maestra de primaria", company: "escuela Don Milani", current: true, achievements: ["formé a 3 nuevos maestros"]),
                Experience(title: "auxiliar", company: "guardería", description: "trabajé como auxiliar en una guardería"),
            ],
            education: [
                Education(degree: "Ciencias de la Educación", institution: "Universidad de Bolonia", endDate: "2012",
                          description: "estudié Ciencias de la Educación en la Universidad de Bolonia y me gradué en 2012"),
            ],
            languages: [Language(name: "italiano", proficiency: .native), Language(name: "inglés", proficiency: .b2)],
            interests: ["ajedrez", "senderismo"])
        return row("first-run-on-the-real-model-example-es",
                   "kept: name, place, both jobs with their titles, the 3 new teachers, the degree and its year, languages, interests; "
                       + "chess and hiking are hobbies and no skills, and una guardería loses its article",
                   AppExample.es, draft, .exactly(expected), kind: .probe, language: "es")
    }

    private static func firstRunFR() -> GroundingRow {
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bologne"),
            summary: "Je suis Maria Rossi, institutrice dans une école primaire de Bologne. Depuis 2016, j'enseigne à l'école Don Milani, "
                + "où j'ai formé 3 nouveaux enseignants. Avant, de 2012 à 2016, j'ai travaillé comme assistante dans une crèche.",
            experience: [
                Experience(title: "assistante", company: "crèche", location: "Bologne",
                           achievements: ["j'ai travaillé comme assistante dans une crèche"]),
                Experience(title: "institutrice", company: "école Don Milani", location: "Bologne", current: true,
                           achievements: ["j'ai formé 3 nouveaux enseignants"]),
            ],
            education: [Education(degree: "diplôme", institution: "université de Bologne", startDate: "2012")],
            languages: [Language(name: "italien", proficiency: .native), Language(name: "anglais", proficiency: .b2)],
            interests: ["échecs", "randonnée"])
        let expected = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bologne"),
            summary: "Je suis Maria Rossi, institutrice dans une école primaire de Bologne.",
            experience: [
                Experience(title: "assistante", company: "crèche", achievements: ["j'ai travaillé comme assistante dans une crèche"]),
                Experience(title: "institutrice", company: "école Don Milani", current: true, achievements: ["j'ai formé 3 nouveaux enseignants"]),
            ],
            education: [Education(institution: "université de Bologne")],
            languages: [Language(name: "italien", proficiency: .native), Language(name: "anglais", proficiency: .b2)],
            interests: ["échecs", "randonnée"])
        return row("first-run-on-the-real-model-example-fr",
                   "kept: name, place, the first sentence of the summary, both jobs with their titles, the 3 new teachers (j'ai holds no "
                       + "Italian ai), the university, languages, interests; diplôme alone names no degree",
                   AppExample.fr, draft, .exactly(expected), kind: .probe, language: "fr")
    }

    private static func firstRunPT() -> GroundingRow {
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bolonha"),
            summary: "Sou professora do ensino fundamental em Bolonha. Desde 2016 leciono na escola Don Milani, onde formei 3 novos professores. "
                + "Antes, de 2012 a 2016, trabalhei como auxiliar em uma creche.",
            experience: [
                Experience(title: "auxiliar", company: "creche", location: "Bolonha", startDate: "2012", endDate: "2016"),
                Experience(title: "professora", company: "escola Don Milani", location: "Bolonha", startDate: "2016", endDate: null, current: true,
                           achievements: ["formei 3 novos professores"]),
            ],
            education: [
                Education(degree: "Ciências da Educação", institution: "Universidade de Bolonha", startDate: "2012", endDate: "2012",
                          description: "me formei em 2012"),
            ],
            skills: [Skill(name: "xadrez", level: .beginner), Skill(name: "caminhadas", level: .beginner)],
            languages: [Language(name: "italiano", proficiency: .native), Language(name: "inglês", proficiency: .b2)],
            interests: ["xadrez", "caminhadas"])
        let expected = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bolonha"),
            experience: [
                Experience(title: "auxiliar", company: "creche", startDate: "2012", endDate: "2016"),
                Experience(title: "professora", company: "escola Don Milani", startDate: "2016", current: true,
                           achievements: ["formei 3 novos professores"]),
            ],
            education: [
                Education(degree: "Ciências da Educação", institution: "Universidade de Bolonha", endDate: "2012", description: "me formei em 2012"),
            ],
            languages: [Language(name: "italiano", proficiency: .native), Language(name: "inglês", proficiency: .b2)],
            interests: ["xadrez", "caminhadas"])
        return row("first-run-on-the-real-model-example-pt",
                   "kept: name, place, both jobs with titles and years, the school job's title professora (fundamental is a word of "
                       + "studying), the 3 new teachers, the degree and its year, languages, interests; chess and hiking are no skills",
                   AppExample.pt, draft, .exactly(expected), kind: .probe, language: "pt")
    }

    /// The years, the place and the achievements of the current job stand in a clause with words that nothing explains (cardiology,
    /// department): it backs nothing, so they go, and so does its current flag (ADR 0023, Consequences: thinner drafts).
    private static func firstRunNurseEN() -> GroundingRow {
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Giulia Bianchi", email: "giulia.bianchi@example.com", phone: "+39 333 123 4567", location: "Turin"),
            summary: "I am a registered nurse living in Turin. Since March 2019 I have worked as a ward nurse in the cardiology department of "
                + "the Molinette hospital in Turin, where I look after up to 12 patients per shift and train new colleagues. From 2016 to 2019 "
                + "I worked as a home care nurse for the Il Sorriso cooperative in Moncalieri. I graduated in Nursing from the University of "
                + "Turin in 2016.",
            experience: [
                Experience(title: "ward nurse", company: "Molinette hospital", location: "Turin", startDate: "March 2019", endDate: null,
                           current: true, description: "I look after up to 12 patients per shift and train new colleagues",
                           achievements: ["look after up to 12 patients per shift", "train new colleagues"]),
                Experience(title: "home care nurse", company: "Il Sorriso cooperative", location: "Moncalieri", startDate: "2016", endDate: "2019",
                           description: "I worked as a home care nurse", achievements: [null]),
            ],
            education: [
                Education(degree: "Nursing", institution: "University of Turin", startDate: "2016", endDate: "2016",
                          description: "I graduated in Nursing from the University of Turin in 2016"),
            ],
            skills: [
                Skill(name: "ECG monitoring", level: .beginner), Skill(name: "wound care", level: .beginner),
                Skill(name: "patient education", level: .beginner),
            ],
            languages: [
                Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .b2),
                Language(name: "French", proficiency: .a2),
            ],
            interests: ["singing in a choir", "going cycling"])
        let expected = CVData(
            personalInfo: PersonalInfo(name: "Giulia Bianchi", email: "giulia.bianchi@example.com", phone: "+39 333 123 4567", location: "Turin"),
            summary: "I am a registered nurse living in Turin.",
            experience: [
                Experience(title: "ward nurse", company: "Molinette hospital"),
                Experience(title: "home care nurse", company: "Il Sorriso cooperative", location: "Moncalieri", startDate: "2016", endDate: "2019"),
            ],
            education: [
                Education(degree: "Nursing", institution: "University of Turin", endDate: "2016",
                          description: "I graduated in Nursing from the University of Turin in 2016"),
            ],
            skills: [Skill(name: "ECG monitoring"), Skill(name: "wound care"), Skill(name: "patient education")],
            languages: [
                Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .b2),
                Language(name: "French", proficiency: .a2),
            ])
        return row("first-run-on-the-real-model-nurse-in-turin-en",
                   "kept: name, contacts, place, the first sentence of the summary, both employers and titles, the years and place of the "
                       + "older job, the degree and its year, skills without levels, languages; the paraphrased hobbies go",
                   nurseInTurin, draft, .exactly(expected), kind: .probe, language: "en")
    }
}

import Testing
import Foundation
import CVGeneratorAI

// The counter of invented facts is the heart of the go/no-go of #202: a counter that misses an invention would pass a
// draft that invents. These tests give it drafts that hold invented facts and drafts that do not, in the six languages of
// the app, on the descriptions the evaluation itself uses.

@Suite("Invented facts: the counter of the drafting evaluation")
struct InventedFactsTests {
    // MARK: - Faithful drafts

    @Test("A draft made only of the description's facts has no invented fact and keeps them all",
          arguments: DraftingInputs.written)
    func faithfulDraftIsClean(_ input: DraftingInput) {
        let report = InventedFacts.count(Draft(faithfulTo: input).cv, for: input)

        #expect(report.invented.isEmpty, "\(report.invented)")
        #expect(report.kept == input.facts)
        #expect(report.lost.isEmpty)
        #expect(report.findings.count == input.facts.count)
        #expect(report.findings.allSatisfy { $0.kind == .quote }, "\(report.findings)")
    }

    // MARK: - Name-like fields

    @Test("An employer the description lacks is one hard finding; the same draft with the employer quoted has none",
          arguments: [
              ("en-plain", "Harbour Freight"), ("it-plain", "Officine Rinaldi"), ("de-plain", "Bäckerei Vogt"),
              ("es-plain", "Talleres Gómez"), ("fr-plain", "Garage Moreau"), ("pt-plain", "Padaria Lisboeta"),
          ])
    func employerTheDescriptionLacks(_ id: String, _ employer: String) throws {
        let input = try Self.input(id)
        var draft = Draft(faithfulTo: input)
        draft.experience.append(Experience(title: "", company: employer))

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.map(\.path) == ["experience[2].company"])
        #expect(report.invented.first?.value == employer)

        let quoted = try #require(input.facts.first { $0.kind == .employer }).forms[0]
        draft.experience[2] = Experience(title: "", company: quoted)
        let quotedReport = InventedFacts.count(draft.cv, for: input)

        #expect(quotedReport.invented.isEmpty, "\(quotedReport.invented)")
        #expect(quotedReport.finding(at: "experience[2].company")?.kind == .quote)
    }

    @Test("Case and accents do not hide a quote", arguments: [
        AccentCase(input: "example-it", field: .school, value: "universita di bologna"),
        AccentCase(input: "fr-plain", field: .employer, value: "PATISSERIE BELLEVUE"),
        AccentCase(input: "de-traps", field: .school, value: "fachschule fur physiotherapie kassel"),
        AccentCase(input: "es-plain", field: .title, value: "Disenadora Grafica"),
        AccentCase(input: "pt-plain", field: .employer, value: "centro de saude de vale verde"),
        AccentCase(input: "en-traps", field: .employer, value: "GREENWAY CARE HOME"),
    ])
    func accentsAndCase(_ example: AccentCase) throws {
        let input = try Self.input(example.input)
        var draft = Draft(faithfulTo: input)
        switch example.field {
        case .school: draft.education = [Education(institution: example.value)]
        case .employer: draft.experience[1] = Experience(title: "", company: example.value)
        case .title: draft.title = example.value
        }

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.isEmpty, "\(report.invented)")
        #expect(report.findings.first { $0.value == example.value }?.kind == .quote)
        #expect(report.lost.isEmpty, "\(report.lost)")
    }

    @Test("A name-like field that is not a phrase of the description is a hard finding, whatever field holds it",
          arguments: DraftingInputs.languages)
    func nameLikeFieldsAreQuotesOrInvented(_ language: String) throws {
        let input = try Self.input("\(language)-plain")
        var draft = Draft(faithfulTo: input)
        draft.location = "Springfield"
        draft.education = [Education(degree: "PhD", institution: draft.education[0].institution)]
        draft.languages.append(Language(name: "Klingon"))
        draft.interests = ["Origami"]

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.map(\.path).sorted() == [
            "education[0].degree", "interests[0]", "languages[2].name", "personalInfo.location",
        ])
    }

    // MARK: - Traps

    @Test("A trap of the description is a hard finding wherever the draft holds it", arguments: TrapCase.all)
    func trapIsInvented(_ trap: TrapCase) {
        var draft = Draft(faithfulTo: trap.input)
        let path = trap.place(in: &draft)

        let report = InventedFacts.count(draft.cv, for: trap.input)

        #expect(report.invented.map(\.path) == [path], "\(report.invented)")
        #expect(report.invented.first?.reason.hasPrefix("trap") == true, "\(report.invented)")
    }

    @Test("The sister's language is found when the draft lists it, in English and in German",
          arguments: [("en-traps", "French"), ("de-traps", "Französisch")])
    func sistersLanguage(_ id: String, _ language: String) throws {
        let input = try Self.input(id)
        var draft = Draft(faithfulTo: input)
        draft.languages.append(Language(name: language, proficiency: .native))

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.map(\.path) == ["languages[2].name"])
    }

    // MARK: - Contact details

    @Test("The person's own email and phone are quotes; another email or number is a hard finding",
          arguments: DraftingInputs.languages)
    func contactDetails(_ language: String) throws {
        let input = try Self.input("\(language)-plain")
        let email = try #require(input.description.firstMatch(of: /[a-z.]+@example\.com/)).output
        let phone = try #require(input.description.firstMatch(of: /\+39 333 123 \d{4}/)).output
        var draft = Draft(faithfulTo: input)
        draft.email = String(email)
        draft.phone = String(phone)

        let own = InventedFacts.count(draft.cv, for: input)
        #expect(own.invented.isEmpty, "\(own.invented)")
        #expect(own.finding(at: "personalInfo.email")?.kind == .quote)
        #expect(own.finding(at: "personalInfo.phone")?.kind == .quote)

        draft.phone = String(phone.dropFirst(4))
        #expect(InventedFacts.count(draft.cv, for: input).finding(at: "personalInfo.phone")?.kind == .derived)

        draft.email = "someone@example.org"
        draft.phone = "+39 333 999 0000"
        let other = InventedFacts.count(draft.cv, for: input)
        #expect(other.invented.map(\.path) == ["personalInfo.email", "personalInfo.phone"])
    }

    // MARK: - Prose

    @Test("A number the description lacks in a summary is a hard finding", arguments: [
        ("en-plain", "Warehouse supervisor with 5 years of experience."),
        ("it-plain", "Cuoco con 5 anni di esperienza."),
        ("de-plain", "Elektriker mit 5 Jahren Erfahrung."),
        ("es-plain", "Diseñadora gráfica con 5 años de experiencia."),
        ("fr-plain", "Boulangère avec 5 ans d'expérience."),
        ("pt-plain", "Enfermeira com 5 anos de experiência."),
    ])
    func numberInSummary(_ id: String, _ summary: String) throws {
        let input = try Self.input(id)
        var draft = Draft(faithfulTo: input)
        draft.summary = summary

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.map(\.path) == ["summary"])
        #expect(report.invented.first?.reason.contains("5") == true, "\(report.invented)")
    }

    // German, where every noun has a capital, sends such a word to review (`InventedFactsFieldTests.germanCapitalGoesToReview`).
    @Test("A capitalised word the description lacks in prose is a hard finding; the clause alone goes to review",
          arguments: [
              ("en-plain", "where I plan the night shifts"),
              ("it-plain", "dove preparo i primi piatti"),
              ("es-plain", "donde diseño carteles y catálogos"),
              ("fr-plain", "où je prépare le pain et les viennoiseries"),
              ("pt-plain", "onde cuido de doentes da cirurgia"),
          ])
    func capitalisedWordInProse(_ id: String, _ clause: String) throws {
        let input = try Self.input(id)
        var draft = Draft(faithfulTo: input)
        draft.experience[0] = Experience(company: draft.experience[0].company, description: "\(clause) Halvorsen")

        let invented = InventedFacts.count(draft.cv, for: input)
        #expect(invented.invented.map(\.path) == ["experience[0].description"])
        #expect(invented.invented.first?.reason.contains("Halvorsen") == true, "\(invented.invented)")

        draft.experience[0] = Experience(company: draft.experience[0].company, achievements: [clause])
        let quoted = InventedFacts.count(draft.cv, for: input)
        #expect(quoted.invented.isEmpty, "\(quoted.invented)")
        #expect(quoted.toReview.map(\.path) == ["experience[0].achievements[0]"])
    }

    @Test("A sentence of prose made of the description's words goes to review, not to the count",
          arguments: DraftingInputs.languages)
    func proseGoesToReview(_ language: String) throws {
        let input = try Self.input("\(language)-plain")
        var draft = Draft(faithfulTo: input)
        let firstSentence = try #require(input.description.split(separator: ".").first)
        draft.summary = "\(firstSentence)."

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.isEmpty, "\(report.invented)")
        #expect(report.toReview.map(\.path) == ["summary"])
    }

    // MARK: - Levels, current job, null

    @Test("A level goes to review with the language or skill it belongs to, and is never counted",
          arguments: DraftingInputs.languages)
    func levelsGoToReview(_ language: String) throws {
        let input = try Self.input("\(language)-plain")
        var draft = Draft(faithfulTo: input)
        draft.languages[0] = Language(name: draft.languages[0].name, proficiency: .native)
        draft.languages[1] = Language(name: draft.languages[1].name, proficiency: .b2)
        draft.skills[0] = Skill(name: draft.skills[0].name, level: .expert)

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.isEmpty, "\(report.invented)")
        let native = try #require(report.finding(at: "languages[0].proficiency"))
        #expect(native.kind == .review)
        #expect(native.context == draft.languages[0].name)
        #expect(report.finding(at: "languages[1].proficiency")?.kind == .review)
        #expect(report.finding(at: "skills[0].level")?.context == draft.skills[0].name)
    }

    @Test("A current job goes to review with its job; the literal null is allowed", arguments: DraftingInputs.languages)
    func currentJobAndNull(_ language: String) throws {
        let input = try Self.input("\(language)-traps")
        var draft = Draft(faithfulTo: input)
        let company = draft.experience[0].company
        draft.experience[0] = Experience(title: "", company: company, location: "null", current: true)

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.isEmpty, "\(report.invented)")
        #expect(report.finding(at: "experience[0].current")?.kind == .review)
        #expect(report.finding(at: "experience[0].current")?.context?.contains(company) == true)
        #expect(report.finding(at: "experience[0].location")?.kind == .derived)
    }

    // MARK: - Lost facts

    @Test("A missing name, title or job is reported as lost", arguments: DraftingInputs.languages)
    func lostFacts(_ language: String) throws {
        let input = try Self.input("\(language)-traps")
        var draft = Draft(faithfulTo: input)
        draft.name = nil
        draft.title = nil
        draft.experience = []

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(!report.keeps(.name))
        #expect(!report.keeps(.title))
        #expect(!report.keeps(.employer))
        #expect(report.keeps(.school))
        #expect(report.lost == input.facts.filter { [.name, .title, .employer].contains($0.kind) })
        #expect(report.invented.isEmpty)
    }

    @Test("A fact is kept when a field of its kind holds one of its forms, and only then", arguments: DraftingInputs.languages)
    func keptByForm(_ language: String) throws {
        let input = try Self.input("\(language)-plain")
        var draft = Draft(faithfulTo: input)
        let title = try #require(input.facts.first { $0.kind == .title })
        draft.title = nil
        draft.experience[0] = Experience(title: title.forms.last ?? "", company: draft.experience[0].company)
        draft.skills = []

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.keeps(.title))
        #expect(report.lost == input.facts.filter { [.skill, .duty].contains($0.kind) })
    }

    // MARK: - Helpers

    static func input(_ id: String) throws -> DraftingInput {
        try #require(try DraftingInputs.all().first { $0.id == id }, "no input \(id)")
    }
}

// MARK: - Cases

/// A draft as plain values, so a test can change one field of the draft its input's facts make.
struct Draft {
    var name: String?
    var title: String?
    var email: String?
    var phone: String?
    var location: String?
    var summary: String?
    var experience: [Experience]
    var education: [Education]
    var skills: [Skill]
    var languages: [Language]
    var interests: [String] = []

    /// A draft that holds the input's facts and nothing else, each in its first form, a duty as a skill.
    init(faithfulTo input: DraftingInput) {
        func forms(_ kind: ExpectedFact.Kind) -> [String] { input.facts.filter { $0.kind == kind }.map { $0.forms[0] } }
        name = forms(.name).first
        title = forms(.title).first
        experience = forms(.employer).map { Experience(company: $0) }
        education = forms(.school).map { Education(institution: $0) }
        skills = (forms(.skill) + forms(.duty)).map { Skill(name: $0) }
        languages = forms(.language).map { Language(name: $0) }
    }

    var cv: CVData {
        CVData(
            personalInfo: PersonalInfo(name: name, email: email, phone: phone, location: location, title: title),
            summary: summary, experience: experience, education: education, skills: skills, languages: languages,
            interests: interests
        )
    }
}

struct AccentCase: Sendable, CustomTestStringConvertible {
    enum Field: Sendable { case school, employer, title }

    let input: String
    let field: Field
    let value: String

    var testDescription: String { "\(input): \(value)" }
}

/// A trap of a description, put in the field where a model would put it. The traps of each input come in one order:
/// another person's language, another person's email, a colleague, the colleague's employer, a wished title, a planned
/// language, a denied skill, two figures of the team.
struct TrapCase: Sendable, CustomTestStringConvertible {
    let input: DraftingInput
    let index: Int

    var trap: String { input.traps[index] }
    var testDescription: String { "\(input.id): \(trap)" }

    static let all: [TrapCase] = DraftingInputs.written.filter { $0.kind == .traps }.flatMap { input in
        input.traps.indices.map { TrapCase(input: input, index: $0) }
    }

    /// Puts the trap in the draft and returns the path of the field that holds it.
    func place(in draft: inout Draft) -> String {
        switch index {
        case 0, 5:
            draft.languages.append(Language(name: trap))
            return "languages[\(draft.languages.count - 1)].name"
        case 1:
            draft.email = trap
            return "personalInfo.email"
        case 2:
            draft.experience[0] = Experience(company: draft.experience[0].company, achievements: [trap])
            return "experience[0].achievements[0]"
        case 3:
            draft.experience.append(Experience(company: trap))
            return "experience[\(draft.experience.count - 1)].company"
        case 4:
            draft.title = trap
            return "personalInfo.title"
        case 6:
            draft.skills.append(Skill(name: trap))
            return "skills[\(draft.skills.count - 1)].name"
        default:
            draft.summary = trap
            return "summary"
        }
    }
}

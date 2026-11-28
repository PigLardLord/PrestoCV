import Testing
import Foundation
@testable import CVGeneratorAI

/// The CV as a whole: what survives a faithful draft, what a made-up one loses, and how entries are tidied.
@Suite("Sanitizer: whole drafts")
struct SanitizerEntryTests {
    private let sanitizer = CVDataSanitizer(lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

    @Test("A draft the description fully supports keeps what its clauses name, in each of the six languages of the example",
          arguments: faithfulExamples)
    func faithfulDraftKeepsWhatItsClausesName(example: FaithfulExample) throws {
        #expect(try sanitizer.sanitize(example.draft, against: example.description) == example.survivors)
    }

    @Test("What the faithful drafts lose is an achievement that is not a quote of the description; the summary written around the facts stays",
          arguments: faithfulExamples)
    func whatTheFaithfulDraftsLose(example: FaithfulExample) throws {
        let result = try sanitizer.sanitize(example.draft, against: example.description)
        let current = result.experience.first { $0.current }
        let past = result.experience.first { !$0.current }

        #expect(result.summary == example.draft.summary, "The summary states no fact of its own: it is written around the facts (ADR 0031)")
        #expect(current?.startDate == "2016", "The date stands in the clause with the school")
        #expect(current?.title == example.draft.experience[0].title, "The title is a quote, though it is stated in the sentence about the person")
        #expect(current?.achievements == (example.keepsAchievement ? example.draft.experience[0].achievements : []), "The achievement stays when it quotes the clause after the comma, from a verb")
        #expect(past?.startDate == "2012", "The years stand in a clause of nothing but time, next to the clause of the employer")
        #expect(past?.endDate == "2016")
        #expect(result.education.first?.degree == example.draft.education[0].degree)
        #expect(result.education.first?.endDate == "2012", "The year is in the clause after \"and\", of nothing but graduating and a year")
    }

    @Test("A draft made up around a one-line description loses everything but what the line says")
    func inventedDraftLosesItsInventions() throws {
        let invented = CVData(
            personalInfo: PersonalInfo(
                name: "Anna Bianchi", email: "anna.bianchi@example.com", phone: "+39 333 123 4567",
                location: "Rome", website: "annabianchi.dev", linkedin: "linkedin.com/in/annabianchi", title: "Senior nurse"
            ),
            summary: "A senior nurse with 12 years of experience. Reach her at anna.bianchi@example.com.",
            experience: [
                Experience(title: "Head nurse", company: "San Camillo Hospital", location: "Rome", startDate: "2010", endDate: "2022",
                           description: "Led a team of 40 nurses.", achievements: ["Cut waiting times by 35%"]),
            ],
            education: [Education(degree: "Nursing", institution: "Sapienza", startDate: "2004", endDate: "2007")],
            skills: [Skill(name: "Triage", level: .expert), Skill(name: "Wound care", level: .advanced)],
            languages: [Language(name: "English", proficiency: .c1), Language(name: "Italian", proficiency: .native)],
            certifications: [Certification(name: "BLS", issuer: "American Heart Association", date: "2019", url: "aha.org/bls")],
            interests: ["Painting", "Running"]
        )

        let result = try sanitizer.sanitize(invented, against: "I'm a nurse.")

        #expect(result == CVData())
    }

    @Test("Repeated entries are kept once, ignoring case and accents")
    func duplicatesAreRemoved() throws {
        let description = "Cook at Trattoria since 2020. Università di Bologna, Nursing. I know Swift, Italian (native). I hold BLS. Chess."
        let cvData = CVData(
            experience: [
                Experience(title: "Cook", company: "Trattoria", startDate: "2020"),
                Experience(title: "cook", company: "TRATTORIA"),
            ],
            education: [
                Education(degree: "Nursing", institution: "Università di Bologna"),
                Education(degree: "nursing", institution: "Universita di Bologna"),
            ],
            skills: [Skill(name: "Swift"), Skill(name: "swift")],
            languages: [Language(name: "Italian", proficiency: .native), Language(name: "italian", proficiency: .native)],
            certifications: [Certification(name: "BLS", issuer: nil), Certification(name: "bls")],
            interests: ["Chess", "chess", " Chess "]
        )

        let result = try sanitizer.sanitize(cvData, against: description)

        #expect(result.experience.count == 1)
        #expect(result.experience.first?.startDate == "2020")
        #expect(result.education.count == 1)
        #expect(result.skills == [Skill(name: "Swift")])
        #expect(result.languages == [Language(name: "Italian", proficiency: .native)])
        #expect(result.certifications.count == 1)
        #expect(result.interests == ["Chess"])
    }

    @Test("Blank values become absent and blank entries vanish")
    func blankValues() throws {
        let cvData = CVData(
            personalInfo: PersonalInfo(location: "  ", title: ""),
            summary: "   ",
            skills: [Skill(name: " ")],
            languages: [Language(name: "")],
            certifications: [Certification(name: " ")],
            interests: ["", "  "]
        )

        #expect(try sanitizer.sanitize(cvData, against: "anything at all") == CVData())
    }

    @Test("A character the reader cannot see, in a fact or a sentence of the draft, is left out of it: the draft keeps the rest")
    func hiddenCharactersLeftOut() throws {
        let example = faithfulExamples[0]
        let hidden = faithfulDraft(
            title: "primary\u{200B} school teacher", location: "Bolo\u{202E}gna",
            summary: "A caring\u{00AD} teacher who loves her pupils.", school: "Don Milani\u{E000} school",
            past: ("assistant", "nur\u{0007}sery"), achievement: "Trained 3 new\u{200B} teachers",
            degree: "Education\u{FEFF} Sciences", university: "University of Bologna",
            native: ("Italian", .native), english: "Eng\u{200F}lish", interests: ["chess", "hik\u{200D}ing"]
        )

        #expect(try sanitizer.sanitize(hidden, against: example.description) == example.survivors)
    }

    // MARK: - A title written as a clause (#359)

    /// A description of the input `pt-plain` of the evaluation, whose second job the model titled with the clause that names it.
    private static let nurseInPortuguese = "Chamo-me Beatriz Moura e sou enfermeira. Desde 2018 trabalho no Hospital da Ribeira, em Coimbra, onde cuido de doentes da cirurgia. De 2014 a 2018 trabalhei no Centro de Saúde de Vale Verde. Estudei na Escola Superior de Saúde do Mondego e terminei o curso em 2014."

    /// A sanitizer for a description in `language`, with no device data: only the rules of the sanitizer decide.
    private func sanitizer(in language: String) -> CVDataSanitizer {
        CVDataSanitizer(
            languageOfText: { _ in language },
            lexicalClasses: ForcedLexicalTagger([.english: .words([]), .german: .words([])]),
            wordList: TableWordList()
        )
    }

    private func job(_ title: String, at employer: String, from start: String?, to end: String?, current: Bool = false) -> CVData {
        CVData(experience: [Experience(title: title, company: employer, startDate: start, endDate: end, current: current)])
    }

    @Test("A title the model writes as the clause in which the person says they worked there gives no title: the job keeps its employer and its years (#359)",
          arguments: [
            (nurseInPortuguese, "trabalhei no Centro de Saúde de Vale Verde", "Centro de Saúde de Vale Verde", "pt"),
            ("Sono infermiera. Dal 2014 al 2018 ho lavorato all'Ospedale San Carlo.", "ho lavorato all'Ospedale San Carlo", "Ospedale San Carlo", "it"),
            ("Soy enfermera. De 2014 a 2018 trabajé en el Hospital Río Claro.", "trabajé en el Hospital Río Claro", "Hospital Río Claro", "es"),
            ("Je suis infirmière. De 2014 à 2018, j'ai travaillé à l'Hôpital Saint-Louis.", "j'ai travaillé à l'Hôpital Saint-Louis", "Hôpital Saint-Louis", "fr"),
            ("I am a nurse. From 2014 to 2018 I worked at St Mary's Hospital.", "I worked at St Mary's Hospital", "St Mary's Hospital", "en"),
            ("Ich bin Pflegerin. Von 2014 bis 2018 habe ich im Klinikum Erfurt gearbeitet.", "habe ich im Klinikum Erfurt gearbeitet", "Klinikum Erfurt", "de"),
          ])
    func clauseTitleKeepsTheJob(description: String, title: String, employer: String, language: String) throws {
        let result = try sanitizer(in: language).sanitize(job(title, at: employer, from: "2014", to: "2018"), against: description)

        #expect(result.experience.map(\.company) == [employer])
        #expect(result.experience.first?.title == "", "A clause is no title")
        #expect(result.experience.first?.startDate == "2014")
        #expect(result.experience.first?.endDate == "2018")
    }

    @Test("A duty the model writes as the title of a job is no title: the job stays, current from its year (#359)",
          arguments: [
            (nurseInPortuguese, "cuido de doentes da cirurgia", "Hospital da Ribeira", "pt"),
            ("Dal 2018 lavoro all'Ospedale San Carlo, dove curo i pazienti della chirurgia.", "curo i pazienti della chirurgia", "Ospedale San Carlo", "it"),
            ("Desde 2018 trabajo en el Hospital Río Claro, donde cuido a los pacientes de cirugía.", "cuido a los pacientes de cirugía", "Hospital Río Claro", "es"),
          ])
    func dutyTitleKeepsTheJob(description: String, title: String, employer: String, language: String) throws {
        let result = try sanitizer(in: language).sanitize(job(title, at: employer, from: "2018", to: nil, current: true), against: description)

        #expect(result.experience.map(\.company) == [employer])
        #expect(result.experience.first?.title == "", "A duty is no title")
        #expect(result.experience.first?.startDate == "2018")
        #expect(result.experience.first?.current == true)
    }

    @Test("A title the person states stays, even one that is written like a form of a verb (#359)",
          arguments: [
            ("Sou encarregado de carpintaria na Construtora Serra Azul desde 2020.", "encarregado de carpintaria", "Construtora Serra Azul", "pt"),
            ("Desde 2020 trabalho na Construtora Serra Azul, onde sou encarregado de carpintaria.", "encarregado de carpintaria", "Construtora Serra Azul", "pt"),
            ("Encarregado de carpintaria na Construtora Serra Azul desde 2020.", "encarregado de carpintaria", "Construtora Serra Azul", "pt"),
            ("Trabajo como encargada de tienda en la Panadería Sol desde 2020.", "encargada de tienda", "Panadería Sol", "es"),
            ("Je suis responsable de salle au Café Lumière depuis 2020.", "responsable de salle", "Café Lumière", "fr"),
            ("Je suis chargée de clientèle à la Banque Alpine depuis 2020.", "chargée de clientèle", "Banque Alpine", "fr"),
            ("Lavoro come addetta alle vendite alla Libreria Gialla dal 2020.", "addetta alle vendite", "Libreria Gialla", "it"),
            ("Since 2020 I have been lead developer at Northwind.", "lead developer", "Northwind", "en"),
          ])
    func statedTitleStays(description: String, title: String, employer: String, language: String) throws {
        let result = try sanitizer(in: language).sanitize(job(title, at: employer, from: "2020", to: nil, current: true), against: description)

        #expect(result.experience.map(\.title) == [title])
        #expect(result.experience.first?.startDate == "2020")
    }

    @Test("A job the person only wants, or denies, is still dropped when its title is the clause (#359)",
          arguments: [
            ("Sono infermiera. Vorrei lavorare all'Ospedale San Carlo.", "lavorare all'Ospedale San Carlo", "Ospedale San Carlo", "it"),
            ("Non ho mai lavorato all'Ospedale San Carlo.", "ho mai lavorato all'Ospedale San Carlo", "Ospedale San Carlo", "it"),
            ("Sou enfermeira. Quero trabalhar no Centro de Saúde de Vale Verde.", "trabalhar no Centro de Saúde de Vale Verde", "Centro de Saúde de Vale Verde", "pt"),
            ("I am a nurse. I would like to work at St Mary's Hospital.", "work at St Mary's Hospital", "St Mary's Hospital", "en"),
          ])
    func unclaimedClauseTitleDropsTheJob(description: String, title: String, employer: String, language: String) throws {
        let result = try sanitizer(in: language).sanitize(job(title, at: employer, from: nil, to: nil), against: description)

        #expect(result.experience.isEmpty)
    }

    @Test("A job kept without its clause title gets no year of another entry, and no title the description does not write (#359)")
    func clauseTitleLendsNoOtherYear() throws {
        let description = "Dal 2014 al 2018 ho lavorato all'Ospedale San Carlo. Nel 2019 mi sono laureata all'Università di Bari."
        let sanitizer = sanitizer(in: "it")

        let otherYear = try sanitizer.sanitize(job("ho lavorato all'Ospedale San Carlo", at: "Ospedale San Carlo", from: "2019", to: "2020"), against: description)
        let invented = try sanitizer.sanitize(job("caposala", at: "Ospedale San Carlo", from: "2014", to: "2018"), against: description)

        #expect(otherYear.experience.map(\.company) == ["Ospedale San Carlo"])
        #expect(otherYear.experience.first?.title == "")
        #expect(otherYear.experience.first?.startDate == nil, "2019 is the year of the degree")
        #expect(otherYear.experience.first?.endDate == nil, "2020 is in no clause")
        #expect(invented.experience.map(\.title) == [""], "The description writes no \"caposala\"")
    }
}

// MARK: - The app's example description, and a draft that says exactly what it says

/// One of the example descriptions the app shows, with the draft a faithful model would write from it.
struct FaithfulExample: Sendable, CustomTestStringConvertible {
    let language: String
    let description: String
    let draft: CVData
    /// Whether the draft's achievement quotes the clause after the comma, and begins with a verb of a CV. The German draft's
    /// begins with a number, and the Spanish and Portuguese drafts write the verb in the third person, as the description does
    /// not: they quote nothing.
    var keepsAchievement = true

    var testDescription: String { language }

    /// The draft as the sanitizer leaves it: the summary states no fact of its own, so it stays (ADR 0031); the achievement stays when it is a quote;
    /// everything else is a quote of a clause that backs its entry or of one that joins it (the years before the employer's
    /// clause, the year of the degree after "and").
    var survivors: CVData {
        let current = draft.experience[0]
        return CVData(
            personalInfo: draft.personalInfo,
            summary: draft.summary,
            experience: [
                Experience(
                    title: current.title, company: current.company, startDate: current.startDate, current: current.current,
                    achievements: keepsAchievement ? current.achievements : []
                ),
                draft.experience[1],
            ],
            education: [draft.education[0]],
            skills: draft.skills,
            languages: draft.languages,
            certifications: draft.certifications,
            interests: draft.interests
        )
    }
}

private func faithfulDraft(
    title: String, location: String, summary: String,
    school: String, past: (title: String, employer: String), achievement: String,
    degree: String, university: String,
    native: (name: String, level: LanguageProficiency), english: String,
    interests: [String]
) -> CVData {
    CVData(
        personalInfo: PersonalInfo(name: "Maria Rossi", location: location, title: title),
        summary: summary,
        experience: [
            Experience(title: title, company: school, startDate: "2016", current: true, achievements: [achievement]),
            Experience(title: past.title, company: past.employer, startDate: "2012", endDate: "2016"),
        ],
        education: [Education(degree: degree, institution: university, endDate: "2012")],
        languages: [
            Language(name: native.name, proficiency: native.level),
            Language(name: english, proficiency: .b2),
        ],
        interests: interests
    )
}

let faithfulExamples: [FaithfulExample] = [
    FaithfulExample(
        language: "en",
        description: "I'm Maria Rossi, a primary school teacher from Bologna. Since 2016 I have taught at the Don Milani school, where I trained 3 new teachers. Before that, from 2012 to 2016, I worked as an assistant in a nursery. I studied Education Sciences at the University of Bologna and graduated in 2012. I speak Italian (native) and English (B2). In my free time I like chess and hiking.",
        draft: faithfulDraft(
            title: "primary school teacher", location: "Bologna", summary: "A caring teacher who loves her pupils.",
            school: "Don Milani school", past: ("assistant", "nursery"), achievement: "Trained 3 new teachers",
            degree: "Education Sciences", university: "University of Bologna",
            native: ("Italian", .native), english: "English", interests: ["chess", "hiking"]
        )
    ),
    FaithfulExample(
        language: "it",
        description: "Sono Maria Rossi, insegnante di scuola primaria a Bologna. Dal 2016 insegno alla scuola Don Milani, dove ho formato 3 nuovi insegnanti. Prima, dal 2012 al 2016, ho lavorato come assistente in un asilo nido. Ho studiato Scienze della Formazione all'Università di Bologna e mi sono laureata nel 2012. Parlo italiano (madrelingua) e inglese (B2). Nel tempo libero mi piacciono gli scacchi e le escursioni.",
        draft: faithfulDraft(
            title: "insegnante di scuola primaria", location: "Bologna", summary: "Un'insegnante attenta ai suoi alunni.",
            school: "scuola Don Milani", past: ("assistente", "asilo nido"), achievement: "Formato 3 nuovi insegnanti",
            degree: "Scienze della Formazione", university: "Università di Bologna",
            native: ("italiano", .native), english: "inglese", interests: ["scacchi", "escursioni"]
        )
    ),
    FaithfulExample(
        language: "de",
        description: "Ich bin Maria Rossi, Grundschullehrerin aus Bologna. Seit 2016 unterrichte ich an der Schule Don Milani, wo ich 3 neue Lehrkräfte eingearbeitet habe. Davor habe ich von 2012 bis 2016 als Betreuerin in einer Kinderkrippe gearbeitet. Ich habe Erziehungswissenschaften an der Universität Bologna studiert und 2012 meinen Abschluss gemacht. Ich spreche Italienisch (Muttersprache) und Englisch (B2). In meiner Freizeit mag ich Schach und Wandern.",
        draft: faithfulDraft(
            title: "Grundschullehrerin", location: "Bologna", summary: "Eine engagierte Lehrerin.",
            school: "Schule Don Milani", past: ("Betreuerin", "Kinderkrippe"), achievement: "3 neue Lehrkräfte eingearbeitet",
            degree: "Erziehungswissenschaften", university: "Universität Bologna",
            native: ("Italienisch", .native), english: "Englisch", interests: ["Schach", "Wandern"]
        ),
        keepsAchievement: false
    ),
    FaithfulExample(
        language: "es",
        description: "Soy Maria Rossi, maestra de primaria en Bolonia. Desde 2016 enseño en la escuela Don Milani, donde formé a 3 nuevos maestros. Antes, de 2012 a 2016, trabajé como auxiliar en una guardería. Estudié Ciencias de la Educación en la Universidad de Bolonia y me gradué en 2012. Hablo italiano (nativo) e inglés (B2). En mi tiempo libre me gustan el ajedrez y el senderismo.",
        draft: faithfulDraft(
            title: "maestra de primaria", location: "Bolonia", summary: "Una maestra dedicada a sus alumnos.",
            school: "escuela Don Milani", past: ("auxiliar", "guardería"), achievement: "Formó a 3 nuevos maestros",
            degree: "Ciencias de la Educación", university: "Universidad de Bolonia",
            native: ("italiano", .native), english: "inglés", interests: ["ajedrez", "senderismo"]
        ),
        keepsAchievement: false
    ),
    FaithfulExample(
        language: "fr",
        description: "Je suis Maria Rossi, institutrice dans une école primaire de Bologne. Depuis 2016, j'enseigne à l'école Don Milani, où j'ai formé 3 nouveaux enseignants. Avant, de 2012 à 2016, j'ai travaillé comme assistante dans une crèche. J'ai étudié les sciences de l'éducation à l'université de Bologne et j'ai obtenu mon diplôme en 2012. Je parle italien (langue maternelle) et anglais (B2). Pendant mon temps libre, j'aime les échecs et la randonnée.",
        draft: faithfulDraft(
            title: "institutrice", location: "Bologne", summary: "Une institutrice dévouée à ses élèves.",
            school: "école Don Milani", past: ("assistante", "crèche"), achievement: "Formé 3 nouveaux enseignants",
            degree: "sciences de l'éducation", university: "université de Bologne",
            native: ("italien", .native), english: "anglais", interests: ["échecs", "randonnée"]
        )
    ),
    FaithfulExample(
        language: "pt",
        description: "Sou Maria Rossi, professora do ensino fundamental em Bolonha. Desde 2016 leciono na escola Don Milani, onde formei 3 novos professores. Antes, de 2012 a 2016, trabalhei como auxiliar em uma creche. Estudei Ciências da Educação na Universidade de Bolonha e me formei em 2012. Falo italiano (nativo) e inglês (B2). No meu tempo livre, gosto de xadrez e de caminhadas.",
        draft: faithfulDraft(
            title: "professora do ensino fundamental", location: "Bolonha", summary: "Uma professora dedicada aos seus alunos.",
            school: "escola Don Milani", past: ("auxiliar", "creche"), achievement: "Formou 3 novos professores",
            degree: "Ciências da Educação", university: "Universidade de Bolonha",
            native: ("italiano", .native), english: "inglês", interests: ["xadrez", "caminhadas"]
        ),
        keepsAchievement: false
    ),
]

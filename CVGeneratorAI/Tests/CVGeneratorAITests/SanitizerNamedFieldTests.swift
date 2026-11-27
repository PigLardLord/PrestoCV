import Testing
import Foundation
@testable import CVGeneratorAI

/// What an AI draft may name (people, employers, schools, titles, places, skills): only what the description names, as written.
@Suite("Sanitizer: a name must occur in the description as a phrase")
struct SanitizerNamedFieldTests {
    private let sanitizer = CVDataSanitizer()

    private func sanitized(_ cvData: CVData, from description: String) throws -> CVData {
        try sanitizer.sanitize(cvData, against: description)
    }

    // MARK: - The person's name

    @Test("A name is a contiguous phrase of the description, whatever its case or accents")
    func nameInTheDescription() throws {
        let info = PersonalInfo(name: "José Núñez")

        #expect(try sanitized(CVData(personalInfo: info), from: "i am JOSE NUNEZ, a chef").personalInfo.name == "José Núñez")
    }

    @Test("A name made of words that are only nearby in the description is dropped",
          arguments: [
            "I am John; my manager is Jane Smith",
            "I am John. Smith is my manager",
            "I am John, and Smith is my manager",
            "Smith hired John",
          ])
    func nameBuiltFromSeparateWords(description: String) throws {
        let result = try sanitized(CVData(personalInfo: PersonalInfo(name: "John Smith")), from: description)

        #expect(result.personalInfo.name == nil)
    }

    @Test("A name is a whole word, not the end of another")
    func nameInsideAnotherWord() throws {
        let result = try sanitized(CVData(personalInfo: PersonalInfo(name: "Anna")), from: "My daughter Joanna is a nurse")

        #expect(result.personalInfo.name == nil)
    }

    @Test("A name with a hyphen or an apostrophe matches however the apostrophe is typed")
    func nameWithPunctuation() throws {
        let info = PersonalInfo(name: "Jean-Luc D'Angelo")

        #expect(try sanitized(CVData(personalInfo: info), from: "My name is Jean-Luc D\u{2019}Angelo.").personalInfo.name == "Jean-Luc D'Angelo")
    }

    @Test("A name that is only a title is dropped: \"I'm a nurse\" is not a person called Nurse")
    func nameThatIsATitle() throws {
        let sparse = CVData(
            personalInfo: PersonalInfo(name: "Nurse", title: "Nurse"),
            experience: [Experience(title: "Nurse", company: "Hospital", startDate: "2020")]
        )

        let result = try sanitized(sparse, from: "I'm a nurse.")

        #expect(result.personalInfo.name == nil)
        #expect(result.personalInfo.title == "Nurse")
        #expect(try sanitized(CVData(personalInfo: PersonalInfo(name: "Cook", title: "nurse")), from: "I'm a nurse and a cook.").personalInfo.name == "Cook", "Only the person's own title is refused")
    }

    @Test("A name the model gives as a job title is dropped")
    func nameThatIsAJobTitle() throws {
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Head Nurse"),
            experience: [Experience(title: "head nurse", company: "San Raffaele")]
        )

        #expect(try sanitized(draft, from: "I was head nurse at San Raffaele").personalInfo.name == nil)
    }

    @Test("The word \"null\", which the model writes for an empty field, is empty, even if the description has the word")
    func nullWord() throws {
        let description = "The word null appears here, with null@example.com and null.example.com"
        let draft = CVData(
            personalInfo: PersonalInfo(name: "null", email: "NULL", phone: "null", location: "Null", title: "null"),
            summary: "null",
            skills: [Skill(name: "null")],
            interests: ["null"]
        )

        #expect(try sanitized(draft, from: description) == CVData())
    }

    /// A sanitizer for a description in `language`, with no device data: only the rules of the sanitizer decide.
    private func sanitizer(in language: String) -> CVDataSanitizer {
        CVDataSanitizer(
            languageOfText: { _ in language },
            lexicalClasses: ForcedLexicalTagger([.english: .words([]), .german: .words([])]),
            wordList: TableWordList()
        )
    }

    @Test("A pronoun, or a clause of the description, is no name: the name is empty, never the first words of the clause (#359)",
          arguments: [
            ("Ich", "Ich arbeite seit zehn Jahren als Tischler bei der Werkstatt Brandt in Suhl.", "de"),
            ("I", "I repair bicycles at the Wheelhouse in Leeds.", "en"),
            ("Io", "Io faccio la sarta a Lecce.", "it"),
            ("Yo", "Yo cocino en un restaurante de Sevilla.", "es"),
            ("Eu", "Eu trabalho numa padaria em Braga.", "pt"),
            ("Je", "Je suis menuisière à Lyon.", "fr"),
            ("I'm Tom Hartley", "I'm Tom Hartley and I repair bicycles in Leeds.", "en"),
            ("Je m'appelle Claire Moreau", "Je m'appelle Claire Moreau, je suis menuisière à Lyon.", "fr"),
            ("Lavoro come cuoco", "Lavoro come cuoco in una trattoria di Parma da molti anni.", "it"),
            ("Soy Pedro Gil", "Soy Pedro Gil y arreglo bicicletas en Zaragoza.", "es"),
            ("Trabalho há doze anos com serralharia, em obras e em oficinas de portões.",
             "Trabalho há doze anos com serralharia, em obras e em oficinas de portões. Gosto de pintar.", "pt"),
            ("Trabajo desde hace nueve años en la reparación de bicicletas de carretera.",
             "Trabajo desde hace nueve años en la reparación de bicicletas de carretera.", "es"),
            ("Arbeite seit zehn Jahren als Tischler bei der Werkstatt Brandt in Suhl",
             "Arbeite seit zehn Jahren als Tischler bei der Werkstatt Brandt in Suhl, in Thüringen, mit Holz.", "de"),
          ])
    func pronounOrClauseAsName(name: String, description: String, language: String) throws {
        let result = try sanitizer(in: language).sanitize(CVData(personalInfo: PersonalInfo(name: name)), against: description)

        #expect(result.personalInfo.name == nil)
    }

    @Test("A clause in which the person names themselves is no name: the name is empty (#359)",
          arguments: [
            ("Mi chiamo Giulia Bianchi", "Mi chiamo Giulia Bianchi e faccio la parrucchiera a Bari.", "it"),
            ("Il mio nome è Giulia Bianchi", "Il mio nome è Giulia Bianchi e faccio la parrucchiera a Bari.", "it"),
            ("Me llamo Pedro Gil", "Me llamo Pedro Gil y arreglo bicicletas en Zaragoza.", "es"),
            ("Mi nombre es Pedro Gil", "Mi nombre es Pedro Gil y arreglo bicicletas en Zaragoza.", "es"),
            ("Chamo-me Ana Costa", "Chamo-me Ana Costa e trabalho como cabeleireira em Braga.", "pt"),
            ("O meu nome é Ana Costa", "O meu nome é Ana Costa e trabalho como cabeleireira em Braga.", "pt"),
            ("My name is Tom Cook", "My name is Tom Cook and I repair bicycles in Leeds.", "en"),
            ("Mein Name ist Anna Müller", "Mein Name ist Anna Müller und ich arbeite als Gärtnerin in Erfurt.", "de"),
            ("Mon nom est Claire Moreau", "Mon nom est Claire Moreau et je suis menuisière à Lyon.", "fr"),
          ])
    func selfNamingClauseAsName(name: String, description: String, language: String) throws {
        let result = try sanitizer(in: language).sanitize(CVData(personalInfo: PersonalInfo(name: name)), against: description)

        #expect(result.personalInfo.name == nil)
    }

    @Test("A name stays, whatever its parts: a hyphen, a particle, an initial, a surname that is also a verb or a trade (#359)",
          arguments: [
            ("Maria da Silva", "Eu sou a Maria da Silva e trabalho como cabeleireira em Braga.", "pt"),
            ("Maria Fernanda de la Cruz Gómez", "Me llamo Maria Fernanda de la Cruz Gómez y soy electricista en Sevilla.", "es"),
            ("Jean-Pierre Dupont", "Je m'appelle Jean-Pierre Dupont et je suis menuisier à Lyon.", "fr"),
            ("José de la Cruz", "Me llamo José de la Cruz y soy electricista en Sevilla.", "es"),
            ("Anna-Lena Müller", "Ich heiße Anna-Lena Müller und arbeite als Gärtnerin in Erfurt.", "de"),
            ("Giulia Rossi", "Mi chiamo Giulia Rossi e faccio la parrucchiera a Bari.", "it"),
            ("Giulia Vivo", "Sono Giulia Vivo e faccio la sarta a Lecce.", "it"),
            ("J. Smith", "I am J. Smith, a florist in Leeds.", "en"),
            ("I. M. Calder", "I am I. M. Calder, an architect in Leeds.", "en"),
            ("Tom Cook", "My name is Tom Cook and I repair bicycles in Leeds.", "en"),
            ("Mia Rossi", "Mi chiamo Mia Rossi e faccio la sarta a Lecce.", "it"),
            ("Ma Lin", "Je m'appelle Ma Lin et je suis menuisière à Lyon.", "fr"),
            ("Ana Costa", "Chamo-me Ana Costa e trabalho como cabeleireira em Braga.", "pt"),
          ])
    func realNameStays(name: String, description: String, language: String) throws {
        let result = try sanitizer(in: language).sanitize(CVData(personalInfo: PersonalInfo(name: name)), against: description)

        #expect(result.personalInfo.name == name)
    }

    @Test("A name the description never mentions is dropped")
    func inventedName() throws {
        let result = try sanitized(CVData(personalInfo: PersonalInfo(name: "Mario Rossi")), from: "I'm a nurse in Turin")

        #expect(result.personalInfo.name == nil)
    }

    // MARK: - Titles and places

    @Test("The person's title and place are kept only if the description says them")
    func personalTitleAndLocation() throws {
        let info = PersonalInfo(location: "Bologna", title: "primary school teacher")
        let invented = PersonalInfo(location: "Milan", title: "head teacher")
        let description = "I'm a primary school teacher from Bologna"

        #expect(try sanitized(CVData(personalInfo: info), from: description).personalInfo.title == "primary school teacher")
        #expect(try sanitized(CVData(personalInfo: info), from: description).personalInfo.location == "Bologna")
        #expect(try sanitized(CVData(personalInfo: invented), from: description).personalInfo.title == nil)
        #expect(try sanitized(CVData(personalInfo: invented), from: description).personalInfo.location == nil)
    }

    @Test("A place wider than the one the description gives is dropped")
    func widerPlace() throws {
        let result = try sanitized(CVData(personalInfo: PersonalInfo(location: "Bologna, Italy")), from: "I live in Bologna")

        #expect(result.personalInfo.location == nil)
    }

    // MARK: - Jobs

    @Test("A job keeps the title, employer and place the description gives, and loses the ones it does not")
    func jobFields() throws {
        let description = "I worked as a cook at Trattoria Da Mario in Rome"
        let job = Experience(title: "cook", company: "Trattoria Da Mario", location: "Rome")
        let partlyInvented = Experience(title: "chef", company: "Trattoria Da Mario", location: "Milan")

        let result = try sanitized(CVData(experience: [job, partlyInvented]), from: description).experience

        #expect(result.map(\.title) == ["cook", ""])
        #expect(result.map(\.company) == ["Trattoria Da Mario", "Trattoria Da Mario"])
        #expect(result.map(\.location) == ["Rome", nil])
    }

    @Test("A job needs its employer, or its title together with a date")
    func jobNeedsAnEmployerOrADatedTitle() throws {
        let description = "I'm a cook. I cooked at Trattoria Da Mario. From 2016 to 2018 I was a baker. In 2019 I became a florist."
        let entries = [
            Experience(title: "cook", description: "Prepared meals.", achievements: ["Won an award"]),
            Experience(company: "Trattoria Da Mario"),
            Experience(title: "baker", startDate: "2016"),
            Experience(title: "florist", endDate: "2019"),
            Experience(title: "baker", description: "Baked bread."),
        ]

        let result = try sanitized(CVData(experience: entries), from: description).experience

        #expect(result.count == 3, "A title alone, with whatever the model made up around it, is not a job")
        #expect(result.map(\.company) == ["Trattoria Da Mario", "", ""])
        #expect(result.map(\.startDate) == [nil, "2016", nil])
        #expect(result.map(\.endDate) == [nil, nil, "2019"])
    }

    @Test("A job with no title or employer from the description is dropped, even if its place is right")
    func jobWithNothingIdentifying() throws {
        let invented = Experience(title: "head chef", company: "Ristorante Bellavista", location: "Rome", description: "Ran the kitchen.")

        let result = try sanitized(CVData(experience: [invented]), from: "I worked as a cook at Trattoria Da Mario in Rome")

        #expect(result.experience.isEmpty)
    }

    @Test("A title is a whole phrase: \"teacher\" is not found in \"teachers\"")
    func titleInsideAnotherWord() throws {
        let result = try sanitized(CVData(experience: [Experience(title: "teacher", company: "Don Milani")]), from: "I trained teachers at Don Milani")

        #expect(result.experience.map(\.title) == [""])
        #expect(result.experience.map(\.company) == ["Don Milani"])
    }

    // MARK: - Studies

    @Test("A degree and a school are kept only if the description names them; with neither left, the entry goes")
    func education() throws {
        let description = "I studied Education Sciences at the University of Bologna"
        let entries = [
            Education(degree: "Education Sciences", institution: "University of Bologna"),
            Education(degree: "Education Sciences", institution: "University of Padua"),
            Education(degree: "Master in Pedagogy", institution: "University of Padua"),
        ]

        let result = try sanitized(CVData(education: entries), from: description).education

        #expect(result.map(\.degree) == ["Education Sciences"], "A degree with a school the description lacks is found by its clause, which names the other school")
        #expect(result.map(\.institution) == ["University of Bologna"])
    }

    // MARK: - Certifications

    @Test("A certification needs its name in the description, and keeps its issuer only if that is there too")
    func certifications() throws {
        let description = "I hold the BLS from the American Heart Association"
        let entries = [
            Certification(name: "BLS", issuer: "American Heart Association"),
            Certification(name: "BLS", issuer: "Red Cross"),
            Certification(name: "ACLS", issuer: "American Heart Association"),
        ]

        let result = try sanitized(CVData(certifications: entries), from: description).certifications

        #expect(result.map(\.name) == ["BLS"], "The ACLS entry is gone, and the BLS entry whose issuer was invented is the same certificate")
        #expect(result.map(\.issuer) == ["American Heart Association"])
    }

    // MARK: - Skills and interests

    @Test("Skills and interests the description does not mention are dropped")
    func skillsAndInterests() throws {
        let description = "I know Swift and Python. In my free time I like chess and hiking."
        let cvData = CVData(
            skills: [Skill(name: "Swift"), Skill(name: "Java"), Skill(name: "python")],
            interests: ["chess", "Hiking", "Painting"]
        )

        let result = try sanitized(cvData, from: description)

        #expect(result.skills.map(\.name) == ["Swift", "python"])
        #expect(result.interests == ["chess", "Hiking"])
    }
}

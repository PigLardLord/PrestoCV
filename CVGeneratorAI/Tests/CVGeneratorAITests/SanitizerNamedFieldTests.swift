import Testing
import Foundation
@testable import CVGeneratorAI

/// What an AI draft may name (people, employers, schools, titles, places, skills): only what the description names, as written.
@Suite("Sanitizer: a name must occur in the description as a phrase")
struct SanitizerNamedFieldTests {
    private let sanitizer = CVDataSanitizer()

    private func sanitized(_ cvData: CVData, from description: String) -> CVData {
        sanitizer.sanitize(cvData, against: description)
    }

    // MARK: - The person's name

    @Test("A name is a contiguous phrase of the description, whatever its case or accents")
    func nameInTheDescription() {
        let info = PersonalInfo(name: "José Núñez")

        #expect(sanitized(CVData(personalInfo: info), from: "i am JOSE NUNEZ, a chef").personalInfo.name == "José Núñez")
    }

    @Test("A name made of words that are only nearby in the description is dropped",
          arguments: [
            "I am John; my manager is Jane Smith",
            "I am John. Smith is my manager",
            "I am John, and Smith is my manager",
            "Smith hired John",
          ])
    func nameBuiltFromSeparateWords(description: String) {
        let result = sanitized(CVData(personalInfo: PersonalInfo(name: "John Smith")), from: description)

        #expect(result.personalInfo.name == nil)
    }

    @Test("A name is a whole word, not the end of another")
    func nameInsideAnotherWord() {
        let result = sanitized(CVData(personalInfo: PersonalInfo(name: "Anna")), from: "My daughter Joanna is a nurse")

        #expect(result.personalInfo.name == nil)
    }

    @Test("A name with a hyphen or an apostrophe matches however the apostrophe is typed")
    func nameWithPunctuation() {
        let info = PersonalInfo(name: "Jean-Luc D'Angelo")

        #expect(sanitized(CVData(personalInfo: info), from: "My name is Jean-Luc D\u{2019}Angelo.").personalInfo.name == "Jean-Luc D'Angelo")
    }

    @Test("A name that is only a title is dropped: \"I'm a nurse\" is not a person called Nurse")
    func nameThatIsATitle() {
        let sparse = CVData(
            personalInfo: PersonalInfo(name: "Nurse", title: "Nurse"),
            experience: [Experience(title: "Nurse", company: "Hospital", startDate: "2020")]
        )

        let result = sanitized(sparse, from: "I'm a nurse.")

        #expect(result.personalInfo.name == nil)
        #expect(result.personalInfo.title == "Nurse")
        #expect(sanitized(CVData(personalInfo: PersonalInfo(name: "Cook", title: "nurse")), from: "I'm a nurse and a cook.").personalInfo.name == "Cook", "Only the person's own title is refused")
    }

    @Test("A name the model gives as a job title is dropped")
    func nameThatIsAJobTitle() {
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Head Nurse"),
            experience: [Experience(title: "head nurse", company: "San Raffaele")]
        )

        #expect(sanitized(draft, from: "I was head nurse at San Raffaele").personalInfo.name == nil)
    }

    @Test("The word \"null\", which the model writes for an empty field, is empty, even if the description has the word")
    func nullWord() {
        let description = "The word null appears here, with null@example.com and null.example.com"
        let draft = CVData(
            personalInfo: PersonalInfo(name: "null", email: "NULL", phone: "null", location: "Null", title: "null"),
            summary: "null",
            skills: [Skill(name: "null")],
            interests: ["null"]
        )

        #expect(sanitized(draft, from: description) == CVData())
    }

    @Test("A name the description never mentions is dropped")
    func inventedName() {
        let result = sanitized(CVData(personalInfo: PersonalInfo(name: "Mario Rossi")), from: "I'm a nurse in Turin")

        #expect(result.personalInfo.name == nil)
    }

    // MARK: - Titles and places

    @Test("The person's title and place are kept only if the description says them")
    func personalTitleAndLocation() {
        let info = PersonalInfo(location: "Bologna", title: "primary school teacher")
        let invented = PersonalInfo(location: "Milan", title: "head teacher")
        let description = "I'm a primary school teacher from Bologna"

        #expect(sanitized(CVData(personalInfo: info), from: description).personalInfo.title == "primary school teacher")
        #expect(sanitized(CVData(personalInfo: info), from: description).personalInfo.location == "Bologna")
        #expect(sanitized(CVData(personalInfo: invented), from: description).personalInfo.title == nil)
        #expect(sanitized(CVData(personalInfo: invented), from: description).personalInfo.location == nil)
    }

    @Test("A place wider than the one the description gives is dropped")
    func widerPlace() {
        let result = sanitized(CVData(personalInfo: PersonalInfo(location: "Bologna, Italy")), from: "I live in Bologna")

        #expect(result.personalInfo.location == nil)
    }

    // MARK: - Jobs

    @Test("A job keeps the title, employer and place the description gives, and loses the ones it does not")
    func jobFields() {
        let description = "I worked as a cook at Trattoria Da Mario in Rome"
        let job = Experience(title: "cook", company: "Trattoria Da Mario", location: "Rome")
        let partlyInvented = Experience(title: "chef", company: "Trattoria Da Mario", location: "Milan")

        let result = sanitized(CVData(experience: [job, partlyInvented]), from: description).experience

        #expect(result.map(\.title) == ["cook", ""])
        #expect(result.map(\.company) == ["Trattoria Da Mario", "Trattoria Da Mario"])
        #expect(result.map(\.location) == ["Rome", nil])
    }

    @Test("A job needs its employer, or its title together with a date")
    func jobNeedsAnEmployerOrADatedTitle() {
        let description = "I'm a cook. I cooked at Trattoria Da Mario. From 2016 to 2018 I was a baker. In 2019 I became a florist."
        let entries = [
            Experience(title: "cook", description: "Prepared meals.", achievements: ["Won an award"]),
            Experience(company: "Trattoria Da Mario"),
            Experience(title: "baker", startDate: "2016"),
            Experience(title: "florist", endDate: "2019"),
            Experience(title: "baker", description: "Baked bread."),
        ]

        let result = sanitized(CVData(experience: entries), from: description).experience

        #expect(result.count == 3, "A title alone, with whatever the model made up around it, is not a job")
        #expect(result.map(\.company) == ["Trattoria Da Mario", "", ""])
        #expect(result.map(\.startDate) == [nil, "2016", nil])
        #expect(result.map(\.endDate) == [nil, nil, "2019"])
    }

    @Test("A job with no title or employer from the description is dropped, even if its place is right")
    func jobWithNothingIdentifying() {
        let invented = Experience(title: "head chef", company: "Ristorante Bellavista", location: "Rome", description: "Ran the kitchen.")

        let result = sanitized(CVData(experience: [invented]), from: "I worked as a cook at Trattoria Da Mario in Rome")

        #expect(result.experience.isEmpty)
    }

    @Test("A title is a whole phrase: \"teacher\" is not found in \"teachers\"")
    func titleInsideAnotherWord() {
        let result = sanitized(CVData(experience: [Experience(title: "teacher", company: "Don Milani")]), from: "I trained teachers at Don Milani")

        #expect(result.experience.map(\.title) == [""])
        #expect(result.experience.map(\.company) == ["Don Milani"])
    }

    // MARK: - Studies

    @Test("A degree and a school are kept only if the description names them; with neither left, the entry goes")
    func education() {
        let description = "I studied Education Sciences at the University of Bologna"
        let entries = [
            Education(degree: "Education Sciences", institution: "University of Bologna"),
            Education(degree: "Education Sciences", institution: "University of Padua"),
            Education(degree: "Master in Pedagogy", institution: "University of Padua"),
        ]

        let result = sanitized(CVData(education: entries), from: description).education

        #expect(result.map(\.degree) == ["Education Sciences"], "A degree with a school the description lacks is found by its clause, which names the other school")
        #expect(result.map(\.institution) == ["University of Bologna"])
    }

    // MARK: - Certifications

    @Test("A certification needs its name in the description, and keeps its issuer only if that is there too")
    func certifications() {
        let description = "I hold the BLS from the American Heart Association"
        let entries = [
            Certification(name: "BLS", issuer: "American Heart Association"),
            Certification(name: "BLS", issuer: "Red Cross"),
            Certification(name: "ACLS", issuer: "American Heart Association"),
        ]

        let result = sanitized(CVData(certifications: entries), from: description).certifications

        #expect(result.map(\.name) == ["BLS"], "The ACLS entry is gone, and the BLS entry whose issuer was invented is the same certificate")
        #expect(result.map(\.issuer) == ["American Heart Association"])
    }

    // MARK: - Skills and interests

    @Test("Skills and interests the description does not mention are dropped")
    func skillsAndInterests() {
        let description = "I know Swift and Python. In my free time I like chess and hiking."
        let cvData = CVData(
            skills: [Skill(name: "Swift"), Skill(name: "Java"), Skill(name: "python")],
            interests: ["chess", "Hiking", "Painting"]
        )

        let result = sanitized(cvData, from: description)

        #expect(result.skills.map(\.name) == ["Swift", "python"])
        #expect(result.interests == ["chess", "Hiking"])
    }
}

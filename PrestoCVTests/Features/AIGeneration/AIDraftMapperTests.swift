import Testing
import Foundation
import CVGeneratorAI
@testable import PrestoCV
@testable import PrestoCVCore

@Suite("AIDraftMapper Tests")
struct AIDraftMapperTests {
    /// Words that appear nowhere in the mapper, so a test fails if it falls back to English.
    private let labels = AIDraftLabels(present: "Oggi", untitled: "Nuovo CV", cvNameFormat: "CV di %@")

    private func map(_ cvData: CVData, writtenIn description: String = "A description.", language: String? = nil) -> CVModel {
        AIDraftMapper(labels: labels, languageOfText: { _ in language }).map(cvData, writtenIn: description)
    }

    // MARK: - CV name and personal info

    @Test("The CV is named after the person with the injected format")
    func cvNameUsesTheFormat() {
        let cv = map(CVData(personalInfo: CVGeneratorAI.PersonalInfo(name: "Maria Rossi")))

        #expect(cv.name == "CV di Maria Rossi")
        #expect(cv.personalInfo.name == "Maria Rossi")
    }

    @Test("Without a name the CV gets the untitled label", arguments: [nil, "", "   "] as [String?])
    func cvNameFallsBackToUntitled(name: String?) {
        let cv = map(CVData(personalInfo: CVGeneratorAI.PersonalInfo(name: name)))

        #expect(cv.name == "Nuovo CV")
    }

    @Test("Personal fields are copied and the summary becomes the profile")
    func personalInfoIsMapped() {
        let info = CVGeneratorAI.PersonalInfo(
            name: "Maria Rossi",
            email: "maria@example.com",
            phone: "+39 333 123 4567",
            location: "Bologna",
            website: "mariarossi.dev",
            title: "Teacher"
        )

        let cv = map(CVData(personalInfo: info, summary: "A teacher from Bologna."))

        #expect(cv.personalInfo == PrestoCVCore.PersonalInfo(
            name: "Maria Rossi",
            title: "Teacher",
            location: "Bologna",
            email: "maria@example.com",
            phone: "+39 333 123 4567",
            portfolio: "mariarossi.dev",
            profile: "A teacher from Bologna."
        ))
    }

    @Test("Missing personal fields are empty, not placeholders")
    func missingPersonalFieldsAreEmpty() {
        let cv = map(CVData(summary: "Hi there."))

        #expect(cv.personalInfo == PrestoCVCore.PersonalInfo(profile: "Hi there."))
    }

    // MARK: - Social links

    @Test("LinkedIn and GitHub become social links; the website is the portfolio")
    func socialLinks() {
        let info = CVGeneratorAI.PersonalInfo(website: "mariarossi.dev", linkedin: "linkedin.com/in/maria", github: "github.com/maria")

        let cv = map(CVData(personalInfo: info))

        #expect(cv.social.map(\.platform) == ["LinkedIn", "GitHub"])
        #expect(cv.social.map(\.url) == ["linkedin.com/in/maria", "github.com/maria"])
        #expect(cv.personalInfo.portfolio == "mariarossi.dev")
    }

    @Test("Empty social values are never added")
    func emptySocialLinksAreSkipped() {
        let info = CVGeneratorAI.PersonalInfo(linkedin: "  ", github: nil)

        #expect(map(CVData(personalInfo: info)).social.isEmpty)
    }

    // MARK: - Experience

    @Test("An experience's period reads start – end")
    func periodWithStartAndEnd() {
        let experience = CVGeneratorAI.Experience(title: "Cook", startDate: "2012", endDate: "2016")

        #expect(map(CVData(experience: [experience])).relevant_experience.first?.period == "2012 – 2016")
    }

    @Test("A current job without an end date ends with the injected word, never an English one")
    func currentJobUsesThePresentLabel() {
        let experience = CVGeneratorAI.Experience(title: "Cook", startDate: "2016", current: true)

        let period = map(CVData(experience: [experience])).relevant_experience.first?.period

        #expect(period == "2016 – Oggi")
    }

    @Test("A stated end date always wins over the present")
    func endDateBeatsPresent() {
        let experience = CVGeneratorAI.Experience(title: "Cook", startDate: "2012", endDate: "2016", current: true)

        let period = map(CVData(experience: [experience])).relevant_experience.first?.period

        #expect(period == "2012 – 2016")
    }

    @Test("A single known date stands alone", arguments: [
        ("2012", nil, "2012"),
        (nil, "2016", "2016"),
        (nil, nil, ""),
    ] as [(String?, String?, String)])
    func periodWithOneOrNoDate(start: String?, end: String?, expected: String) {
        let experience = CVGeneratorAI.Experience(title: "Cook", startDate: start, endDate: end)

        #expect(map(CVData(experience: [experience])).relevant_experience.first?.period == expected)
    }

    @Test("A current job without a start date still says it is current")
    func currentJobWithoutStart() {
        let experience = CVGeneratorAI.Experience(title: "Cook", current: true)

        #expect(map(CVData(experience: [experience])).relevant_experience.first?.period == "Oggi")
    }

    @Test("The description is followed by one bullet line per achievement")
    func experienceDescriptionWithAchievements() {
        let experience = CVGeneratorAI.Experience(
            title: "Teacher",
            company: "Scuola Don Milani",
            location: "Bologna",
            description: "Teaches primary school.",
            achievements: ["Trained 3 new teachers", "Ran the chess club"]
        )

        let mapped = map(CVData(experience: [experience])).relevant_experience.first

        #expect(mapped?.title == "Teacher")
        #expect(mapped?.company == "Scuola Don Milani")
        #expect(mapped?.location == "Bologna")
        #expect(mapped?.description == "Teaches primary school.\n• Trained 3 new teachers\n• Ran the chess club")
    }

    @Test("Without a description the bullets stand alone, and with neither it is empty")
    func experienceDescriptionVariants() {
        let onlyBullets = CVGeneratorAI.Experience(title: "A", achievements: ["Did x"])
        let nothing = CVGeneratorAI.Experience(title: "B")

        let mapped = map(CVData(experience: [onlyBullets, nothing])).relevant_experience

        #expect(mapped.map(\.description) == ["• Did x", ""])
    }

    @Test("No English headings are added to a description")
    func noEnglishHeadings() {
        let experience = CVGeneratorAI.Experience(title: "Teacher", description: "Teaches.", achievements: ["Did x"])

        let description = map(CVData(experience: [experience])).relevant_experience.first?.description ?? ""

        #expect(!description.contains("Key Achievements"))
        #expect(!description.contains("Technologies"))
    }

    // MARK: - Education

    @Test("An education entry keeps its description only, with its own period")
    func educationIsMapped() {
        let education = CVGeneratorAI.Education(
            degree: "Education Sciences",
            institution: "University of Bologna",
            startDate: "2008",
            endDate: "2012",
            description: "Thesis on play."
        )

        let mapped = map(CVData(education: [education])).education.first

        #expect(mapped?.degree == "Education Sciences")
        #expect(mapped?.school == "University of Bologna")
        #expect(mapped?.period == "2008 – 2012")
        #expect(mapped?.description == "Thesis on play.")
    }

    // MARK: - Skills and languages

    @Test("Skill levels map to stars, and no level is no stars", arguments: [
        (nil, 0),
        (SkillLevel.beginner, 1),
        (.intermediate, 3),
        (.advanced, 4),
        (.expert, 5),
    ] as [(SkillLevel?, Int)])
    func skillLevelsMapToStars(level: SkillLevel?, stars: Int) {
        let cv = map(CVData(skills: [CVGeneratorAI.Skill(name: "Chess", level: level)]))

        #expect(cv.skills.first?.name == "Chess")
        #expect(cv.skills.first?.level == stars)
    }

    @Test("Every language level maps to its own level", arguments: [
        (LanguageProficiency.a1, LanguageProficiencyLevel.a1),
        (.a2, .a2),
        (.b1, .b1),
        (.b2, .b2),
        (.c1, .c1),
        (.c2, .c2),
        (.native, .native),
    ] as [(LanguageProficiency, LanguageProficiencyLevel)])
    func languageLevelsMap(proficiency: LanguageProficiency, expected: LanguageProficiencyLevel) {
        let cv = map(CVData(languages: [CVGeneratorAI.Language(name: "Italian", proficiency: proficiency)]))

        #expect(cv.languages.first?.level == expected)
    }

    @Test("A language given without a level is skipped")
    func languageWithoutLevelIsSkipped() {
        let languages = [
            CVGeneratorAI.Language(name: "Italian", proficiency: .native),
            CVGeneratorAI.Language(name: "French"),
        ]

        let cv = map(CVData(languages: languages))

        #expect(cv.languages.map(\.name) == ["Italian"])
    }

    // MARK: - Certifications and interests

    @Test("A certification takes its year from a free-form date and carries no credential id")
    func certificationIsMapped() {
        let certification = CVGeneratorAI.Certification(name: "BLS", issuer: "AHA", date: "June 2020", url: "aha.org/bls")

        let mapped = map(CVData(certifications: [certification])).certifications.first

        #expect(mapped?.name == "BLS")
        #expect(mapped?.issuer == "AHA")
        #expect(mapped?.year == 2020)
        #expect(mapped?.url == "aha.org/bls")
        #expect(mapped?.description == "")
    }

    @Test("A certification without a date or issuer has year 0 and no issuer")
    func certificationWithoutDate() {
        let mapped = map(CVData(certifications: [CVGeneratorAI.Certification(name: "BLS")])).certifications.first

        #expect(mapped?.year == 0)
        #expect(mapped?.issuer == "")
    }

    @Test("Interests are trimmed and deduplicated")
    func interestsAreCleaned() {
        let cv = map(CVData(interests: [" Chess ", "chess", "", "Hiking"]))

        #expect(cv.interests == ["Chess", "Hiking"])
    }

    // MARK: - From the description to the CV

    @Test("A job the description puts in the past does not say Present because another statement says \"now\"")
    func borrowedPresentIsNotPrinted() throws {
        let description = "I paint now, I worked at Acme in 2012."
        let job = CVGeneratorAI.Experience(title: "", company: "Acme", startDate: "2012", current: true)

        let draft = try CVDataSanitizer(lexicalClasses: FakeLexicalTagger.english).sanitize(CVData(experience: [job]), against: description)

        #expect(map(draft, writtenIn: description).relevant_experience.map(\.period) == ["2012"])
    }

    @Test("A job the description says goes on now prints the injected word for the present")
    func statedPresentIsPrinted() throws {
        let description = "Currently, I work at Acme since 2012."
        let job = CVGeneratorAI.Experience(title: "", company: "Acme", startDate: "2012", current: true)

        let draft = try CVDataSanitizer(lexicalClasses: FakeLexicalTagger.english).sanitize(CVData(experience: [job]), against: description)

        #expect(map(draft, writtenIn: description).relevant_experience.map(\.period) == ["2012 – Oggi"])
    }

    @Test("A job does not print the dates of another job that has the same title")
    func borrowedDatesAreNotPrinted() throws {
        let description = "Nurse at Acme 2012–2016. Nurse at Beta 2019–2023, trained 3 nurses."
        let acme = CVGeneratorAI.Experience(title: "nurse", company: "Acme", startDate: "2012", endDate: "2023", current: true, achievements: ["Trained 3 nurses"])
        let beta = CVGeneratorAI.Experience(title: "nurse", company: "Beta", startDate: "2019", endDate: "2023", achievements: ["Trained 3 nurses"])

        let draft = try CVDataSanitizer(lexicalClasses: FakeLexicalTagger.english).sanitize(CVData(experience: [acme, beta]), against: description)

        let cv = map(draft, writtenIn: description)
        #expect(cv.relevant_experience.map(\.period) == ["2012", "2019 – 2023"])
        #expect(cv.relevant_experience.map(\.description) == ["", "• Trained 3 nurses"], "The 3 is in the clause after the comma, which joins the clause of Beta that it follows, and not Acme's")
    }

    // MARK: - Document language

    @Test("The CV is printed in the language of the description when a template supports it", arguments: [
        ("en", "en"), ("it", "it"), ("de", "de"), ("es", "es"), ("fr", "fr"), ("pt", "pt"),
        ("pt-BR", "pt"), ("en-GB", "en"),
    ])
    func documentLanguageIsTheDescriptionLanguage(tag: String, expected: String) {
        let cv = map(CVData(summary: "Hi."), language: tag)

        #expect(cv.documentLanguage == expected)
    }

    @Test("A language without templates, or an unknown one, leaves the document language to the app", arguments: [nil, "ja", "zh-Hans", "und", ""] as [String?])
    func unsupportedLanguageFollowsTheApp(tag: String?) {
        let cv = map(CVData(summary: "Hi."), language: tag)

        #expect(cv.documentLanguage == nil)
    }

    @Test("The mapper asks about the person's own text")
    func detectorReceivesTheDescription() {
        var received: [String] = []
        let mapper = AIDraftMapper(labels: labels, languageOfText: { text in
            received.append(text)
            return nil
        })

        _ = mapper.map(CVData(summary: "Generated summary."), writtenIn: "Sono infermiera.")

        #expect(received == ["Sono infermiera."])
    }

    // MARK: - Identity

    @Test("Every entry gets its own id")
    func entriesHaveDistinctIds() {
        let cv = map(CVData(
            experience: [CVGeneratorAI.Experience(title: "A"), CVGeneratorAI.Experience(title: "B")],
            education: [CVGeneratorAI.Education(degree: "C")]
        ))

        let ids = cv.relevant_experience.map(\.id) + cv.education.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}

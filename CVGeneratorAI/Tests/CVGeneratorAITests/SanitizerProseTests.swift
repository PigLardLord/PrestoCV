import Testing
import Foundation
@testable import CVGeneratorAI

/// What an AI draft may write in free text (summary, role and study descriptions, achievements) is quoted from the description
/// (ADR 0023): a sentence stays only if each of its clauses quotes a clause of the description (a clause that backs its entry, for
/// the text of an entry), it states no address the description lacks, and a summary holds no number.
@Suite("Sanitizer: prose keeps no claim the description cannot back")
struct SanitizerProseTests {
    private let sanitizer = CVDataSanitizer()

    private func summary(_ summary: String, from description: String) throws -> String? {
        try sanitizer.sanitize(CVData(summary: summary), against: description).summary
    }

    private func roleDescription(_ text: String, from description: String) throws -> String? {
        let job = Experience(title: "nurse", company: "San Raffaele", startDate: "2016", description: text)
        return try sanitizer.sanitize(CVData(experience: [job]), against: description).experience.first?.description
    }

    private let description = "I'm a nurse in Turin. At San Raffaele I trained 3 new nurses and I work nights."
    private let roleSource = "I worked at San Raffaele for 12 years."

    // MARK: - The summary

    @Test("A sentence with a number is dropped from a summary, even one the description writes; the others stay")
    func inventedNumberInTheSummary() throws {
        let text = "A nurse in Turin. Over 10 years of experience. Trained 3 new nurses."

        #expect(try summary(text, from: description) == "A nurse in Turin.")
    }

    @Test("A sentence with a year is dropped from a summary")
    func inventedYear() throws {
        #expect(try summary("A nurse in Turin since 2016. A nurse in Turin.", from: description) == "A nurse in Turin.")
        #expect(try summary("A nurse in Turin since 2016. At the hospital since 2012.", from: description) == nil)
    }

    @Test("A sentence with an email, a link or a phone number the description lacks is dropped")
    func inventedContactInProse() throws {
        let given = "I'm a nurse in Turin. Write to me at nurse@example.com, call 333 123 4567 or see example.com/nurse."
        let text = """
        A nurse in Turin. Write to nurse@invented.com. See invented.dev/nurse. Call 333 999 8888. \
        See www.hospital.example.org.
        """

        #expect(try summary(text, from: given) == "A nurse in Turin.")
    }

    @Test("A sentence with a contact detail the description does give stays, unless the detail is a number: a summary holds none")
    func givenContactInProse() throws {
        let given = "I'm a nurse. Write to me at nurse@example.com, call 333 123 4567 or see nurse.example.com/cv."
        let text = "Write to me at nurse@example.com. Call 333 123 4567. See https://www.nurse.example.com/cv/"

        #expect(try summary(text, from: given) == "Write to me at nurse@example.com. See https://www.nurse.example.com/cv/")
    }

    @Test("A sentence with an address that is not a whole email or link is dropped, even if the description has the same")
    func ambiguousAddressInProse() throws {
        let given = "I'm a nurse. Write to sam!anna@example.com or see:example.com or https://example.com?user=alice."

        #expect(try summary("A nurse. Write to anna@example.com.", from: given) == "A nurse.")
        #expect(try summary("A nurse. Write to sam!anna@example.com.", from: given) == "A nurse.")
        #expect(try summary("A nurse. Write to example.com.", from: given) == "A nurse.")
        #expect(try summary("A nurse. Write to see:example.com.", from: given) == "A nurse.")
        #expect(try summary("A nurse. Write to https://example.com?user=alice.", from: given) == "A nurse. Write to https://example.com?user=alice.")
    }

    @Test("A paraphrase is dropped: its words are not the description's")
    func paraphraseIsDropped() throws {
        let text = "A caring professional who looks after patients through the night."

        #expect(try summary(text, from: description) == nil)
    }

    @Test("A summary of nothing but invented claims is dropped altogether")
    func summaryWithNothingLeft() throws {
        #expect(try summary("Over 20 years in nursing. Led 12 nurses.", from: description) == nil)
        #expect(try summary("   ", from: description) == nil)
    }

    @Test("A number must be written as the description writes it: 35 is not 3.5, 1000 is not 1.000",
          arguments: [
            // (what the description writes, what the draft claims, whether it stays)
            ("3.5 years", "Worked at San Raffaele for 3.5 years.", true),
            ("3.5 years", "Worked at San Raffaele for 3,5 years.", true),
            ("3.5 years", "Worked at San Raffaele for 35 years.", false),
            ("35 years", "Worked at San Raffaele for 3.5 years.", false),
            ("4.5 years", "Worked at San Raffaele for 3.5 years.", false),
            ("1.000 days", "Worked at San Raffaele for 1.000 days.", true),
            ("1.000 days", "Worked at San Raffaele for 1,000 days.", true),
            ("1,000 days", "Worked at San Raffaele for 1.000 days.", true),
            ("1.000 days", "Worked at San Raffaele for 1000 days.", false),
            ("1000 days", "Worked at San Raffaele for 1.000 days.", false),
            ("1000 days", "Worked at San Raffaele for 1,000 days.", false),
            ("1000 days", "Worked at San Raffaele for 1000 days.", true),
          ] as [(String, String, Bool)])
    func numbersAreComparedAsWritten(given: String, claimed: String, stays: Bool) throws {
        let source = "I worked at San Raffaele for \(given)."

        #expect((try roleDescription(claimed, from: source) == claimed) == stays)
    }

    @Test("Digits of any script count as the same digits",
          arguments: ["９９", "٩٩", "९९"])
    func unicodeDigits(digits: String) throws {
        #expect(try summary("Trained 99 people.", from: "I'm a nurse.") == nil)
        #expect(try summary("Trained \(digits) people.", from: "I'm a nurse.") == nil, "Written in another script, it is still an invented number")
        #expect(try roleDescription("Worked at San Raffaele for 99 years.", from: "I worked at San Raffaele for \(digits) years.") == "Worked at San Raffaele for 99 years.")
        #expect(try roleDescription("Worked at San Raffaele for \(digits) years.", from: "I worked at San Raffaele for 99 years.") == "Worked at San Raffaele for \(digits) years.", "Kept prose stays as written")
        #expect(try roleDescription("Worked at San Raffaele for \(digits) years.", from: "I worked at San Raffaele for 98 years.") == nil)
    }

    @Test("A year written in other digits is still a year of the description")
    func yearInOtherDigits() throws {
        let given = "I was a nurse at San Raffaele from 2015"

        let result = try sanitizer.sanitize(CVData(experience: [Experience(title: "nurse", company: "San Raffaele", startDate: "２０１５", endDate: "２０１９")]), against: given)

        #expect(result.experience.first?.startDate == "2015", "Written with 0-9")
        #expect(result.experience.first?.endDate == nil)
    }

    @Test("A date range is not mistaken for a phone number")
    func dateRangeIsNotAPhoneNumber() throws {
        let given = "I worked as a nurse at San Raffaele 2012-2016"

        #expect(try roleDescription("Worked as a nurse at San Raffaele 2012-2016.", from: given) == "Worked as a nurse at San Raffaele 2012-2016.")
    }

    @Test("A full stop inside a number or an address does not end a sentence")
    func fullStopInsideTokens() throws {
        #expect(try roleDescription("Worked at San Raffaele for 4.5 years. Worked at San Raffaele for 4.5 years.", from: "I worked at San Raffaele for 4.5 years.") == "Worked at San Raffaele for 4.5 years. Worked at San Raffaele for 4.5 years.")
        #expect(try summary("A nurse. See nurse.example.com. A nurse.", from: "I'm a nurse, see nurse.example.com") == "A nurse. See nurse.example.com. A nurse.")
    }

    // MARK: - The language of the description

    /// A detector that knows the language of a few texts and is unsure of the rest.
    private func sanitizer(languages: [String: String]) -> CVDataSanitizer {
        CVDataSanitizer(languageOfText: { text in languages[text] })
    }

    @Test("Prose in another language than the description's is dropped, sentence by sentence")
    func proseInAnotherLanguage() throws {
        let french = "Depuis 2016, j'enseigne à l'école Don Milani, où j'ai formé 3 nouveaux enseignants."
        let detector = sanitizer(languages: [
            french: "fr",
            "Don Milani school.": "en",
            "J'enseigne à l'école Don Milani.": "fr",
            "Don Milani": "und",
        ])

        let result = try detector.sanitize(CVData(summary: "Don Milani school. J'enseigne à l'école Don Milani."), against: french)

        #expect(result.summary == "J'enseigne à l'école Don Milani.")
    }

    @Test("The same language with another region, an unsure detector or no detector keeps the prose")
    func proseLanguageIsOnlyDroppedWhenSure() throws {
        let description = "Desde 2016, leciono na escola Don Milani."
        let prose = "Leciono na escola Don Milani."

        let sameLanguage = sanitizer(languages: [description: "pt-BR", prose: "pt-PT"])
        let unsure = sanitizer(languages: [description: "pt-BR"])
        let undetectableDescription = sanitizer(languages: [prose: "en"])

        #expect(try sameLanguage.sanitize(CVData(summary: prose), against: description).summary == prose)
        #expect(try unsure.sanitize(CVData(summary: prose), against: description).summary == prose)
        #expect(try undetectableDescription.sanitize(CVData(summary: prose), against: description).summary == prose, "Without the description's language there is nothing to compare")
        #expect(try CVDataSanitizer().sanitize(CVData(summary: prose), against: description).summary == prose)
    }

    @Test("Descriptions and achievements of an entry follow the same language rule")
    func entryProseInAnotherLanguage() throws {
        let description = "Depuis 2016, j'enseigne à l'école Don Milani, où j'ai formé 3 nouveaux enseignants."
        let detector = sanitizer(languages: [
            description: "fr",
            "Don Milani school.": "en",
            "J'enseigne à l'école Don Milani.": "fr",
        ])
        let job = Experience(
            title: "", company: "Don Milani", startDate: "2016",
            description: "Don Milani school.",
            achievements: ["Don Milani school.", "J'enseigne à l'école Don Milani."]
        )

        let result = try detector.sanitize(CVData(experience: [job]), against: description).experience.first

        #expect(result?.description == nil)
        #expect(result?.achievements == ["J'enseigne à l'école Don Milani."])
    }

    // MARK: - A number next to the words it stands next to

    @Test("A summary holds no number, not even one the description writes next to the same words: 3 teachers are not 3 years")
    func numberNextToOtherWords() throws {
        let german = "Seit 2016 unterrichte ich an der Schule Don Milani, wo ich 3 neue Lehrkräfte eingearbeitet habe."

        #expect(try summary("Sie hat 3 neue Lehrkräfte eingearbeitet.", from: german) == nil)
        #expect(try summary("Eine Lehrerin mit 3 Jahren Erfahrung.", from: german) == nil)
        #expect(try summary("Trained 3 new teachers.", from: "I trained 3 new teachers at school") == nil)
        #expect(try summary("A teacher with 3 years of experience.", from: "I trained 3 new teachers at school") == nil)
        #expect(try summary("Com 3 anos de experiência.", from: "Desde 2016 leciono, onde formei 3 novos professores.") == nil)
    }

    @Test("A year of a text is the year of its quote: another year, another word beside it or a part of the clause is no quote")
    func yearWithOtherWords() throws {
        let given = "I worked at San Raffaele from 2012 to 2016"

        #expect(try roleDescription("Worked at San Raffaele from 2012 to 2016.", from: given) == "Worked at San Raffaele from 2012 to 2016.")
        #expect(try roleDescription("A nurse, 2012-2016.", from: given) == nil, "2012 is followed by 2016, not by to")
        #expect(try roleDescription("Worked at San Raffaele until 2016.", from: given) == nil, "2016 is preceded by until, not by to")
        #expect(try roleDescription("Worked at San Raffaele from 2012 to 2018.", from: given) == nil)
        #expect(try roleDescription("Worked at San Raffaele from 2012.", from: given) == nil, "The quote stops before the clause's end")
    }

    // MARK: - An entry is backed by the sentences that name it

    @Test("The dates of a study are those of the sentence naming it, not the years of a job")
    func studyDatesComeFromItsOwnSentence() throws {
        let given = "Seit 2016 unterrichte ich an der Schule Don Milani. Davor habe ich von 2012 bis 2016 als Betreuerin in einer Kinderkrippe gearbeitet. Ich habe 2012 Erziehungswissenschaften an der Universität Bologna studiert."
        let study = Education(degree: "Erziehungswissenschaften", institution: "Universität Bologna", startDate: "2012", endDate: "2016", description: "Ich habe 2012 Erziehungswissenschaften an der Universität Bologna studiert.")

        let result = try sanitizer.sanitize(CVData(education: [study]), against: given).education.first

        #expect(result?.startDate == "2012")
        #expect(result?.endDate == nil, "2016 belongs to the job in the nursery")
        #expect(result?.description == "Ich habe 2012 Erziehungswissenschaften an der Universität Bologna studiert.")
    }

    @Test("The dates and achievements of a job are those of the sentences naming it")
    func jobFiguresComeFromItsOwnSentences() throws {
        let given = """
        Dal 2004 al 2008 ho lavorato presso lo Studio Rossi, seguendo 40 pratiche. \
        Dal 2008 al 2015 sono stato responsabile presso Edilverona, dove ho gestito 3 complessi residenziali.
        """
        let studio = Experience(title: "Tecnico", company: "Studio Rossi", startDate: "2004", endDate: "2015", achievements: ["Gestito 3 complessi residenziali", "Seguendo 40 pratiche"])
        let edil = Experience(title: "Responsabile", company: "Edilverona", startDate: "2008", endDate: "2015", achievements: ["Gestito 3 complessi residenziali"])

        let result = try sanitizer.sanitize(CVData(experience: [studio, edil]), against: given).experience

        #expect(result.map(\.startDate) == ["2004", "2008"])
        #expect(result.map(\.endDate) == [nil, "2015"], "2015 is not the end of the job at Studio Rossi")
        #expect(result.first?.achievements == ["Seguendo 40 pratiche"], "3 complexes belong to Edilverona")
        #expect(result.last?.achievements == ["Gestito 3 complessi residenziali"])
    }

    @Test("A certification's date is that of the sentence naming it")
    func certificationDateComesFromItsOwnSentence() throws {
        let given = "I hold BLS from the Italian Resuscitation Council renewed in 2023. I obtained PALS in 2019."
        let bls = Certification(name: "BLS", issuer: "Italian Resuscitation Council", date: "2019")
        let pals = Certification(name: "PALS", date: "2019")

        let result = try sanitizer.sanitize(CVData(certifications: [bls, pals]), against: given).certifications

        #expect(result.map(\.date) == [nil, "2019"])
    }

    // MARK: - Role and study descriptions, achievements

    @Test("A role description is filtered like the summary")
    func roleDescriptionIsFiltered() throws {
        #expect(try roleDescription("Worked at San Raffaele for 12 years. Led a team of 12.", from: roleSource) == "Worked at San Raffaele for 12 years.")
        #expect(try roleDescription("Led a team of 12.", from: roleSource) == nil)
    }

    @Test("A study description is filtered like the summary")
    func studyDescriptionIsFiltered() throws {
        let given = "I graduated in Nursing at the University of Turin with 110 out of 110"
        let entry = Education(
            degree: "Nursing", institution: "University of Turin",
            description: "Graduated in Nursing at the University of Turin with 110 out of 110. Thesis grade 30."
        )

        let result = try sanitizer.sanitize(CVData(education: [entry]), against: given).education

        #expect(result.first?.description == "Graduated in Nursing at the University of Turin with 110 out of 110.")
    }

    @Test("An achievement keeps only its grounded sentences, and goes when none is left")
    func achievementsAreFiltered() throws {
        let achievements = [
            "Worked for 3 years since 2016 at San Raffaele",
            "Worked for 3 years",
            "Reduced waiting by 30%",
            "Worked for 3 years since 2016 at San Raffaele. Won an award in 2019.",
        ]
        let job = Experience(title: "nurse", company: "San Raffaele", startDate: "2016", achievements: achievements)

        let result = try sanitizer.sanitize(CVData(experience: [job]), against: "I worked for 3 years since 2016 at San Raffaele.").experience.first?.achievements

        #expect(result == ["Worked for 3 years since 2016 at San Raffaele", "Worked for 3 years since 2016 at San Raffaele."])
    }

    // MARK: - Dates

    @Test("A date whose year is not in the description is dropped")
    func yearMustBeInTheDescription() throws {
        let given = "I was a nurse at San Raffaele from 2015 to 2019"
        let entries = [
            Experience(title: "nurse", company: "San Raffaele", startDate: "2015", endDate: "2021"),
            Experience(title: "nurse", company: "San Raffaele", startDate: "2014", endDate: "2019"),
        ]

        let result = try sanitizer.sanitize(CVData(experience: entries), against: given).experience

        #expect(result.map(\.startDate) == ["2015"], "Both jobs name the same employer and title, so they are one")
        #expect(result.map(\.endDate) == [nil])
    }

    @Test("A date is cut to its years unless the description writes it that way")
    func dateIsCutToItsYears() throws {
        let given = "I was a nurse at San Raffaele from 2015 to June 2019"
        let entries = [
            Experience(title: "nurse", company: "San Raffaele", startDate: "March 2015", endDate: "June 2019"),
            Experience(title: "cook", company: "Other", startDate: "2015-01-01", endDate: "2019-12-31"),
        ]

        let result = try sanitizer.sanitize(CVData(experience: entries), against: given).experience

        #expect(result.first?.startDate == "2015", "The description gives no month, so \"March\" is made up")
        #expect(result.first?.endDate == "June 2019", "The description writes it so")
        #expect(result.count == 1, "The second job names neither a title nor an employer of the description")
    }

    @Test("A date without a year is kept only if its words are in the description")
    func dateWithoutYear() throws {
        let given = "I worked as a cook since last spring"
        let entries = [Experience(title: "cook", startDate: "last spring", endDate: "Present")]

        let result = try sanitizer.sanitize(CVData(experience: entries), against: given).experience

        #expect(result.first?.startDate == "last spring")
        #expect(result.first?.endDate == nil)
    }

    @Test("Study and certification dates follow the same rule")
    func otherDates() throws {
        let given = "I graduated in Nursing in 2014. I obtained BLS in 2020."
        let cvData = CVData(
            education: [Education(degree: "Nursing", startDate: "2011", endDate: "2014")],
            certifications: [Certification(name: "BLS", date: "2020")]
        )

        let result = try sanitizer.sanitize(cvData, against: given)

        #expect(result.education.first?.startDate == nil)
        #expect(result.education.first?.endDate == "2014")
        #expect(result.certifications.first?.date == "2020")
    }
}

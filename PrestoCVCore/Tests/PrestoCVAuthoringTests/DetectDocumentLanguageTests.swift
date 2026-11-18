import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication

private let italian = DocumentLanguage("it")!
private let german = DocumentLanguage("de")!
private let offered = [DocumentLanguage.english, german, italian]

/// Fifteen words of work, the fewest that tell a language.
private let fifteenWords = "Coordino i turni della cucina e preparo i menu del pranzo per un ristorante storico"

/// Answers `reading` only for the text and the languages it expects, and a reading of no language for any other: a
/// verdict then proves what the rule asked.
private struct ExpectingReader: TextLanguageReading {
    let text: String
    var languages = offered
    var reading = LanguageReading(dominant: italian, likelihoods: [italian: 0.9, .english: 0.06, german: 0.04])

    func reading(of text: String, among languages: [DocumentLanguage]) -> LanguageReading {
        guard text == self.text, languages == self.languages else {
            return LanguageReading(dominant: nil, likelihoods: [:])
        }
        return reading
    }
}

/// Fails the test when it is asked: the words were too few to ask.
private struct UnaskedReader: TextLanguageReading {
    func reading(of text: String, among languages: [DocumentLanguage]) -> LanguageReading {
        Issue.record("the reader was asked to read \(text.count) characters")
        return LanguageReading(dominant: italian, likelihoods: [italian: 1])
    }
}

private func cv(
    title: String = "", summary: String = "", experiences: [Experience] = [], education: [Education] = []
) -> CV {
    CV(id: CVID(UUID()),
       personal: PersonalDetails(fullName: "Mara Ellison", professionalTitle: title, email: nil, location: "Torino",
                                 summary: summary),
       sections: CVSections(experiences: experiences, education: education))
}

private func language(
    of cv: CV, by reader: some TextLanguageReading, among languages: [DocumentLanguage] = offered
) -> DocumentLanguage? {
    DetectDocumentLanguage(reader: reader).language(of: cv, among: languages)
}

@Suite("The language a CV's words are written in")
struct DetectDocumentLanguageTests {

    // MARK: - The words read

    @Test("the words of the work are read in order: the summary, the title, each job, each study")
    func wordsOfTheWork() {
        let written = cv(
            title: "Cuoca",
            summary: "Lavoro in cucina da dieci anni.",
            experiences: [Experience(role: "Capo partita", company: "Trattoria Venn", location: "Asti",
                                     description: "Preparo i primi piatti e ordino la merce."),
                          Experience(role: "Aiuto cuoca", company: "Osteria Corr")],
            education: [Education(degree: "Diploma alberghiero", school: "Istituto Renn",
                                  description: "Cucina e sala, con uno stage in hotel.")])
        let expected = """
            Lavoro in cucina da dieci anni.
            Cuoca
            Capo partita
            Preparo i primi piatti e ordino la merce.
            Aiuto cuoca
            Diploma alberghiero
            Cucina e sala, con uno stage in hotel.
            """

        #expect(language(of: written, by: ExpectingReader(text: expected)) == italian)
    }

    @Test("names tell no language: the person's, an employer's, a school's and a place's are not read")
    func namesAreNotRead() {
        let written = cv(summary: fifteenWords,
                         experiences: [Experience(role: "", company: "Trattoria Venn", location: "Asti")],
                         education: [Education(degree: "", school: "Istituto Renn")])

        #expect(language(of: written, by: ExpectingReader(text: fifteenWords)) == italian)
    }

    @Test("only the first thousand characters are read")
    func firstThousandCharacters() {
        let long = String(repeating: "Preparo i primi piatti e ordino la merce ogni mattina. ", count: 40)
        let read = String(long.prefix(DetectDocumentLanguage.maximumCharacters))

        #expect(long.count > DetectDocumentLanguage.maximumCharacters)
        #expect(language(of: cv(summary: long), by: ExpectingReader(text: read)) == italian)
    }

    @Test("the reader chooses among the languages it is given")
    func amongTheLanguagesGiven() {
        let two = [german, italian]
        let reader = ExpectingReader(text: fifteenWords, languages: two)

        #expect(language(of: cv(summary: fifteenWords), by: reader, among: two) == italian)
    }

    // MARK: - Too few words

    @Test("fewer than fifteen words tell no language, and the reader is not asked", arguments: [
        "",
        "Coordino i turni della cucina e preparo i menu del pranzo per un ristorante",
        // Numbers and signs are not words
        "Coordino i turni della cucina e preparo i menu del pranzo per un ristorante 2019 – 2024 · 40 %",
    ])
    func tooFewWords(summary: String) {
        #expect(language(of: cv(summary: summary), by: UnaskedReader()) == nil)
    }

    @Test("the words of all the fields count together: fifteen of them tell a language")
    func wordsCountTogether() {
        let written = cv(title: "Cuoca", summary: "Coordino i turni della cucina e preparo i menu",
                         experiences: [Experience(role: "Capo partita", company: "Trattoria Venn",
                                                  description: "Primi piatti, dolci")])
        let text = "Coordino i turni della cucina e preparo i menu\nCuoca\nCapo partita\nPrimi piatti, dolci"

        #expect(language(of: written, by: ExpectingReader(text: text)) == italian)
    }

    // MARK: - The verdict

    @Test("a reading sure enough of the language it finds on its own gives that language", arguments: [0.8, 0.95, 1])
    func sureEnough(likelihood: Double) {
        let reader = ExpectingReader(text: fifteenWords,
                                     reading: LanguageReading(dominant: italian, likelihoods: [italian: likelihood]))

        #expect(language(of: cv(summary: fifteenWords), by: reader) == italian)
    }

    @Test("a reading that does not tell one language gives none", arguments: [
        // Not sure enough
        LanguageReading(dominant: italian, likelihoods: [italian: 0.79, .english: 0.21]),
        // Its likeliest language among those offered is not the one it finds on its own
        LanguageReading(dominant: german, likelihoods: [italian: 0.9, german: 0.1]),
        // Two languages as likely
        LanguageReading(dominant: italian, likelihoods: [italian: 0.85, german: 0.85]),
        // It finds no language on its own
        LanguageReading(dominant: nil, likelihoods: [italian: 0.9]),
        // It finds one it gives no likelihood for
        LanguageReading(dominant: italian, likelihoods: [:]),
        // It finds one the PDF cannot be written in
        LanguageReading(dominant: DocumentLanguage("fr")!, likelihoods: [DocumentLanguage("fr")!: 0.95]),
    ])
    func noLanguage(reading: LanguageReading) {
        let reader = ExpectingReader(text: fifteenWords, reading: reading)

        #expect(language(of: cv(summary: fifteenWords), by: reader) == nil)
    }
}

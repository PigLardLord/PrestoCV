#if canImport(NaturalLanguage)
import Foundation
import NaturalLanguage
import PrestoCVApplication
@testable import PrestoCVApplicationNaturalLanguage
import PrestoCVDomain
import Testing

private let italian = DocumentLanguage("it")!
private let german = DocumentLanguage("de")!
private let offered = [DocumentLanguage.english, german, italian]

private let italianWork = """
    Coordino i turni della cucina, preparo i menu del pranzo e della cena e seguo gli ordini della merce per un \
    ristorante del centro.
    """
private let germanWork = """
    Ich plane die Schichten in der Küche, bereite die Menüs für Mittag und Abend vor und bestelle die Waren für \
    ein Restaurant in der Altstadt.
    """
private let englishWork = """
    I plan the kitchen shifts, prepare the lunch and dinner menus and order the goods for a restaurant in the old \
    town.
    """

/// The system's recognizer, read through the port: these run on the Apple platforms only.
@Suite("The system's recognizer reads the language of a text")
struct NaturalLanguageTextReaderTests {

    @Test("a text of work is read as its language, sure enough for the rule", arguments: [
        (italianWork, italian), (germanWork, german), (englishWork, DocumentLanguage.english),
    ])
    func readsItsLanguage(text: String, language: DocumentLanguage) throws {
        let reading = NaturalLanguageTextReader().reading(of: text, among: offered)

        #expect(reading.dominant == language)
        let likelihood = try #require(reading.likelihoods[language])
        #expect(likelihood >= DetectDocumentLanguage.minimumLikelihood)
    }

    @Test("the likelihoods are of the languages given only")
    func likelihoodsOfTheLanguagesGiven() {
        let two = [german, italian]
        let reading = NaturalLanguageTextReader().reading(of: englishWork, among: two)

        #expect(Set(reading.likelihoods.keys).isSubset(of: two))
        #expect(reading.dominant == .english)
    }

    @Test("a language the recognizer does not know gets no likelihood")
    func unknownLanguage() throws {
        let klingon = try #require(DocumentLanguage("tlh"))
        let reading = NaturalLanguageTextReader().reading(of: italianWork, among: [italian, klingon])

        #expect(reading.likelihoods[klingon] == nil)
        #expect(reading.likelihoods[italian] != nil)
    }

    @Test("with no languages given, the text is still read, and nothing is likely")
    func noLanguagesGiven() {
        let reading = NaturalLanguageTextReader().reading(of: italianWork, among: [])

        #expect(reading.dominant == italian)
        #expect(reading.likelihoods.isEmpty)
    }

    @Test("a text the recognizer cannot read gives no language", arguments: ["", "2019 – 2024 · 40 % · 12/2021"])
    func noLanguage(text: String) {
        #expect(NaturalLanguageTextReader().reading(of: text, among: offered).dominant == nil)
    }

    @Test("a text called undetermined gives no language, though its tag would make one")
    func undetermined() {
        #expect(DocumentLanguage(NLLanguage.undetermined.rawValue) != nil)
        #expect(NaturalLanguageTextReader.found(.undetermined) == nil)
        #expect(NaturalLanguageTextReader.found(nil) == nil)
        #expect(NaturalLanguageTextReader.found(.italian) == italian)
    }

    @Test("a CV whose work is written in Italian is exported in Italian")
    func throughTheRule() {
        let cv = CV(id: CVID(UUID()),
                    personal: PersonalDetails(fullName: "Mara Ellison", professionalTitle: "Cuoca", email: nil,
                                              location: "Torino", summary: italianWork),
                    sections: CVSections(experiences: [], education: []))

        #expect(DetectDocumentLanguage(reader: NaturalLanguageTextReader()).language(of: cv, among: offered) == italian)
    }
}
#endif

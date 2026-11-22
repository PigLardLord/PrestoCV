import Testing
import Foundation

// The checks on the wording of texts that need no catalog: they run on strings given in the test.

@Suite("Localization catalog")
struct LocalizationCatalogTests {

    static let properNames: Set<String> = [
        "Apple", "Intelligence", "Siri", "Ajustes", "Réglages", "Impostazioni", "Sistema", "Système",
    ]

    @Test("A capital letter is expected at the start of a sentence, in an abbreviation and in a proper name")
    func titleCaseWordsSkipsLegitimateCapitals() throws {
        #expect(try StringChecks.titleCaseWords(in: "Crea Tu CV Perfecto", properNames: Self.properNames) == ["Tu", "Perfecto"])
        #expect(try StringChecks.titleCaseWords(in: "Crea tu CV perfecto", properNames: Self.properNames).isEmpty)
        #expect(try StringChecks.titleCaseWords(in: "Impossibile creare il PDF. Riprova.", properNames: Self.properNames).isEmpty)
        #expect(try StringChecks.titleCaseWords(in: "C1 - Avanzado", properNames: Self.properNames).isEmpty)
        #expect(try StringChecks.titleCaseWords(in: "O Apple Intelligence está desativado. Abra Ajustes.", properNames: Self.properNames).isEmpty)
    }

    @Test("A promise of availability is found as a word, in any case; a text without one, or a duration, passes")
    func availabilityPromiseIsFoundAsAWord() {
        #expect(StringChecks.availabilityPromise(in: "Getting ready, available soon", language: "en") == "soon")
        #expect(StringChecks.availabilityPromise(in: "In preparazione, presto disponibile", language: "it") == "presto")
        #expect(StringChecks.availabilityPromise(in: "Bald verfügbar", language: "de") == "bald")
        #expect(StringChecks.availabilityPromise(in: "Try again later.", language: "en") == "later")
        #expect(StringChecks.availabilityPromise(in: "Riprova più tardi.", language: "it") == "più tardi")
        #expect(StringChecks.availabilityPromise(in: "Downloading the model", language: "en") == nil)
        #expect(StringChecks.availabilityPromise(in: "Not available right now", language: "en") == nil)
        #expect(StringChecks.availabilityPromise(in: "Apple Intelligence is busy right now. Please try again.", language: "en") == nil)
        #expect(StringChecks.availabilityPromise(in: "This can take up to a minute.", language: "en") == nil, "A duration is not a promise of availability")
    }
}

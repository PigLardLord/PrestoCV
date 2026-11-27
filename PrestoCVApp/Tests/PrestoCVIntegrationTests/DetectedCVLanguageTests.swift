import Foundation
import PrestoCVApplication
import PrestoCVDomain
import PrestoCVIntegration
import Synchronization
import Testing

/// A reader that finds Italian, sure of it, and remembers for each text whether it read it on the main actor.
private final class ThreadRecordingReader: TextLanguageReading {
    private let threads = Mutex<[Bool]>([])

    /// For each text read, whether it was read on the main actor.
    var readOnTheMainActor: [Bool] { threads.withLock { $0 } }

    func reading(of text: String, among languages: [DocumentLanguage]) -> LanguageReading {
        let onMainActor = MainActorProbe.isOnTheMainActor
        threads.withLock { $0.append(onMainActor) }
        return LanguageReading(dominant: italian, likelihoods: [italian: 0.9])
    }
}

private let italian = DocumentLanguage("it") ?? .english

/// Fifteen words of work, the fewest that tell a language.
private let fifteenWords = "Coordino i turni della cucina e preparo i menu del pranzo per un ristorante storico"

@Suite("The language of a CV's words")
struct DetectedCVLanguageTests {
    @MainActor
    @Test("the words are read off the main actor, also when the export sheet asks from it (R19)")
    func wordsAreReadOffTheMainActor() async {
        let reader = ThreadRecordingReader()
        let cv = CV(id: CVID(UUID()),
                    personal: PersonalDetails(fullName: "Mara Ellison", professionalTitle: "", email: nil, location: "Torino",
                                              summary: fifteenWords))

        let found = await DetectedCVLanguage(DetectDocumentLanguage(reader: reader))
            .language(of: cv, among: [.english, italian])

        #expect(found == italian)
        #expect(reader.readOnTheMainActor == [false])
    }
}

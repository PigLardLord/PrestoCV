import CVGeneratorAI
import Synchronization

/// A device that has no language data until the test says it has arrived, as when the system downloads it while the app waits.
/// From then on it tags the verbs that `FakeLexicalTagger.english` tags.
final class ArrivingLexicalTagger: LexicalTagger {
    private let arrived = Mutex(false)
    private let tags = FakeLexicalTagger.english

    /// The data of every language is on the device now.
    func dataArrives() {
        arrived.withLock { $0 = true }
    }

    func tagsLexicalClass(inLanguage language: String) -> Bool {
        arrived.withLock { $0 }
    }

    func verbs(in text: String, language: String) -> [Range<Int>] {
        tags.verbs(in: text, language: language)
    }
}

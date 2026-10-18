import Foundation
@testable import CVGeneratorAI

/// A lexical class whose verdict a test gives, language by language, in place of the one the device's assets would give. A language
/// with no verdict is read by the device.
struct ForcedLexicalTagger: LexicalTagger {
    enum Verdict: Sendable {
        /// The device has no assets for the language: it tags nothing.
        case noAssets
        /// It tags every word as a verb.
        case everyWord
        /// It tags these words as verbs, as `Word.folded` writes them.
        case words(Set<String>)
    }

    let verdicts: [Vocabulary.Language: Verdict]

    init(_ verdicts: [Vocabulary.Language: Verdict]) {
        self.verdicts = verdicts
    }

    func verbs(in text: String, language: String) -> [Range<Int>] {
        switch Vocabulary.Language(rawValue: language).flatMap({ verdicts[$0] }) {
        case nil:
            return DeviceLexicalTagger().verbs(in: text, language: language)
        case .noAssets:
            return []
        case .everyWord:
            return Word.words(in: text).map(\.range)
        case .words(let verbs):
            return Word.words(in: text).filter { verbs.contains($0.folded) }.map(\.range)
        }
    }
}

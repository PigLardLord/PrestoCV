import Foundation
@testable import CVGeneratorAI

/// A lexical class whose verdict a test gives, language by language, in place of the one the device's assets would give. A language
/// with no verdict is read by the device.
struct ForcedLexicalTagger: LexicalTagger {
    enum Verdict: Sendable {
        /// It tags these words as verbs, as `Word.folded` writes them.
        case words(Set<String>)
    }

    let verdicts: [Vocabulary.Language: Verdict]

    init(_ verdicts: [Vocabulary.Language: Verdict]) {
        self.verdicts = verdicts
    }

    func verbs(in text: String, language: Vocabulary.Language) -> [Range<Int>] {
        switch verdicts[language] {
        case nil:
            return DeviceLexicalTagger().verbs(in: text, language: language)
        case .words(let verbs):
            return Word.words(in: text).filter { verbs.contains($0.folded) }.map(\.range)
        }
    }
}

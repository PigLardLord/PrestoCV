import Foundation
import CVGeneratorAI

/// A lexical class that tags the words a test gives as verbs, so that grounding reads a description the same on every simulator,
/// whatever language data it has.
struct FakeLexicalTagger: LexicalTagger {
    /// The verbs that the device tags, with the data of English, in the descriptions of these tests (macOS 27).
    static let english = FakeLexicalTagger(taggedWords: ["am", "paint", "speak", "trained", "work", "worked"])

    /// The words it tags, in lower case.
    let taggedWords: Set<String>

    func verbs(in text: String, language: String) -> [Range<Int>] {
        var verbs: [Range<Int>] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { word, range, _, _ in
            guard let word, taggedWords.contains(word.lowercased()) else { return }
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            verbs.append(start..<(start + text.distance(from: range.lowerBound, to: range.upperBound)))
        }
        return verbs
    }
}

import Foundation
@testable import CVGeneratorAI

/// A dictionary of one language that knows only `words`, in lower case: a test that needs a dictionary verdict of its own reads
/// it in place of the device's.
struct KnownWords: WordList {
    let words: Set<String>

    func knows(_ word: String, inLanguage language: String) -> Bool? { words.contains(word.lowercased()) }
}

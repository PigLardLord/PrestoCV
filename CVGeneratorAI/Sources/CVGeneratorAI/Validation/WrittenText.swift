import Foundation

/// The text the model writes around the facts (ADR 0031): a summary of the person's profession and the responsibilities typical of
/// each job's title. Such a sentence quotes nothing, so it is kept only when it states no fact of its own, which the person would have
/// had to say. A sentence is plain when it is in the language of the description and holds:
/// - no address, and no number, in digits or in words ("five", "cinque");
/// - no month, and no word of duration, seniority or level ("years", "senior", "expert") that the description does not write;
/// - no negation: the person denied nothing in it;
/// - no word that the description holds only in the clauses that claim nothing for the person (another person's, or one that denies,
///   wishes or supposes): "I would like to become a head nurse" gives no "head";
/// - for a job, no word of another job's title or employer: the duties of the head nurse are not those of the nurse;
/// - no name: in English, Italian, Spanish, French and Portuguese a capital after the first word, a first word that is no word of the
///   language, or any other word that the vocabulary and the device's dictionary do not know; in German, where every noun has a
///   capital, a word the device tags as a name, or one that the vocabulary and the dictionary do not know as written; in every
///   language, a word of capitals ("ACME"). The person's title and the titles and degrees of the draft are the person's own words.
struct WrittenText {
    private let source: DescriptionText
    private let language: Vocabulary.Language?
    private let words: WrittenTextWords
    /// The words of the description, as `Word.folded` writes them.
    private let descriptionWords: Set<String>
    /// The content words that the description holds only in clauses that claim nothing for the person.
    private let excludedWords: Set<String>
    private let wordList: any WordList
    private let tagger: any LexicalTagger

    /// - Parameters:
    ///   - claimed: The description as the person claims things in it (`Entries.claimed`).
    ///   - wordList: The device's dictionary, which tells a word from a name.
    ///   - tagger: What tells the names of a German text.
    init(source: DescriptionText, claimed: DescriptionText, wordList: any WordList, tagger: any LexicalTagger) {
        self.source = source
        language = source.explainer.language
        words = WrittenTextWords.of(language)
        descriptionWords = source.foldedWords
        let language = language
        excludedWords = source.foldedWords.subtracting(claimed.foldedWords).filter { word in
            !Vocabulary.isNeutral(word, in: language) && !word.allSatisfy(\.isNumber)
        }
        self.wordList = wordList
        self.tagger = tagger
    }

    /// Whether `sentence` states no fact of its own.
    ///
    /// - Parameters:
    ///   - ownWords: The words that are no name in it, as `Word.folded` writes them: the titles and degrees it may name.
    ///   - foreignWords: The words it may not hold: for a job, those of the other jobs' titles and employers.
    func isPlain(_ sentence: String, ownWords: Set<String>, foreignWords: Set<String> = []) -> Bool {
        guard source.isInTheLanguageOfTheDescription(sentence) else { return false }

        let addresses = AddressTokens(sentence)
        guard addresses.emails.isEmpty, addresses.links.isEmpty, !addresses.hasAmbiguousAddress else { return false }
        guard !sentence.contains(where: \.isNumber), !Self.hasAContractedNegation(sentence) else { return false }

        let sentenceWords = Word.words(in: sentence)
        guard !sentenceWords.contains(where: { statesAFact($0.folded, foreignWords: foreignWords) }) else { return false }
        return !namesSomething(sentenceWords, in: sentence, ownWords: ownWords)
    }

    /// Whether `word` is a word that the description holds only in clauses that claim nothing for the person.
    func isExcluded(_ word: String) -> Bool {
        excludedWords.contains(word)
    }

    /// Whether `word` is a word of level, duration or seniority that the description does not write.
    func isAnUnstatedLevel(_ word: String) -> Bool {
        (words.seniority.contains(word) || Vocabulary.isLevel(word, in: language)) && !descriptionWords.contains(word)
    }

    private func statesAFact(_ word: String, foreignWords: Set<String>) -> Bool {
        words.numbers.contains(word) || words.months.contains(word) || words.negations.contains(word) || isAnUnstatedLevel(word)
            || isExcluded(word) || foreignWords.contains(word)
    }

    /// "Don't", "isn't": the apostrophe splits the word, so the negation is read in the text.
    private static func hasAContractedNegation(_ sentence: String) -> Bool {
        let text = DescriptionText.normalized(sentence)
        return text.contains("n't")
    }

    // MARK: - Names

    private func namesSomething(_ sentenceWords: [Word], in sentence: String, ownWords: Set<String>) -> Bool {
        let characters = Array(Digits.ascii(sentence))
        let dictionary = (language ?? .english).rawValue
        let tagged = language == .german ? tagger.names(in: sentence, language: dictionary) : []

        for (index, word) in sentenceWords.enumerated() where !word.isNumber && !ownWords.contains(word.folded) {
            let written = String(characters[word.range])
            let letters = written.filter(\.isLetter)
            let isCapitalised = characters[word.range.lowerBound].isUppercase
            guard letters.count < 2 || !letters.allSatisfy(\.isUppercase) else { return true }

            let isExplained = Vocabulary.explains(word.folded, in: language) || Vocabulary.isNeutral(word.folded, in: language)
            if language == .german {
                guard !tagged.contains(where: { $0.contains(word.range.lowerBound) }) else { return true }
                if !isExplained && (isCapitalised || letters.count >= 3) && wordList.knows(written, inLanguage: dictionary) == false {
                    return true
                }
            } else if isCapitalised {
                guard index == 0 || written == "I" else { return true }
                if !isExplained && wordList.knows(written.lowercased(), inLanguage: dictionary) == false { return true }
            } else if !isExplained && letters.count >= 3 && wordList.knows(written, inLanguage: dictionary) == false {
                return true
            }
        }
        return false
    }
}

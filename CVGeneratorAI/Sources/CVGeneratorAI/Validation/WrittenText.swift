import Foundation

/// The text the model writes around the facts (ADR 0031): a summary of the person's profession and the responsibilities typical of
/// each job's title. Such a sentence quotes nothing, so it is kept only when it states no fact of its own, which the person would have
/// had to say. A sentence is plain when it is in the language of the description and holds:
/// - no address, and no number, in digits or in words, compound ones included ("five", "cinque", "ventuno", "einundzwanzig");
/// - no character that the reader cannot see or that reorders what they see (`HiddenCharacters`): a zero-width space would hide an
///   address from the checks;
/// - no word of a qualification ("license", "abilitazione", "Abschluss"): a qualification is a fact the person has to state, unless it is
///   one of the person's studies (`OwnQualifications`);
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
    /// The first 7 letters of the excluded words of 7 letters or more, and of none of the words the person claims.
    private let excludedStems: Set<String>
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
        let excludedWords = source.foldedWords.subtracting(claimed.foldedWords).filter { word in
            !Vocabulary.isNeutral(word, in: language) && !word.allSatisfy(\.isNumber)
        }
        self.excludedWords = excludedWords
        excludedStems = Set(excludedWords.compactMap(Self.stem)).subtracting(claimed.foldedWords.compactMap(Self.stem))
        self.wordList = wordList
        self.tagger = tagger
    }

    /// Whether `sentence` states no fact of its own.
    ///
    /// - Parameters:
    ///   - ownWords: The words that are no name in it, as `Word.folded` writes them: the titles and degrees it may name.
    ///   - foreignWords: The words it may not hold: for a job, those of the other jobs' titles and employers.
    ///   - ownQualifications: The qualification words that are the person's own (`OwnQualifications`), as `rejection` reads them.
    func isPlain(_ sentence: String, ownWords: Set<String>, foreignWords: Set<String> = [], ownQualifications: Set<String> = []) -> Bool {
        rejection(of: sentence, ownWords: ownWords, foreignWords: foreignWords, ownQualifications: ownQualifications) == nil
    }

    /// Why `isPlain` rejects `sentence`, as a short reason the repair request reads; nil when it is plain.
    ///
    /// ADR 0031, D3: `allowing` holds the words of a duty that quotes its own job's clause word for word: there its acronyms,
    /// number words and seniority words are the person's own. Digits and another job's words still reject it. `ownQualifications`
    /// holds the qualification words of the person's studies, which a summary sentence of a rich draft names (#354, probe round 21).
    func rejection(
        of sentence: String, ownWords: Set<String>, foreignWords: Set<String> = [], allowing: Set<String> = [],
        ownQualifications: Set<String> = []
    ) -> String? {
        guard source.isInTheLanguageOfTheDescription(sentence, wordList: wordList) else { return "it is not in the language of the description" }
        guard !HiddenCharacters.occur(in: sentence) else { return "it holds a character the reader cannot see" }

        let addresses = AddressTokens(sentence)
        guard addresses.emails.isEmpty, addresses.links.isEmpty, !addresses.hasAmbiguousAddress else { return "it holds an address" }
        guard !sentence.contains(where: \.isNumber) else { return "it holds a number" }
        guard !Self.hasAContractedNegation(sentence) else { return "it holds a negation" }

        let sentenceWords = Word.words(in: sentence)
        for (index, word) in sentenceWords.enumerated() {
            let folded = word.folded
            let isAllowed = allowing.contains(folded)
            let isTaught = index > 0 && Self.isTaught(folded, after: sentenceWords[index - 1].folded)
            if words.isNumber(folded) && !isAllowed { return "the word \"\(folded)\" is a number" }
            if words.qualifications.contains(folded) && !ownQualifications.contains(folded) { return "the word \"\(folded)\" names a qualification" }
            if words.months.contains(folded) { return "the word \"\(folded)\" is a date" }
            if words.negations.contains(folded) { return "the word \"\(folded)\" is a negation" }
            if isAnUnstatedLevel(folded) && !isAllowed && !isTaught {
                return "the word \"\(folded)\" states a level the person did not say"
            }
            if isExcluded(folded) { return "the word \"\(folded)\" is something the person only wishes or plans" }
            if foreignWords.contains(folded) { return "the word \"\(folded)\" belongs to another job" }
        }
        if let name = nameIn(sentenceWords, in: sentence, ownWords: ownWords.union(allowing)) { return "the word \"\(name)\" reads as a name" }
        return nil
    }

    /// The words a written duty of a job must avoid, among `candidates` (the words of the job's clauses): those that
    /// the description holds only in clauses that claim nothing, and those of `foreignWords`.
    func wordsToAvoid(among candidates: [Word], in text: String, ownWords: Set<String>, foreignWords: Set<String>) -> [String] {
        var avoided: [String] = []
        let characters = Array(Digits.ascii(text))
        for word in candidates where !word.isNumber && !ownWords.contains(word.folded) {
            let written = String(characters[word.range])
            let letters = written.filter(\.isLetter)
            let isAcronym = letters.count >= 2 && letters.allSatisfy(\.isUppercase)
            if isExcluded(word.folded) || foreignWords.contains(word.folded) || isAcronym { avoided.append(written) }
        }
        var seen = Set<String>()
        return avoided.filter { seen.insert($0.lowercased()).inserted }
    }

    /// Whether `word` is a word that the description holds only in clauses that claim nothing for the person.
    func isExcluded(_ word: String) -> Bool {
        excludedWords.contains(word)
    }

    /// Whether `word` is a form of a word that the description holds only in clauses that claim nothing for the person: its first 7
    /// letters are those of such a word, and of no word the person claims ("auditoria" of "I would like to work as an auditor", #354).
    func isAnExcludedForm(_ word: String) -> Bool {
        Self.stem(word).map(excludedStems.contains) ?? false
    }

    /// The first 7 letters of a word of 7 letters or more.
    private static func stem(_ word: String) -> String? {
        word.count >= 7 ? String(word.prefix(7)) : nil
    }

    /// Whether `word` is a word of level, duration or seniority that the description does not write.
    func isAnUnstatedLevel(_ word: String) -> Bool {
        (words.seniority.contains(word) || Vocabulary.isLevel(word, in: language)) && !descriptionWords.contains(word)
    }

    /// Whether `word` is a noun of a low level that `previous`, a definite article, makes the matter that is taught (O1; #354, probe
    /// round 10): "j'explique les notions aux élèves", "ich vermittle die Grundlagen". Without one it states the person's level:
    /// "notions d'anglais", "Grundkenntnisse in Excel". Not "des", which is also the article of "j'ai des notions".
    static func isTaught(_ word: String, after previous: String) -> Bool {
        ["notions", "grundlagen", "grundkenntnisse"].contains(word) && ["les", "aux", "die", "den", "der"].contains(previous)
    }

    private func statesAFact(_ word: String, foreignWords: Set<String>) -> Bool {
        words.isNumber(word) || words.qualifications.contains(word) || words.months.contains(word) || words.negations.contains(word)
            || isAnUnstatedLevel(word) || isExcluded(word) || foreignWords.contains(word)
    }

    /// "Don't", "isn't": the apostrophe splits the word, so the negation is read in the text.
    private static func hasAContractedNegation(_ sentence: String) -> Bool {
        let text = DescriptionText.normalized(sentence)
        return text.contains("n't")
    }

    // MARK: - Names

    private func namesSomething(_ sentenceWords: [Word], in sentence: String, ownWords: Set<String>) -> Bool {
        nameIn(sentenceWords, in: sentence, ownWords: ownWords) != nil
    }

    private func nameIn(_ sentenceWords: [Word], in sentence: String, ownWords: Set<String>) -> String? {
        let characters = Array(Digits.ascii(sentence))
        let dictionary = (language ?? .english).rawValue
        let tagged = language == .german ? tagger.names(in: sentence, language: dictionary) : []

        for (index, word) in sentenceWords.enumerated() where !word.isNumber && !ownWords.contains(word.folded) {
            let written = String(characters[word.range])
            let letters = written.filter(\.isLetter)
            let isCapitalised = characters[word.range.lowerBound].isUppercase
            guard letters.count < 2 || !letters.allSatisfy(\.isUppercase) else { return written }

            let isExplained = Vocabulary.explains(word.folded, in: language) || Vocabulary.isNeutral(word.folded, in: language)
            if language == .german {
                guard !tagged.contains(where: { $0.contains(word.range.lowerBound) }) else { return written }
                if !isExplained && (isCapitalised || letters.count >= 3) && wordList.knows(written, inLanguage: dictionary) == false {
                    return written
                }
            } else if isCapitalised {
                guard index == 0 || written == "I" else { return written }
                if !isExplained && wordList.knows(written.lowercased(), inLanguage: dictionary) == false { return written }
            } else if !isExplained && letters.count >= 3 && wordList.knows(written, inLanguage: dictionary) == false {
                return written
            }
        }
        return nil
    }
}

import Foundation

/// Why a claim check gave no usable answer (ADR 0028). Each case takes the unchecked path: the draft keeps its jobs, schools and prose,
/// loses its personal items, and says so.
enum ClaimCheckError: Error, Equatable {
    /// The answer does not number the items 1 to n, each once.
    case invalidAnswer
    /// The check did not finish within its time (`ClaimCheckLimits`).
    case timedOut
}

/// One verdict of a model's answer, as plain values: the item it numbers, the sentence it quotes and the stance it takes.
struct ClaimVerdictEntry: Equatable, Sendable {
    let item: Int
    let quote: String
    let stance: ClaimStance
}

/// Reads the answer of a model to a batch of candidates as one judgement for each, or refuses it (ADR 0028). The model is trusted for
/// nothing it does not show: the answer must number the items 1 to n, each once, and an item is a fact only when the model quotes
/// words of the description that contain the item and leave out nothing of their clause that withdraws the claim.
enum ClaimAnswer {
    /// The judgement of each candidate, in the order of `candidates`.
    /// - Throws: `ClaimCheckError.invalidAnswer` when the items of `entries` are not exactly 1 to n, each once: an answer that
    ///   skips, repeats or misnumbers an item cannot be matched to the candidates.
    /// - Note: A fact whose quote is empty, is not in `description`, does not contain the item or leaves out a word of negation, wish
    ///   or condition of its clause is judged `notMentioned`. That withdraws the item, as a verdict of the model would: the check only
    ///   ever removes.
    static func judgements(from entries: [ClaimVerdictEntry], of candidates: [ClaimCandidate], in description: String) throws -> [ClaimJudgement] {
        let ordered = entries.sorted { $0.item < $1.item }
        guard ordered.map(\.item) == Array(1..<(candidates.count + 1)) else { throw ClaimCheckError.invalidAnswer }

        let source = Source(description)
        return zip(candidates, ordered).map { candidate, entry in
            let backed = entry.stance != .fact || source.backs(entry.quote, theItem: candidate.value)
            return ClaimJudgement(stance: backed ? entry.stance : .notMentioned, quote: entry.quote)
        }
    }

    /// The description, as the words a quote is looked up in.
    private struct Source {
        /// The words of the description, sentence after sentence.
        private let words: [Word]
        /// For each word, whether it is the last of its sentence.
        private let endsASentence: [Bool]
        /// The indices of the words of each sentence.
        private let sentences: [Range<Int>]
        private let language: Vocabulary.Language?

        init(_ description: String) {
            var words: [Word] = []
            var endsASentence: [Bool] = []
            var sentences: [Range<Int>] = []
            for sentence in SentenceSplitter.sentences(in: description) {
                let read = Word.words(in: sentence)
                guard !read.isEmpty else { continue }
                sentences.append(words.count..<(words.count + read.count))
                words += read
                endsASentence += Array(repeating: false, count: read.count - 1) + [true]
            }
            self.words = words
            self.endsASentence = endsASentence
            self.sentences = sentences
            language = LanguageGuess.tag(of: description).flatMap(Vocabulary.Language.init(tag:))
        }

        /// Whether `quote` is words of the description, that contain `item` as whole words, and that leave out nothing which withdraws
        /// the claim. A model copies a sentence, but it also shortens one, as "I speak German" for "I speak English, German and
        /// Spanish": a quote is backed when its words run as they stand in the description, or follow one another within one of its
        /// sentences, and the clause it quotes holds no word of negation, wish or condition (`Vocabulary.withdrawals`) that the quote
        /// itself does not hold. "I speak German" is no quote of "I do not speak German", nor of "I speak German if needed", and
        /// "speak German" is none of them either.
        func backs(_ quote: String, theItem item: String) -> Bool {
            let quoted = Word.words(in: quote).map(\.folded)
            guard !quoted.isEmpty,
                  !DescriptionText.spans(of: DescriptionText.normalized(item), in: DescriptionText.normalized(quote)).isEmpty
            else { return false }
            return placements(of: quoted).contains(where: leavesOutNoWithdrawal)
        }

        /// Where the words of `quote` stand in the description, as the indices of the words they match: every stretch of the
        /// description that reads as the quote does, and for each word of a sentence that opens the quote the next words of the
        /// quote at their first place after it within that sentence.
        private func placements(of quote: [String]) -> [[Int]] {
            var placements: [[Int]] = []
            if quote.count <= words.count {
                for start in 0...(words.count - quote.count) where (0..<quote.count).allSatisfy({ words[start + $0].folded == quote[$0] }) {
                    placements.append(Array(start..<(start + quote.count)))
                }
            }
            for sentence in sentences {
                for start in sentence where words[start].folded == quote[0] {
                    var placement = [start]
                    for index in (start + 1)..<max(sentence.upperBound, start + 1) where placement.count < quote.count {
                        if words[index].folded == quote[placement.count] { placement.append(index) }
                    }
                    if placement.count == quote.count { placements.append(placement) }
                }
            }
            return placements
        }

        /// Whether the clause that the words at `placement` stand in, from the word after the last comma or semicolon before the
        /// first of them to the next comma or semicolon after the last (never beyond a sentence), holds no word that withdraws a claim
        /// besides the ones that the quote itself holds. Words between the first and the last of the quote are in the clause whatever
        /// stands between them: "I speak English, not German" does not give "I speak German".
        private func leavesOutNoWithdrawal(_ placement: [Int]) -> Bool {
            guard let first = placement.first, let last = placement.last else { return false }
            var start = first
            while start > 0, !words[start - 1].endsWithABreak, !endsASentence[start - 1] { start -= 1 }
            var end = last
            while end < words.count - 1, !words[end].endsWithABreak, !endsASentence[end] { end += 1 }

            let clause = Vocabulary.withdrawals(in: Array(words[start...end]), language: language)
            let quoted = Vocabulary.withdrawals(in: placement.map { words[$0] }, language: language)
            return clause.isSubset(of: quoted)
        }
    }
}

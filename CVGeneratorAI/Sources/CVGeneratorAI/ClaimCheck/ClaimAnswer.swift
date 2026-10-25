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
/// words of the description that contain the item.
enum ClaimAnswer {
    /// The judgement of each candidate, in the order of `candidates`.
    /// - Throws: `ClaimCheckError.invalidAnswer` when the items of `entries` are not exactly 1 to n, each once: an answer that
    ///   skips, repeats or misnumbers an item cannot be matched to the candidates.
    /// - Note: A fact whose quote is empty, is not in `description` or does not contain the item is judged `notMentioned`. That
    ///   withdraws the item, as a verdict of the model would: the check only ever removes.
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
        private let words: [String]
        private let sentences: [[String]]

        init(_ description: String) {
            words = Self.words(of: description)
            sentences = SentenceSplitter.sentences(in: description).map(Self.words(of:))
        }

        /// Whether `quote` is words of the description that contain `item` as whole words. A model copies a sentence, but it also
        /// shortens one, as "I speak German" for "I speak English, German and Spanish": a quote is backed when its words run as
        /// they stand in the description, or follow one another within one of its sentences.
        func backs(_ quote: String, theItem item: String) -> Bool {
            let quoted = Self.words(of: quote)
            guard !quoted.isEmpty,
                  Self.run(quoted, in: words) || sentences.contains(where: { Self.follows(quoted, in: $0) })
            else { return false }
            return !DescriptionText.spans(of: DescriptionText.normalized(item), in: DescriptionText.normalized(quote)).isEmpty
        }

        /// The words of a text, without case, accents or punctuation.
        private static func words(of text: String) -> [String] {
            DescriptionText.normalized(text).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        }

        /// Whether `quote` is a stretch of `words`.
        private static func run(_ quote: [String], in words: [String]) -> Bool {
            guard quote.count <= words.count else { return false }
            return (0...(words.count - quote.count)).contains { words[$0..<($0 + quote.count)].elementsEqual(quote) }
        }

        /// Whether the words of `quote` occur in `words` in the same order, with other words allowed between them.
        private static func follows(_ quote: [String], in words: [String]) -> Bool {
            var next = quote.startIndex
            for word in words where next < quote.endIndex && word == quote[next] {
                next += 1
            }
            return next == quote.endIndex
        }
    }
}

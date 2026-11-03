import Foundation

/// An answer of the model caught writing one stretch of text again and again (#354). Greedy sampling can fall into a loop on a
/// sentence or an item and write it until the session's window overflows, about 200 seconds later: jobs-de wrote one sentence of its
/// description over and over in a job's duties. On iOS 27 and macOS 27 the first pass streams its answer and stops it as soon as it
/// repeats (`FoundationModelsService.streamsAnswers`).
enum RepeatingAnswer {
    /// How many times one stretch is written back to back before the answer repeats: an answer asked again with sampling wrote one
    /// sentence of the description three times in a row, which the checks of the facts then leave as a quote.
    static let times = 4
    /// The lengths of a repeated stretch, in characters: a shorter one written `times` times is a word or a number written again, as
    /// in a list of years. Written many more times, it repeats as a longer stretch of its copies.
    static let stretches = 16...400
    /// The length of an answer, in bytes of its JSON, past which it repeats whatever it writes: the longest answer of the evaluation
    /// is under 2,000 characters, and an answer that loops on a stretch longer than `stretches` still ends here.
    static let longest = 8000
    /// How many bytes an answer grows between two checks: a check reads all its texts again.
    static let every = 64

    /// An answer streamed to its end, or stopped where it began to repeat.
    struct Watched<Answer> {
        let answer: Answer
        let repeats: Bool
    }

    /// The last element of `stream`, watched as it grows: the stream is left as soon as an element `repeats`, and that element is the
    /// answer. Nil when the stream ends with none.
    ///
    /// - Parameters:
    ///   - texts: The texts of an element, as `repeats` reads them.
    ///   - length: The length of an element, as `repeats` reads it; the element is checked each time it has grown by `every`, and
    ///     once more at the end.
    /// - Throws: What the stream throws.
    static func watch<Stream: AsyncSequence>(
        _ stream: Stream, texts: (Stream.Element) -> [String], length: (Stream.Element) -> Int,
        isolation: isolated (any Actor)? = #isolation
    ) async throws -> Watched<Stream.Element>? {
        var last: Stream.Element?
        var checked = 0
        for try await element in stream {
            last = element
            let size = length(element)
            guard size - checked >= every else { continue }
            checked = size
            if repeats(texts(element), length: size) { return Watched(answer: element, repeats: true) }
        }
        return last.map { Watched(answer: $0, repeats: repeats(texts($0), length: length($0))) }
    }

    /// Whether an answer so far repeats: one of its `texts` ends with a stretch written `times` times back to back, or its `length`
    /// is over `longest`.
    ///
    /// - Parameters:
    ///   - texts: The texts of the answer so far, each string and each list as one text with an item a line: the text the model is
    ///     writing is one of them.
    ///   - length: The length of the whole answer so far.
    static func repeats(_ texts: [String], length: Int) -> Bool {
        length > longest || texts.contains(where: endsRepeating)
    }

    /// Whether `text` ends with one stretch of `stretches` written `times` times back to back.
    static func endsRepeating(_ text: String) -> Bool {
        let tail = Array(text.unicodeScalars.suffix(stretches.upperBound * times))
        let end = tail.count
        return stretches.contains { length in
            guard length * times <= end else { return false }
            let last = tail[(end - length)...]
            return (1..<times).allSatisfy { tail[(end - length * ($0 + 1))..<(end - length * $0)] == last }
        }
    }
}

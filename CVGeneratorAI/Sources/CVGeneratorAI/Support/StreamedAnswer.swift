import Foundation

/// The last answer of a streamed call of the model (#354). The second pass streams its answer, so that an answer cut by its token
/// limit keeps what the model wrote before the cut: a whole answer would be lost to the cut, and asking again gives the same answer.
enum StreamedAnswer {
    /// The last element of a stream, and whether the stream ended on it or failed after it.
    struct Last<Answer> {
        let answer: Answer
        /// Whether the stream ended on its own: an answer the stream failed after may stop in the middle of a word.
        let isComplete: Bool
    }

    /// The last element of `stream`, or nil when it ends with none.
    ///
    /// - Parameter keepsPartial: Whether an error the stream fails with after an element leaves that element to keep, as the cut of
    ///   the token limit does. Any other error is thrown, and so is every error before the first element.
    /// - Throws: What the stream throws, as above; the cancellation of the task always.
    static func last<Stream: AsyncSequence>(
        of stream: Stream, keepingPartialAfter keepsPartial: (any Error) -> Bool, isolation: isolated (any Actor)? = #isolation
    ) async throws -> Last<Stream.Element>? {
        var last: Stream.Element?
        do {
            for try await element in stream {
                last = element
            }
        } catch {
            guard !(error is CancellationError), !Task.isCancelled, let last, keepsPartial(error) else { throw error }
            return Last(answer: last, isComplete: false)
        }
        return last.map { Last(answer: $0, isComplete: true) }
    }
}

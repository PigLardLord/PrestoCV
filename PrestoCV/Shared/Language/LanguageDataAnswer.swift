import Synchronization

/// The answer to one request for a language's data, which resumes its waiter exactly once: the first answer wins, from the system
/// or from a cancel, and a later one is dropped. An answer that comes before the wait starts is kept, and ends the wait as it starts.
final class LanguageDataAnswer: Sendable {
    private enum State {
        case notAsked
        case waiting(CheckedContinuation<LanguageDataOutcome, Never>)
        case answeredEarly(LanguageDataOutcome)
        case done
    }

    private let state = Mutex(State.notAsked)

    /// Starts the wait. Returns false when an answer came first: the wait has ended with it, and there is nothing to ask.
    func wait(_ continuation: CheckedContinuation<LanguageDataOutcome, Never>) -> Bool {
        let early: LanguageDataOutcome? = state.withLock { state in
            guard case .answeredEarly(let outcome) = state else {
                state = .waiting(continuation)
                return nil
            }
            state = .done
            return outcome
        }
        guard let early else { return true }
        continuation.resume(returning: early)
        return false
    }

    /// Ends the wait with `outcome`, unless an answer came first.
    func give(_ outcome: LanguageDataOutcome) {
        let waiter: CheckedContinuation<LanguageDataOutcome, Never>? = state.withLock { state in
            switch state {
            case .notAsked:
                state = .answeredEarly(outcome)
                return nil
            case .waiting(let continuation):
                state = .done
                return continuation
            case .answeredEarly, .done:
                return nil
            }
        }
        waiter?.resume(returning: outcome)
    }
}

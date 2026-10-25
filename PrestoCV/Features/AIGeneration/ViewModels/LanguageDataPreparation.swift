/// The wait for the language data that grounding a description needs (ADR 0023): the system is asked for it, and the wait ends with
/// the system's answer or, when the bound passes first, with `.notAvailable`. An answer after the bound is dropped. The bound holds
/// even if the system never answers and ignores the cancel.
@MainActor
struct LanguageDataPreparation {
    /// How long the person waits for the data at most, while the generating screen stays up.
    nonisolated static let bound: Duration = .seconds(60)

    private let requester: any LanguageDataRequesting
    private let sleep: @Sendable (Duration) async throws -> Void

    /// - Parameters:
    ///   - requester: What asks the system for the data.
    ///   - sleep: The wait of the bound, which ends early with an error when its task is cancelled.
    init(requester: any LanguageDataRequesting, sleep: @escaping @Sendable (Duration) async throws -> Void) {
        self.requester = requester
        self.sleep = sleep
    }

    /// Asks for the data of `language`, a BCP 47 code, and waits for it at most `bound`. Cancelled, it returns `.notAvailable` at once.
    func prepare(language: String) async -> LanguageDataOutcome {
        let (answers, answer) = AsyncStream.makeStream(of: LanguageDataOutcome.self)
        let request = Task { [requester] in
            let outcome = await requester.requestLexicalClassData(forLanguage: language)
            answer.yield(outcome)
        }
        let timer = Task { [sleep] in
            do {
                try await sleep(Self.bound)
            } catch {
                // A cancelled timer gives no answer: only a bound that has passed does
                return
            }
            answer.yield(.notAvailable)
        }
        defer {
            request.cancel()
            timer.cancel()
            answer.finish()
        }
        // The first answer ends the wait; a cancelled task's stream ends with none
        for await outcome in answers {
            return outcome
        }
        return .notAvailable
    }
}

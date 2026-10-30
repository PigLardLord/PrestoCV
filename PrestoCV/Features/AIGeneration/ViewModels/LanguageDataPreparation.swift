import CVGeneratorAI
import DiagnosticLogging

/// The wait for the language data that grounding a description needs (ADR 0023): the system is asked for it, and the wait ends with
/// the system's answer or, when the bound passes first, with `.notAvailable`. An answer after the bound is dropped. The bound holds
/// even if the system never answers and ignores the cancel. Each wait ends with a `draft.languageData` entry (ADR 0030): how it
/// ended and how long it took, never the language.
@MainActor
struct LanguageDataPreparation {
    /// How long the person waits for the data at most, while the generating screen stays up.
    nonisolated static let bound: Duration = .seconds(60)

    private let requester: any LanguageDataRequesting
    private let waitsAtMost: Duration
    private let sleep: @Sendable (Duration) async throws -> Void
    private let logger: any DiagnosticLogger
    private let clock: any Clock<Duration>

    /// - Parameters:
    ///   - requester: What asks the system for the data.
    ///   - bound: How long the wait lasts at most. The app uses `LanguageDataPreparation.bound`; a debug launch shortens it.
    ///   - sleep: The wait of the bound, which ends early with an error when its task is cancelled.
    ///   - logger: Where the end of each wait is written.
    ///   - clock: The clock the wait is measured on.
    init(
        requester: any LanguageDataRequesting, bound: Duration = LanguageDataPreparation.bound,
        sleep: @escaping @Sendable (Duration) async throws -> Void, logger: any DiagnosticLogger, clock: any Clock<Duration>
    ) {
        self.requester = requester
        self.waitsAtMost = bound
        self.sleep = sleep
        self.logger = logger
        self.clock = clock
    }

    /// Asks for the data of `language`, a BCP 47 code, and waits for it at most the bound. Cancelled, it returns `.notAvailable` at once.
    func prepare(language: String) async -> LanguageDataOutcome {
        let stopwatch = Stopwatch(started: clock)
        let answer = await wait(for: language)
        log(answer, elapsed: stopwatch.elapsed)
        return answer ?? .notAvailable
    }

    /// The first answer: the system's, or `.notAvailable` from the bound; nil when the wait's task was cancelled first.
    private func wait(for language: String) async -> LanguageDataOutcome? {
        let (answers, answer) = AsyncStream.makeStream(of: LanguageDataOutcome.self)
        let request = Task { [requester] in
            let outcome = await requester.requestLexicalClassData(forLanguage: language)
            answer.yield(outcome)
        }
        let timer = Task { [sleep] in
            do {
                try await sleep(waitsAtMost)
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
        return nil
    }

    /// Info when the data came; notice when it did not, or the person left first.
    private func log(_ answer: LanguageDataOutcome?, elapsed: Duration) {
        switch answer {
        case .available?:
            logger.info(.draft, "draft.languageData", .token("outcome", "available"), .duration("elapsed", elapsed))
        case .notAvailable?:
            logger.notice(.draft, "draft.languageData", .token("outcome", "notAvailable"), .duration("elapsed", elapsed))
        case nil:
            logger.notice(.draft, "draft.languageData", .token("outcome", "cancelled"), .duration("elapsed", elapsed))
        }
    }
}

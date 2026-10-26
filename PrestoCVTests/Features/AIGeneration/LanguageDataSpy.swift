import Foundation
@testable import PrestoCV

/// Records the languages whose data the app asks the system for, and answers as the test says: at once with `outcome`, or, when
/// `outcome` is nil, only when the test calls `answerHeld(_:)`, whatever cancels the request, as a system that never answers.
@MainActor
final class LanguageDataSpy: LanguageDataRequesting {
    private(set) var requests: [String] = []
    /// The answer to every request; nil holds each one until `answerHeld(_:)`.
    var outcome: LanguageDataOutcome? = .notAvailable
    /// Runs as the spy answers `.available`: the data arrives on the device.
    var onAvailable: @MainActor () -> Void = {}

    private var held: [CheckedContinuation<LanguageDataOutcome, Never>] = []
    private var heldCount = 0
    private var heldWaiters = CountWaiters()

    func requestLexicalClassData(forLanguage language: String) async -> LanguageDataOutcome {
        requests.append(language)
        guard let outcome else {
            return await withCheckedContinuation { continuation in
                held.append(continuation)
                heldCount += 1
                heldWaiters.reach(heldCount)
            }
        }
        return answer(outcome)
    }

    /// Answers every request being held, late.
    func answerHeld(_ outcome: LanguageDataOutcome) {
        let waiting = held
        held = []
        let answer = answer(outcome)
        waiting.forEach { $0.resume(returning: answer) }
    }

    /// Returns once `count` requests have been held since the spy was made.
    func waitUntilHeld(_ count: Int) async {
        await withCheckedContinuation { continuation in
            heldWaiters.add(UUID(), waitingFor: count, continuation, reached: heldCount)
        }
    }

    private func answer(_ outcome: LanguageDataOutcome) -> LanguageDataOutcome {
        if outcome == .available { onAvailable() }
        return outcome
    }
}

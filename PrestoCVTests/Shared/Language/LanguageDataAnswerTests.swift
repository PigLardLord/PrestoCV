import Testing
@testable import PrestoCV

@Suite("LanguageDataAnswer - one request for language data ends once, with the first answer", .timeLimit(.minutes(1)))
struct LanguageDataAnswerTests {
    @Test("An answer given while the request waits ends it")
    func answerEndsTheWait() async {
        let answer = LanguageDataAnswer()
        var asks = false

        let outcome = await withCheckedContinuation { continuation in
            asks = answer.wait(continuation)
            answer.give(.available)
        }

        #expect(asks, "Nothing had answered, so the system is asked")
        #expect(outcome == .available)
    }

    @Test("An answer that comes before the wait, as a cancel does, ends the wait as it starts, and nothing is asked")
    func earlyAnswerEndsTheWaitAtOnce() async {
        let answer = LanguageDataAnswer()
        answer.give(.notAvailable)
        var asks = true

        let outcome = await withCheckedContinuation { continuation in
            asks = answer.wait(continuation)
        }

        #expect(!asks)
        #expect(outcome == .notAvailable)
    }

    @Test("The first answer wins: a later one, from the system or a cancel, is dropped")
    func firstAnswerWins() async {
        let answer = LanguageDataAnswer()

        let outcome = await withCheckedContinuation { continuation in
            _ = answer.wait(continuation)
            answer.give(.notAvailable)
            answer.give(.available)
        }

        #expect(outcome == .notAvailable)
    }
}

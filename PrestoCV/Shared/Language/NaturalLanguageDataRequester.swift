import NaturalLanguage

/// Asks the NaturalLanguage framework to download a language's data, and reads its answer: `.available` only when the framework
/// says so; "not available", an error and a cancelled request are all `.notAvailable`. It decides nothing else: how long the app
/// waits is `LanguageDataPreparation`'s, which cancels the request when its bound passes.
struct NaturalLanguageDataRequester: LanguageDataRequesting {
    func requestLexicalClassData(forLanguage language: String) async -> LanguageDataOutcome {
        let answer = LanguageDataAnswer()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard answer.wait(continuation) else { return }
                // The framework calls back on a queue of its own: the closure must not be the main actor's
                NLTagger.requestAssets(for: NLLanguage(rawValue: language), tagScheme: .lexicalClass) { @Sendable result, _ in
                    answer.give(result == .available ? .available : .notAvailable)
                }
            }
        } onCancel: {
            answer.give(.notAvailable)
        }
    }
}

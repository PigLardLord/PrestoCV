#if DEBUG
import CVGeneratorAI
import Synchronization

/// Debug launch argument that scripts the language data of English and German, for UI tests (issue #270). Release builds do not
/// read it.
///
/// - `-LanguageDataOverride arrives`: the device has no language data until the app asks the system for it, which gives it at once.
/// - `-LanguageDataOverride neverArrives`: the device has no language data, and the system never answers the app's request, so
///   the app's wait ends at its bound.
///
/// Either way no word is tagged as a verb, so that a description gives the same draft on every simulator, whatever data it has.
struct LanguageDataOverride {
    static let launchArgument = "-LanguageDataOverride"

    /// What tells the verbs: it tags a language once its data has arrived.
    let tagger: any LexicalTagger
    /// What asks the system for the data.
    let requester: any LanguageDataRequesting

    /// The language data this launch scripted, if it did. It reads the launch arguments themselves, as `AIAvailabilityOverride` does.
    @MainActor
    static func current(arguments: [String]) -> LanguageDataOverride? {
        guard let index = arguments.firstIndex(of: launchArgument), arguments.indices.contains(index + 1) else { return nil }
        let data = ScriptedLanguageData()
        switch arguments[index + 1] {
        case "arrives": return LanguageDataOverride(tagger: data, requester: ArrivingLanguageData(data: data))
        case "neverArrives": return LanguageDataOverride(tagger: data, requester: SilentLanguageData())
        default: return nil
        }
    }
}

/// The language data of a scripted device: none until it arrives, then every language's, with no word tagged as a verb.
private final class ScriptedLanguageData: LexicalTagger {
    private let arrived = Mutex(false)

    func arrive() {
        arrived.withLock { $0 = true }
    }

    func tagsLexicalClass(inLanguage language: String) -> Bool {
        arrived.withLock { $0 }
    }

    func verbs(in text: String, language: String) -> [Range<Int>] {
        []
    }
}

/// A system that gives the data at once.
@MainActor
private struct ArrivingLanguageData: LanguageDataRequesting {
    let data: ScriptedLanguageData

    func requestLexicalClassData(forLanguage language: String) async -> LanguageDataOutcome {
        data.arrive()
        return .available
    }
}

/// A system that never answers: a request ends only when it is cancelled, with `.notAvailable`.
@MainActor
private struct SilentLanguageData: LanguageDataRequesting {
    func requestLexicalClassData(forLanguage language: String) async -> LanguageDataOutcome {
        let answer = LanguageDataAnswer()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                _ = answer.wait(continuation)
            }
        } onCancel: {
            answer.give(.notAvailable)
        }
    }
}
#endif

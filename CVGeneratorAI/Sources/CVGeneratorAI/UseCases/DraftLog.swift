import DiagnosticLogging
import Foundation

// MARK: - What the AI draft logs (ADR 0030)

extension LogCategory {
    /// The AI draft of a CV, from the availability of the model to the checked draft.
    static let draft = LogCategory("draft")
}

/// The entries of the AI draft: whether the model can run, the language of the description and its data, the generation from its
/// start to its end, the guardrails, the claims withdrawn and the rules that rejected the draft. Counts, names and times only: no
/// word of the description or of the draft, which stay on the device and out of the log.
struct DraftLog {
    /// The step a generation had reached when it stopped.
    enum Stage: Equatable {
        /// The model writes the draft.
        case model
        /// The rules keep what the description supports (ADR 0023).
        case grounding
        /// The second check of the personal items (ADR 0028).
        case claimCheck
        /// The check of what is left.
        case result

        var logName: StaticString {
            switch self {
            case .model: "model"
            case .grounding: "grounding"
            case .claimCheck: "claimCheck"
            case .result: "result"
            }
        }
    }

    let logger: any DiagnosticLogger

    /// Whether the model can run, and why not when it cannot: then a notice, since the person sees the draft is not offered.
    func availability(_ availability: AIAvailability) {
        switch availability {
        case .available:
            logger.info(.draft, "draft.availability", .flag("available", true))
        case .unavailable(let reason):
            logger.notice(.draft, "draft.availability", .flag("available", false), .token("reason", reason.logName))
        }
    }

    /// A draft asked for while the model cannot run.
    func unavailable(_ reason: AIAvailability.Reason) {
        logger.notice(.draft, "draft.unavailable", .token("reason", reason.logName))
    }

    /// A description the rules of the request reject, before the model is asked.
    func rejectedRequest(_ error: any Error) {
        logger.notice(.draft, "draft.rejected", .token("check", "request"), .error(error))
    }

    /// The language of the description, and whether grounding it needs the device's language data and finds it; a notice when
    /// the data is missing, since the person is then asked to wait for it.
    func language(_ check: LanguageCheck) {
        var fields: [LogField] = [.flag("supported", check.language != nil)]
        if let language = check.language { fields.append(.token("language", language.logName)) }
        fields.append(.token("data", check.data.logName))
        logger.log(LogEntry(level: check.data == .missing ? .notice : .info, category: .draft, event: "draft.language", fields: fields))
    }

    /// The model is asked, with a description of so many characters.
    func started(characters: Int) {
        logger.info(.draft, "draft.started", .count("characters", characters))
    }

    /// The personal items the claim check judged and those it withdrew, and whether it gave no answer: a notice when it withdrew
    /// one, since the person then sees fewer items than the model wrote.
    func claims(of grounded: CVData, checked: GeneratedDraft) {
        let candidates = ClaimCandidates.of(grounded)
        let kept = Set(ClaimCandidates.of(checked.cvData))
        let withdrawn = candidates.count { !kept.contains($0) }
        let fields: [LogField] = [
            .count("checked", candidates.count), .count("withdrawn", withdrawn), .flag("unchecked", checked.personalItemsUnchecked),
        ]
        logger.log(LogEntry(level: withdrawn > 0 ? .notice : .info, category: .draft, event: "draft.claims", fields: fields))
    }

    func finished(elapsed: Duration) {
        logger.info(.draft, "draft.finished", .duration("elapsed", elapsed))
    }

    /// How a generation that did not finish stopped: cancelled, refused by the model's guardrails, rejected by the check of the
    /// result, or failed at a step.
    func stopped(at stage: Stage, by error: any Error, elapsed: Duration) {
        if error is CancellationError {
            logger.info(.draft, "draft.cancelled", .token("stage", stage.logName), .duration("elapsed", elapsed))
        } else if error as? CVGenerationError == .contentNotAllowed {
            logger.notice(.draft, "draft.refused", .duration("elapsed", elapsed))
        } else if stage == .result {
            logger.notice(.draft, "draft.rejected", .token("check", "result"), .error(error), .duration("elapsed", elapsed))
        } else {
            logger.error(.draft, "draft.failed", .token("stage", stage.logName), .error(error), .duration("elapsed", elapsed))
        }
    }
}

// MARK: - Names

extension CVGenerationError: LoggableError {
    public var logCode: StaticString {
        switch self {
        case .unavailable: "unavailable"
        case .descriptionTooShort: "descriptionTooShort"
        case .descriptionTooLong: "descriptionTooLong"
        case .contentNotAllowed: "contentNotAllowed"
        case .unsupportedLanguage: "unsupportedLanguage"
        case .busy: "busy"
        case .generationFailed: "generationFailed"
        case .serviceFailed: "serviceFailed"
        case .emptyResult: "emptyResult"
        case .languageDataUnavailable: "languageDataUnavailable"
        }
    }
}

extension AIAvailability.Reason {
    var logName: StaticString {
        switch self {
        case .deviceNotEligible: "deviceNotEligible"
        case .appleIntelligenceNotEnabled: "appleIntelligenceNotEnabled"
        case .modelNotReady: "modelNotReady"
        case .unknown: "unknown"
        }
    }
}

extension Vocabulary.Language {
    /// The BCP 47 code of the language.
    var logName: StaticString {
        switch self {
        case .english: "en"
        case .italian: "it"
        case .german: "de"
        case .spanish: "es"
        case .french: "fr"
        case .portuguese: "pt"
        }
    }
}

extension LanguageCheck.LanguageData {
    var logName: StaticString {
        switch self {
        case .notNeeded: "notNeeded"
        case .present: "present"
        case .missing: "missing"
        }
    }
}

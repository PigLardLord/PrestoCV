#if DEBUG
import Foundation
import CVGeneratorAI

/// Debug launch arguments that script the AI draft, for UI tests and end-to-end tests (ADR 0028). Release builds do not read them.
///
/// - `-PrestoCVUITestsScriptedDraft nurse`: the model is not asked; it answers with the draft of `nurseDescription` at once, so
///   that a simulator that cannot run the model still reaches the editor. The rules of ADR 0023 and the claim check still run.
/// - `-PrestoCVUITestsClaimCheck fail`: the claim check gives no answer, so the draft opens without its personal items and with
///   the notice that says so.
enum AIDraftScript {
    static let scriptedDraftArgument = "-PrestoCVUITestsScriptedDraft"
    static let claimCheckArgument = "-PrestoCVUITestsClaimCheck"

    /// The description the scripted draft is written from. It is in Italian, whose rules need no lexical data of the device: a
    /// simulator erased for a test run has none of English or German until it downloads it.
    static let nurseDescription = "Sono infermiera presso San Camillo a Roma dal 2015. Uso Excel ogni giorno."

    /// The model a UI test asked for in place of the device's, if any.
    @MainActor
    static func service(arguments: [String]) -> (any CVGenerationService)? {
        value(of: scriptedDraftArgument, in: arguments) == "nurse" ? ScriptedGeneration(draft: nurse) : nil
    }

    /// The claim check a UI test asked for in place of the device's, if any.
    static func claimChecker(arguments: [String]) -> (any ClaimChecking)? {
        value(of: claimCheckArgument, in: arguments) == "fail" ? FailingClaimCheck() : nil
    }

    /// What the model drafts from `nurseDescription`.
    private static let nurse = CVData(
        personalInfo: PersonalInfo(location: "Roma", title: "Infermiera"),
        experience: [Experience(title: "Infermiera", company: "San Camillo", location: "Roma", startDate: "2015", current: true)],
        skills: [Skill(name: "Excel")]
    )

    /// The value that follows `argument`, if both are there.
    private static func value(of argument: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: argument), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// A model that can always run and answers with one draft at once.
    @MainActor
    private struct ScriptedGeneration: CVGenerationService {
        let draft: CVData

        func availability() -> AIAvailability { .available }

        func generateCV(from request: CVGenerationRequest) async throws -> CVData { draft }
    }

    /// A claim check that gives no answer, as when the model fails or refuses.
    private struct FailingClaimCheck: ClaimChecking {
        struct NoAnswer: Error {}

        func judgements(of candidates: [ClaimCandidate], in description: String) async throws -> [ClaimJudgement] {
            throw NoAnswer()
        }
    }
}
#endif

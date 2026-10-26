#if DEBUG
import Testing
import CVGeneratorAI
@testable import PrestoCV

/// The debug launch arguments that script the AI draft (ADR 0028), so that a UI test on a simulator that cannot run the model, and
/// an end-to-end test that needs a claim check with no answer, reach the editor with the notice of an unchecked draft.
@Suite("AIDraftScript Tests")
struct AIDraftScriptTests {
    private static let scripted = ["PrestoCV", AIDraftScript.scriptedDraftArgument, "nurse"]
    private static let failing = ["PrestoCV", AIDraftScript.claimCheckArgument, "fail"]

    @Test("Without its launch arguments, or with a value it does not know, nothing is scripted", arguments: [
        ["PrestoCV"], ["PrestoCV", AIDraftScript.scriptedDraftArgument], ["PrestoCV", AIDraftScript.claimCheckArgument],
        ["PrestoCV", AIDraftScript.scriptedDraftArgument, "doctor", AIDraftScript.claimCheckArgument, "pass"],
    ])
    @MainActor
    func nothingIsScriptedWithoutTheArguments(arguments: [String]) {
        #expect(AIDraftScript.service(arguments: arguments) == nil)
        #expect(AIDraftScript.claimChecker(arguments: arguments) == nil)
    }

    @Test("The scripted model can run, and answers with the draft of the nurse")
    @MainActor
    func scriptedModelAnswersTheNurse() async throws {
        let service = try #require(AIDraftScript.service(arguments: Self.scripted))

        let draft = try await service.generateCV(from: CVGenerationRequest(userPrompt: AIDraftScript.nurseDescription))

        #expect(service.availability() == .available, "A simulator that cannot run the model still reaches the editor")
        #expect(draft.experience.map(\.company) == ["San Camillo"])
        #expect(draft.skills.map(\.name) == ["Excel"])
    }

    @Test("The scripted claim check gives no answer")
    func scriptedCheckFails() async throws {
        let checker = try #require(AIDraftScript.claimChecker(arguments: Self.failing))

        await #expect(throws: (any Error).self) {
            try await checker.judgements(of: [ClaimCandidate(kind: .skill, value: "Excel")], in: AIDraftScript.nurseDescription)
        }
    }

    @Test("The scripted draft with a check that gives no answer keeps the job and leaves the personal items blank")
    @MainActor
    func scriptedDraftIsUnchecked() async throws {
        let arguments = Self.scripted + Array(Self.failing.dropFirst())
        let useCase = CVGeneratorUseCase(
            service: try #require(AIDraftScript.service(arguments: arguments)),
            claimChecker: try #require(AIDraftScript.claimChecker(arguments: arguments)),
            sanitizer: CVDataSanitizer(lexicalClasses: FakeLexicalTagger.withoutData)
        )

        let draft = try await useCase.generateCV(from: CVGenerationRequest(userPrompt: AIDraftScript.nurseDescription))

        #expect(draft.personalItemsUnchecked)
        #expect(draft.cvData.experience.map(\.company) == ["San Camillo"], "What the check does not judge stays")
        #expect(draft.cvData.skills.isEmpty && draft.cvData.languages.isEmpty && draft.cvData.interests.isEmpty)
        #expect(draft.cvData.personalInfo.title == nil && draft.cvData.personalInfo.location == nil)
    }
}
#endif

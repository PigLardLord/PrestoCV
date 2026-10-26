import Testing
import Foundation
import CryptoKit
@testable import CVGeneratorAI

/// What the on-device claim check says to the model (ADR 0028). Its instructions and its prompt are what the measurements of the
/// ADR were made with: a change to either is a new measurement, so these tests fail on it, and say what to do.
@Suite("Claim check: what the model is asked")
struct FoundationModelsClaimCheckerTests {
    /// The SHA-256 of `FoundationModelsClaimChecker.instructions`, as the evaluation measured them.
    private let measuredInstructions = "186882b2ff45b54994e49ee050289889a566a710596a1ca4d2c0775c181c6ed3"

    @Test("The instructions are the ones the evaluation measured")
    func instructionsAreTheMeasuredOnes() {
        let digest = SHA256.hash(data: Data(FoundationModelsClaimChecker.instructions.utf8)).map { String(format: "%02x", $0) }.joined()

        #expect(digest == measuredInstructions, """
            The instructions changed. Run `ClaimCheckEvaluation` on a device with the model (the ADR 0028 measurements), then \
            set `measuredInstructions` to \(digest).
            """)
    }

    @Test("The prompt gives the description between triple quotes, then the items, numbered from 1 and labelled by kind")
    func promptLayout() {
        let candidates = [
            ClaimCandidate(kind: .title, value: "primary school teacher"), ClaimCandidate(kind: .place, value: "Bologna"),
            ClaimCandidate(kind: .skill, value: "Swift"), ClaimCandidate(kind: .language, value: "German"),
            ClaimCandidate(kind: .interest, value: "chess"),
        ]

        let prompt = FoundationModelsClaimChecker.prompt(for: candidates, in: "I teach.\nI like chess.")

        #expect(prompt == #"""
            Description:
            """
            I teach.
            I like chess.
            """

            Items:
            1. the writer's job title: primary school teacher
            2. the place where the writer lives or works: Bologna
            3. skill: Swift
            4. language the writer speaks: German
            5. hobby or interest: chess
            """#)
    }

    @Test("A batch is numbered from 1, whatever the position of its items in the draft")
    func batchesAreNumberedFromOne() {
        let prompt = FoundationModelsClaimChecker.prompt(for: [ClaimCandidate(kind: .skill, value: "Kotlin")], in: "I know Kotlin.")

        #expect(prompt.hasSuffix("Items:\n1. skill: Kotlin"))
    }
}

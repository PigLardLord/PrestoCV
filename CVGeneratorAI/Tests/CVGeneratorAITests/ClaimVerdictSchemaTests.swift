#if canImport(FoundationModels)
import Testing
import Foundation
import FoundationModels
@testable import CVGeneratorAI

/// The shape of the answer that the claim check asks the on-device model for (ADR 0028): one verdict for each candidate, no more and
/// no fewer. The model is not called here; the request is read as the model receives it.
@Suite("Claim check: the shape of the answer")
struct ClaimVerdictSchemaTests {
    @Test("The answer holds exactly one verdict for each candidate of the batch", arguments: [1, 2, 3, 8])
    func oneVerdictForEachCandidate(count: Int) throws {
        let verdicts = try Self.verdictsProperty(of: FoundationModelsClaimChecker.schema(forCandidates: count))

        #expect(verdicts["type"] as? String == "array", "\(count) candidates: the verdicts are a list")
        #expect(verdicts["minItems"] as? Int == count, "\(count) candidates: the list cannot be shorter than the batch")
        #expect(verdicts["maxItems"] as? Int == count, "\(count) candidates: the list cannot be longer than the batch, whatever the model finds to say")
    }

    @Test("Each verdict names the item, quotes its sentence, and says whose it is and how the sentence states it")
    func eachVerdictHasTheFieldsTheReadingNeeds() throws {
        let root = try Self.json(of: FoundationModelsClaimChecker.schema(forCandidates: 1))
        let definitions = try #require(root["$defs"] as? [String: Any])
        let verdict = try #require(definitions["ClaimVerdict"] as? [String: Any])
        let properties = try #require(verdict["properties"] as? [String: Any])

        #expect(Set(properties.keys) == ["item", "quote", "owner", "mood"], "the fields of a verdict")
        #expect(verdict["additionalProperties"] as? Bool == false, "a verdict holds nothing else")
    }

    // MARK: - Reading the schema

    private static func json(of schema: GenerationSchema) throws -> [String: Any] {
        let data = try JSONEncoder().encode(schema)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func verdictsProperty(of schema: GenerationSchema) throws -> [String: Any] {
        let properties = try #require(try json(of: schema)["properties"] as? [String: Any])
        return try #require(properties[FoundationModelsClaimChecker.verdictsProperty] as? [String: Any])
    }
}
#endif

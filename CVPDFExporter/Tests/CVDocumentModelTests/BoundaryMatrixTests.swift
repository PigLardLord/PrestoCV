import Testing
import Foundation

@Suite("ADR 0002 · the schema and the exporter agree at every boundary")
struct BoundaryMatrixTests {
    /// The schema must not refuse what the exporter accepts. It may accept what the exporter refuses only on a rule that
    /// JSON Schema lacks: the order of a period's dates, and the byte limit on the one change that probes it. Every change
    /// also states what the exporter is expected to say, so that a matrix that stops probing a boundary fails.
    @Test("the schema and the exporter agree on every change to every field", arguments: BoundaryMatrix.cases)
    func agreement(testCase: BoundaryCase) throws {
        let text = BoundaryMatrix.render(testCase)
        let violations = try CommittedSchema.validator().violations(of: JSON(parsing: text))
        let verdict = Exporter.verdict(for: text)

        switch (violations.isEmpty, verdict) {
        case (false, .accepted):
            Issue.record("the schema refuses what the exporter accepts: \(violations)")
        case (true, .refused(let reason)):
            let rule = Exporter.rule(of: reason)
            let isKnownGap = rule == .periodOrder || (rule == .textRules && testCase.premise == .exceedsSchema)
            #expect(isKnownGap, "the schema accepts what the exporter refuses: \(reason)")
        default:
            break
        }

        switch (testCase.premise, verdict) {
        case (.exporterAccepts, .refused(let reason)):
            #expect(Exporter.rule(of: reason) == .periodOrder, "the exporter refuses a change taken to be valid: \(reason)")
        case (.exporterRefuses, .accepted), (.exceedsSchema, .accepted):
            Issue.record("the exporter accepts a change taken to be invalid")
        case (.exceedsSchema, .refused(let reason)):
            #expect(Exporter.rule(of: reason) == .textRules, "the exporter refuses on a rule other than the byte limit: \(reason)")
        default:
            break
        }
    }

    @Test("the matrix knows the bounds of every integer field of the document")
    func bounds() {
        #expect(BoundaryMatrix.integerFields.subtracting(BoundaryMatrix.bounds.keys) == [])
        #expect(BoundaryMatrix.integerFields == Set(BoundaryMatrix.bounds.keys))
    }

    @Test("the matrix starts from a document and changes more than each node once")
    func coverage() {
        #expect(BoundaryMatrix.populated != .null)
        #expect(BoundaryMatrix.cases.count > BoundaryMatrix.nodes.count)
    }
}

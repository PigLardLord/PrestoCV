import Testing
import Foundation

// Whether a run set the drafting evaluation wrote is GO (#202). The evaluation itself passes with no hard finding; the fields the
// counter can only send to review (review.json) are read by a person, who records the reading in adjudication.json beside them:
//
//     {"reviewer": "<who>", "revision": "<the revision of the set>", "entries": [{"key": "<key in review.json>", "decision": "accept" | "reject", "note": "<why>"}]}
//
// PRESTOCV_DRAFT_EVAL_READY names the folder of a run set. The check needs no model and runs on any host. It fails with every reason
// the set is not GO: a hard finding, a partial or unfinished set, a revision that is not recorded, an item nobody decided, a decision
// of another revision, a rejected item.

private let readyFolder = ProcessInfo.processInfo.environment["PRESTOCV_DRAFT_EVAL_READY"].flatMap { $0.isEmpty ? nil : $0 }

@Suite("Drafting evaluation: is the run set GO", .enabled(if: readyFolder != nil))
struct DraftingReadiness {
    @Test("The run set in PRESTOCV_DRAFT_EVAL_READY is complete, has no hard finding, and every review item is decided at its revision")
    func isGo() throws {
        let folder = try URL(fileURLWithPath: #require(readyFolder))

        let readiness = try RunFolder.readiness(of: folder)

        #expect(readiness == .go, "\(readiness)")
    }
}

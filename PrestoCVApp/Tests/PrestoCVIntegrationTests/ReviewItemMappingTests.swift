import Testing
import Foundation
import PrestoCVImporting
import PrestoCVImportingTestSupport
import PrestoCVIntegration
import PrestoCVWorkflowPorts

@Suite("Review item mapping")
struct ReviewItemMappingTests {
    @Test("every reason the import gives has a reason of its own in the port, and no two share one")
    func everyCheckReasonHasAReviewReason() {
        let reasons = CheckReason.allCases.map(ReviewItemMapping.reason)
        #expect(Set(reasons).count == CheckReason.allCases.count)
        #expect(CheckReason.allCases.map(\.rawValue) == reasons.map(\.rawValue), "the codes keep their names")
    }

    @Test("entries are counted from one, as the person counts them")
    func entryChecksAreCountedFromOne() {
        let cases: [(ReviewItem.Field, ImportReviewField)] = [
            (.name, .name), (.title, .title), (.location, .location), (.summary, .summary),
            (.experience(0), .experience(1)), (.experiencePeriod(2), .experiencePeriod(3)),
            (.education(0), .education(1)), (.educationPeriod(1), .educationPeriod(2)), (.language(4), .language(5)),
        ]
        for (core, port) in cases { #expect(ReviewItemMapping.field(core) == port) }
    }

    @Test("the text of an item is the person's text, unchanged")
    func reviewTextIsThePersonsText() {
        let f = ImportFixture(text: "Ada  Lovelace — Analytical")
        var cv = ImportedCV()
        cv.person.name = f.quoted("Ada  Lovelace", check: .nameByPosition)
        let items = f.result(cv).reviewList.map(ReviewItemMapping.item)
        #expect(items == [ImportReviewItem(field: .name, reason: .nameByPosition, text: "Ada  Lovelace")])
    }
}

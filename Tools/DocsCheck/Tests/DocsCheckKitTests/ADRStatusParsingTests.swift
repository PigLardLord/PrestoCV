import Testing
@testable import DocsCheckKit

@Suite("Check 3 · ADR status text")
struct ADRStatusParsingTests {
    @Test("the plain statuses are recognised, exactly as written", arguments: [
        ("Proposed", ADRStatus.proposed), ("Accepted", .accepted), ("Rejected", .rejected),
    ])
    func plain(text: String, status: ADRStatus) {
        #expect(ADRStatus(text: text) == status)
        #expect(ADRStatus(text: "  \(text) \t") == status)
    }

    @Test("anything else is not a status", arguments: [
        "", "accepted", "ACCEPTED", "Accepted (amended)", "Accepted, superseded", "Draft", "Deprecated", "Superseded", "Proposed by Ada",
    ])
    func unknown(text: String) {
        #expect(ADRStatus(text: text) == nil)
    }

    @Test("a superseded ADR carries the link to its replacement")
    func superseded() {
        #expect(ADRStatus(text: "Superseded by [0013](0013-new.md)") == .supersededBy(link: "0013-new.md"))
        #expect(ADRStatus(text: "Superseded by [ADR 0013](../adr/0013-new.md#decision)") == .supersededBy(link: "../adr/0013-new.md"))
    }

    @Test("a superseded ADR without a link is still recognised, so it can be reported")
    func supersededWithoutLink() {
        #expect(ADRStatus(text: "Superseded by 0013") == .supersededBy(link: nil))
        #expect(ADRStatus(text: "Superseded by [the new one](https://example.com/x.md)") == .supersededBy(link: nil))
    }

    @Test("the number of the replacement is the number in its file name", arguments: [
        ("0013-new.md", "0013"), ("dir/0007-x-y.md", "0007"), ("../adr/0100-a.md", "0100"),
    ])
    func successorNumber(link: String, number: String) {
        #expect(ADRStatus.supersededBy(link: link).successorNumber == number)
    }

    @Test("a link that is not to an ADR file has no number", arguments: ["README.md", "13-new.md", "0013new.md", "0013-new.txt", "0013-.md"])
    func noSuccessorNumber(link: String) {
        #expect(ADRStatus.supersededBy(link: link).successorNumber == nil)
    }

    @Test("two statuses are the same when they say the same thing")
    func comparison() {
        #expect(ADRStatus.supersededBy(link: "0013-a.md").summary == ADRStatus.supersededBy(link: "./0013-a.md").summary)
        #expect(ADRStatus.supersededBy(link: "0013-a.md").summary != ADRStatus.supersededBy(link: "0014-a.md").summary)
        #expect(ADRStatus.accepted.summary == "Accepted")
        #expect(ADRStatus.supersededBy(link: "0013-a.md").summary == "Superseded by 0013")
    }
}

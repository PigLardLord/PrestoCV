import Testing
@testable import CVRendering

@Suite("DocumentCompleteness · a search that runs out of steps fails closed")
struct CompletenessBudgetTests {
    @Test("when the budget runs out before a placement is found, the last text is named although a placement exists")
    func exhaustedBudgetNamesTheLastText() {
        #expect(DocumentCompleteness.missing(in: "a b", expected: ["a", "b"]).isEmpty)
        #expect(DocumentCompleteness.missing(in: "a b", expected: ["a", "b"], stepBudget: 0) == ["b"])
    }

    @Test("a budget that is enough finds the same placement as the default one")
    func enoughBudget() {
        #expect(DocumentCompleteness.missing(in: "ababa", expected: ["aba", "ab"], stepBudget: 100).isEmpty)
        #expect(DocumentCompleteness.missing(in: "Ann\nAnna", expected: ["Ann", "Anna"], stepBudget: 100).isEmpty)
    }

    @Test("texts that cannot all fit are reported when the search gives up, and the search does end")
    func overfullText() {
        let nodes = Array(repeating: "aa", count: 20) + Array(repeating: "aaa", count: 20) + Array(repeating: "aaaa", count: 20)
        let pdfText = String(repeating: "a", count: 170)   // the nodes need 180 scalars
        #expect(DocumentCompleteness.missing(in: pdfText, expected: nodes, stepBudget: 1_000) == ["aa"])
        #expect(DocumentCompleteness.missing(in: String(repeating: "a", count: 180), expected: nodes, stepBudget: 1_000_000).isEmpty)
    }
}

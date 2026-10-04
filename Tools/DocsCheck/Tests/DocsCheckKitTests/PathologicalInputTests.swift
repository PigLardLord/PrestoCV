import Testing
@testable import DocsCheckKit

@Suite("Pathological input is a finding, never a crash or a long run", .timeLimit(.minutes(1)))
struct PathologicalInputTests {
    private func problems(in text: String) -> [String] {
        MarkdownDocument(text: text).problems.map { "\($0.line) \($0.reason)" }
    }

    @Test("a heading longer than the cap is reported and has no anchor")
    func longHeading() {
        let atTheCap = String(repeating: "a", count: MarkdownDocument.maximumHeadingLength)
        let document = MarkdownDocument(text: "# \(atTheCap)\n# \(atTheCap)a\n# Short")
        #expect(document.problems.map(\.line) == [2])
        #expect(document.problems.map(\.reason) == [.tooLong])
        #expect(document.anchors == [atTheCap, "short"])
    }

    @Test("a 200,000-character heading is reported without being read")
    func hugeHeading() {
        #expect(problems(in: "# " + String(repeating: "a", count: 200_000)) == ["1 tooLong"])
        #expect(problems(in: "# " + String(repeating: "`a ", count: 70_000)) == ["1 tooLong"])
    }

    @Test("100,000 brackets in a heading are reported")
    func hugeNesting() {
        #expect(problems(in: "# " + String(repeating: "[", count: 100_000)) == ["1 tooLong"])
        #expect(problems(in: "# " + String(repeating: "[", count: 50_000) + "x" + String(repeating: "]", count: 50_000)) == ["1 tooLong"])
    }

    @Test("link labels nested deeper than the cap are reported, and nesting up to it is read")
    func nestedLabels() {
        func nested(_ depth: Int) -> String { String(repeating: "[", count: depth) + "x" + String(repeating: "]", count: depth) }
        #expect(problems(in: "# " + nested(300)) == ["1 tooNested"])
        #expect(MarkdownDocument(text: "# " + nested(InlineText.maximumNesting)).anchors == ["x"])
        #expect(problems(in: "# " + nested(InlineText.maximumNesting + 1)) == ["1 tooNested"])
    }

    @Test("a heading that is not read does not shift the numbering of the others")
    func numbering() {
        let long = String(repeating: "a", count: MarkdownDocument.maximumHeadingLength + 1)
        #expect(MarkdownDocument(text: "# Same\n# \(long)\n# Same").anchors == ["same", "same-1"])
    }

    @Test("nesting is reported at the line of the heading, by the checker")
    func reportedByTheChecker() throws {
        let long = String(repeating: "a", count: MarkdownDocument.maximumHeadingLength + 1)
        let nested = String(repeating: "[", count: 100) + "x" + String(repeating: "]", count: 100)
        #expect(try findings(in: ["README.md": "# Title\n\n## \(long)\n\n## \(nested)"]) == ["README.md:3 heading-too-long", "README.md:5 heading-too-nested"])
    }

    @Test("100,000 link openers on one line take linear time")
    func manyLinkOpeners() {
        #expect(MarkdownDocument(text: String(repeating: "](", count: 100_000)).links.count <= 1)
        #expect(MarkdownDocument(text: String(repeating: "[a](b ", count: 30_000)).links.count == 30_000)
    }

    @Test("a finding about a long destination or path stays one short line")
    func shortMessages() throws {
        let destination = String(repeating: "a", count: 100_000)
        try withRepository(acceptedBaseline.merging(["README.md": "[x](\(destination)) `Tools/\(destination)`", "Tools/run.sh": ""]) { _, test in test }) { root in
            let findings = try DocumentationChecker(root: root).run().findings.filter { $0.file == "README.md" }
            #expect(findings.map(\.code) == [.linkTargetMissing, .pathMissing])
            #expect(findings.allSatisfy { $0.description.count < 300 })
        }
        #expect(Finding.quoted("short") == "`short`")
        #expect(Finding.quoted(String(repeating: "b", count: 160)) == "`" + String(repeating: "b", count: 160) + "`")
        #expect(Finding.quoted(String(repeating: "b", count: 161)) == "`" + String(repeating: "b", count: 160) + "…`")
    }

    @Test("long runs of backticks and brackets outside headings are read")
    func longLines() {
        _ = MarkdownDocument(text: String(repeating: "`", count: 200_000))
        _ = MarkdownDocument(text: String(repeating: "` ", count: 100_000))
        _ = MarkdownDocument(text: String(repeating: "[", count: 200_000))
        _ = MarkdownDocument(text: (1...600).map { String(repeating: "`", count: $0) }.joined(separator: "a"))
    }
}

import Foundation
import Testing
@testable import DocsCheckKit

@Suite("Markdown document scanning")
struct MarkdownDocumentTests {
    private func destinations(_ text: String) -> [String] { MarkdownDocument(text: text).links.map(\.destination) }

    @Test("inline links and images are found with their line numbers")
    func inlineLinks() {
        let document = MarkdownDocument(text: "Intro\nSee [rules](rules.md) and ![logo](img/logo.png).\n\n[x](a.md#top) [y](<b c.md>)")
        #expect(document.links == [
            .init(line: 2, destination: "rules.md"), .init(line: 2, destination: "img/logo.png"),
            .init(line: 4, destination: "a.md#top"), .init(line: 4, destination: "b c.md"),
        ])
    }

    @Test("a title after the destination is not part of it")
    func linkTitle() {
        #expect(destinations("[a](a.md \"The title\") [b](b.md 'title') [c](c.md (title))") == ["a.md", "b.md", "c.md"])
    }

    @Test("balanced parentheses belong to the destination")
    func parentheses() {
        #expect(destinations("[a](dir/file_(1).md) then (see [b](b.md))") == ["dir/file_(1).md", "b.md"])
    }

    @Test("a link as the text of a link and an escaped bracket")
    func nesting() {
        #expect(destinations("[![badge](badge.svg)](target.md)") == ["badge.svg", "target.md"])
    }

    @Test("link definitions are links, footnote definitions are not")
    func definitions() {
        let text = "[one]: one.md\n  [two]: <two.md> \"Title\"\n[^note]: not a link\n    [indented]: code.md"
        #expect(destinations(text) == ["one.md", "two.md"])
    }

    @Test("code spans and fenced blocks hide what looks like a link")
    func codeHidesLinks() {
        let text = """
        Use `[a](a.md)` or ``[b](b.md)`` and [c](c.md).
        ```
        [d](d.md)
        ```
        ~~~markdown
        [e](e.md)
        ~~~
        [f](f.md)
        """
        #expect(destinations(text) == ["c.md", "f.md"])
    }

    @Test("a fence closes only with the same character and at least as many of them")
    func fenceClosing() {
        let text = "````\n```\n[a](a.md)\n```\n````\n[b](b.md)\n~~~\n[c](c.md)\n```\n[d](d.md)\n~~~\n[e](e.md)"
        #expect(destinations(text) == ["b.md", "e.md"])
    }

    @Test("an indented fence inside a list item is a fence")
    func indentedFence() {
        #expect(destinations("- item\n    ```\n    [a](a.md)\n    ```\n- [b](b.md)") == ["b.md"])
    }

    @Test("an escaped backtick does not open a code span, and an unmatched run is text")
    func backtickEscapes() {
        #expect(destinations("\\`[a](a.md)\\` and `` [b](b.md) ` and ` [c](c.md)") == ["a.md", "b.md", "c.md"])
    }

    @Test("a link in an external form is still reported, for the caller to classify")
    func externalLinks() {
        #expect(destinations("[a](https://example.com/x) [b](mailto:a@b.c) [c](#top)") == ["https://example.com/x", "mailto:a@b.c", "#top"])
    }

    @Test("code spans are reported with their content and line")
    func codeSpans() {
        let text = "One `a/b` and ``c ` d`` here.\n```\n`not.a/span`\n```\nTwo `e/f.md:10`; `\\` backslash; unmatched `"
        #expect(MarkdownDocument(text: text).codeSpans == [
            .init(line: 1, text: "a/b"), .init(line: 1, text: "c ` d"),
            .init(line: 5, text: "e/f.md:10"), .init(line: 5, text: "\\"),
        ])
    }

    @Test("ATX headings are found by level, with closing hashes removed")
    func headings() {
        let text = "# Title\n## Section ##\n###### Deep\n####### Seven\n#hashtag\n   ### Indented three\n    #### Indented four\n#\n```\n# in a fence\n```\n## `Code` heading"
        #expect(MarkdownDocument(text: text).headings == [
            .init(line: 1, level: 1, text: "Title"), .init(line: 2, level: 2, text: "Section"), .init(line: 3, level: 6, text: "Deep"),
            .init(line: 6, level: 3, text: "Indented three"), .init(line: 8, level: 1, text: ""), .init(line: 12, level: 2, text: "`Code` heading"),
        ])
    }

    @Test("a closing sequence of hashes needs a space before it, so a heading may end in a hash")
    func headingEndingInHash() {
        #expect(MarkdownDocument(text: "# C#\n## F# #\n### #").headings.map(\.text) == ["C#", "F#", ""])
    }

    @Test("anchors are the slugs of the headings, numbered when they repeat")
    func anchors() {
        let text = "# Usage\n## Install\ntext\n## Install\n```\n## Install\n```\n## Città e `code`\n## Install"
        #expect(MarkdownDocument(text: text).anchors == ["usage", "install", "install-1", "città-e-code", "install-2"])
    }

    @Test("Windows line endings do not change what is found")
    func windowsLineEndings() {
        let document = MarkdownDocument(text: "# Title\r\n[a](a.md)\r\n")
        #expect(document.links == [.init(line: 2, destination: "a.md")])
        #expect(document.anchors == ["title"])
    }

    // MARK: HTML comments

    @Test("an HTML comment hides links and code spans, on one line and over several")
    func comments() {
        let text = """
        before [a](a.md) <!-- [b](b.md) `c/d.md` --> after [e](e.md)
        <!--
        [f](f.md)
        `g/h.md`
        -->[i](i.md)
        [j](j.md)
        """
        let document = MarkdownDocument(text: text)
        #expect(document.links.map(\.destination) == ["a.md", "e.md", "i.md", "j.md"])
        #expect(document.codeSpans.isEmpty)
    }

    @Test("a comment opened inside a code span or a fence is not a comment, and one opened first hides a code span")
    func commentsAndCode() {
        let text = "`<!--` [a](a.md)\n```\n<!--\n```\n[b](b.md)\n<!-- `x` [c](c.md) -->\n\\<!-- [d](d.md)"
        #expect(MarkdownDocument(text: text).links.map(\.destination) == ["a.md", "b.md", "d.md"])
    }

    @Test("a fence marker inside a comment opens nothing, and a comment that is never closed hides the rest")
    func commentsAndFences() {
        #expect(MarkdownDocument(text: "<!--\n```\n-->\n[a](a.md)").links.map(\.destination) == ["a.md"])
        #expect(MarkdownDocument(text: "[a](a.md)\n<!--\n[b](b.md)\n").links.map(\.destination) == ["a.md"])
    }

    @Test("a heading in a comment is not a heading, and a comment at the end of a heading is not part of it")
    func commentsAndHeadings() {
        let document = MarkdownDocument(text: "<!--\n## Hidden\n-->\n## Title <!-- note -->\n## Other")
        #expect(document.headings.map(\.text) == ["Title", "Other"])
        #expect(document.anchors == ["title", "other"])
        #expect(MarkdownDocument(text: "<!-- - **Status:** Accepted -->\n- **Status:** Proposed").proseLines.map { $0.text.trimmingCharacters(in: .whitespaces) } == ["", "- **Status:** Proposed"])
    }

    @Test("an indented block is read like any other text: reading more can only add findings")
    func indentedCode() {
        #expect(MarkdownDocument(text: "    [a](a.md) `b/c.md`").links.map(\.destination) == ["a.md"])
    }
}

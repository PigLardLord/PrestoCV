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
}

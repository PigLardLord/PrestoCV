import Foundation
import Testing

// MARK: - Markdown Text Tests

/// `MarkdownText` reads Markdown the way the document checks need it: which paths are Markdown files, which lines are code or
/// comments, which text is prose, and which links point at files. All of it is a function of the text, so these tests need
/// neither git nor files.
@Suite("Reading Markdown text")
struct MarkdownTextTests {

    // MARK: - Files

    @Test("A path is a Markdown file by its extension, in any case", arguments: [
        ("README.md", true),
        ("docs/X.MD", true),
        ("docs/Notes.Md", true),
        ("a.markdown", true),
        ("A.MARKDOWN", true),
        ("a/b/c.mdx", true),
        ("notes.mkd", true),
        ("a.mdc.txt", false),
        ("a.mdc", false),
        ("a.txt", false),
        ("docs/md", false),
        ("md", false),
        ("a.md/b.txt", false),
        ("docs.md.orig", false),
        ("Makefile", false),
    ])
    func markdownFilesAreFoundByTheirExtension(path: String, isMarkdown: Bool) {
        #expect(MarkdownText.isMarkdown(path) == isMarkdown)
    }

    // MARK: - Lines

    @Test("Lines end at a line feed, a carriage return or both, and an empty line is kept")
    func linesEndAtAnyNewline() {
        #expect(MarkdownText.lines(of: "a\r\n\r\nb\rc\nd\n").map(String.init) == ["a", "", "b", "c", "d", ""])
        #expect(MarkdownText.lines(of: "").map(String.init) == [""])
    }

    @Test("A heading has a level from one to six when the hashes are followed by a space or end the line", arguments: [
        ("# Title", 1),
        ("## Section", 2),
        ("###### Deep", 6),
        ("  ## Indented", 2),
        ("   # Three spaces", 1),
        ("    # Four spaces are code", nil),
        ("## Section\r", 2),
        ("#", 1),
        ("####### Seven", nil),
        ("#hashtag", nil),
        ("A # in the middle", nil),
        ("", nil),
    ] as [(String, Int?)])
    func headingLevels(line: String, level: Int?) {
        #expect(MarkdownText.headingLevel(of: line) == level)
    }

    // MARK: - Code and comments

    @Test("Fenced code is left out, whether the fence is backticks or tildes, and a longer fence ends only with a fence as long")
    func fencedCodeIsLeftOut() {
        let markdown = """
            Before.

            ```swift
            let hidden = 1
            ```

            Between.

            ~~~
            hidden
            ~~~

            ````
            ```
            still hidden
            ```
            ````

            After.
            """

        let visible = MarkdownText.withoutFencesAndComments(markdown)

        #expect(visible.contains("Before."))
        #expect(visible.contains("Between."))
        #expect(visible.contains("After."))
        #expect(!visible.contains("hidden"))
        #expect(!visible.contains("```"))
    }

    @Test("A fence that is never closed runs to the end of the file, as Markdown renders it")
    func unclosedFenceRunsToTheEnd() {
        let visible = MarkdownText.withoutFencesAndComments("Before.\n\n```\nhidden\n\nalso hidden\n")

        #expect(visible.contains("Before."))
        #expect(!visible.contains("hidden"))
    }

    @Test("Backticks in a sentence, or in the text after a fence of backticks, do not open a fence")
    func inlineBackticksOpenNoFence() {
        let markdown = "Use ```three``` backticks inline.\n\n``` not a fence`\n\nText that stays."

        #expect(MarkdownText.withoutFencesAndComments(markdown).contains("Text that stays."))
    }

    @Test("A fence line with text after it does not close a fence, and one with only white space does")
    func closingFenceHasNoInfo() {
        let notClosed = MarkdownText.withoutFencesAndComments("```\nhidden\n```swift\nstill hidden\n```\nVisible.")
        let closed = MarkdownText.withoutFencesAndComments("```\nhidden\n```  \nVisible.")

        #expect(!notClosed.contains("still hidden"))
        #expect(notClosed.contains("Visible."))
        #expect(!closed.contains("hidden"))
        #expect(closed.contains("Visible."))
    }

    @Test("Comments are left out, on one line and over several lines")
    func commentsAreLeftOut() {
        let markdown = "One <!-- hidden --> two.\n\n<!-- hidden\nacross\nlines -->\n\nThree."

        let visible = MarkdownText.withoutFencesAndComments(markdown)

        #expect(!visible.contains("hidden"))
        #expect(!visible.contains("across"))
        #expect(visible.contains("One"))
        #expect(visible.contains("two."))
        #expect(visible.contains("Three."))
    }

    @Test("A comment opener inside a code span is no comment, so the text after it is still read")
    func commentOpenerInACodeSpanOpensNoComment() {
        let markdown = "Write `<!--` to open a comment.\n\nThe next paragraph is read. A real one <!-- hidden --> ends. Also `<!--` and <!-- gone -->."

        let visible = MarkdownText.withoutFencesAndComments(markdown)

        #expect(visible.contains("to open a comment."))
        #expect(visible.contains("The next paragraph is read."))
        #expect(visible.contains("ends."))
        #expect(!visible.contains("hidden"))
        #expect(!visible.contains("gone"))
    }

    @Test("Inline code is listed, outside fenced code and comments", arguments: [
        ("A `path/to/x` and `y` here.", ["path/to/x", "y"]),
        ("```\n`inside a fence`\n```\n`outside`", ["outside"]),
        ("<!-- `in a comment` --> `outside`", ["outside"]),
        ("No code here.", []),
        ("An `open span without an end", []),
    ] as [(String, [String])])
    func codeSpans(markdown: String, spans: [String]) {
        #expect(MarkdownText.codeSpans(in: markdown) == spans)
    }

    // MARK: - Prose

    @Test("Prose keeps the words of the text and the words of a link, and drops code, link targets, addresses, tags and definitions")
    func proseKeepsTheWords() {
        let markdown = """
            Read [the guide](docs/the-guide.md "A title") and run `swift test`.
            See https://example.com/a/b and <https://example.org> or <b>bold</b> text.

            [guide]: docs/the-guide.md
            """

        let prose = MarkdownText.prose(markdown)

        for word in ["Read", "the guide", "and run", "See", "bold", "text"] { #expect(prose.contains(word), "\(word) is missing from \(prose)") }
        for dropped in ["docs/", "swift test", "example", "<b>", "A title"] { #expect(!prose.contains(dropped), "\(dropped) is still in \(prose)") }
    }

    // MARK: - Blocks

    @Test("Blocks are headings, table rows, list items and paragraphs, with wrapped lines joined and code and comments left out")
    func blocksAreSplit() {
        let markdown = """
            # Title

            A wrapped paragraph
            over two lines.
            ## Heading right after text
            Text right after a heading.

            - First item
              continued here
            * Second item
            + Third item
            1. Numbered
            2) Also numbered

            > A quote
            > over two lines

            | A | B |
            |:--|--:|
            | x | `code` and `more` y |

            ```text
            - not an item
            ```
            <!-- - not an item either -->
            Last line.
            """

        #expect(MarkdownText.blocks(in: markdown) == [
            .init(kind: .heading, text: "# Title"),
            .init(kind: .paragraph, text: "A wrapped paragraph over two lines."),
            .init(kind: .heading, text: "## Heading right after text"),
            .init(kind: .paragraph, text: "Text right after a heading."),
            .init(kind: .listItem, text: "- First item continued here"),
            .init(kind: .listItem, text: "* Second item"),
            .init(kind: .listItem, text: "+ Third item"),
            .init(kind: .listItem, text: "1. Numbered"),
            .init(kind: .listItem, text: "2) Also numbered"),
            .init(kind: .paragraph, text: "A quote over two lines"),
            .init(kind: .tableRow, text: "| A | B |"),
            .init(kind: .tableRow, text: "| x | and y |"),
            .init(kind: .paragraph, text: "Last line."),
        ])
    }

    @Test("Blocks of a file with Windows line endings are the blocks of the same file with line feeds")
    func blocksIgnoreTheLineEnding() {
        let lineFeeds = "# Title\n\nFirst line\nsecond line.\n\n- Item\n"

        #expect(MarkdownText.blocks(in: lineFeeds.replacingOccurrences(of: "\n", with: "\r\n")) == MarkdownText.blocks(in: lineFeeds))
        #expect(MarkdownText.blocks(in: lineFeeds).count == 3)
    }

    // MARK: - Links

    @Test("The files a text links to are named as the text writes them, without a leading dot, a fragment or a title", arguments: [
        ("[x](LICENSE)", ["LICENSE"]),
        ("[x](./LICENSE)", ["LICENSE"]),
        ("[x](<LICENSE>)", ["LICENSE"]),
        ("[x](LICENSE#top)", ["LICENSE"]),
        ("[x](LICENSE \"The licence\")", ["LICENSE"]),
        ("[x](docs/)", ["docs/"]),
        ("![logo](images/logo.png)", ["images/logo.png"]),
        ("[a](A.md) and [b](B.md)", ["A.md", "B.md"]),
        ("[x](https://example.com/LICENSE)", []),
        ("[x](mailto:someone@example.com)", []),
        ("[x](//example.com/LICENSE)", []),
        ("[x](LICENSE?plain=1)", ["LICENSE"]),
        ("[x](#section)", []),
        ("[x]()", []),
    ] as [(String, [String])])
    func relativeLinkTargets(markdown: String, targets: [String]) {
        #expect(MarkdownText.relativeLinkTargets(in: markdown) == targets)
    }

    @Test("A link in a comment, in a code span or in a fence is no link")
    func hiddenLinksAreNoLinks() {
        #expect(MarkdownText.relativeLinkTargets(in: "<!-- [x](LICENSE) -->") == [])
        #expect(MarkdownText.relativeLinkTargets(in: "<!--\n[x](LICENSE)\n-->") == [])
        #expect(MarkdownText.relativeLinkTargets(in: "`[x](LICENSE)`") == [])
        #expect(MarkdownText.relativeLinkTargets(in: "```\n[x](LICENSE)\n```") == [])
    }

    @Test("A reference definition links a file once the text uses its label, in any of the three forms and in any case")
    func referenceLinks() {
        let definition = "\n\n[license]: ./LICENSE\n"

        #expect(MarkdownText.relativeLinkTargets(in: "See [the licence][license]." + definition) == ["LICENSE"])
        #expect(MarkdownText.relativeLinkTargets(in: "See [license][]." + definition) == ["LICENSE"])
        #expect(MarkdownText.relativeLinkTargets(in: "See [License]." + definition) == ["LICENSE"])
        #expect(MarkdownText.relativeLinkTargets(in: "See the licence." + definition) == [], "a definition that nothing uses links nothing")
        #expect(MarkdownText.relativeLinkTargets(in: "[x][license]\n\n[license]: https://example.com/LICENSE") == [])
    }
}

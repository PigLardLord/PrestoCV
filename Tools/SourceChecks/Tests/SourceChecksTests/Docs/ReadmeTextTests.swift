import Foundation
import Testing

// MARK: - Readme Text Tests

/// `ReadmeText` reads the README's "Where things are" table, finds the placeholders that an open-source file must not keep and
/// finds the paragraph that holds a statement. All of it is a function of the text, so these tests need neither git nor files.
@Suite("Reading the README and the open-source files")
struct ReadmeTextTests {

    // MARK: - The table

    private static let table = """
        # Project

        Intro with `not/a/row` in it.

        ## Where things are

        | Path | What it is |
        |---|---|
        | `app/` | The app. |
        | `core/`, `exporter/` | Two packages, as in `docs/guide.md`. |
        | `tools/` | The checks. See [the checks](tools/checks/README.md) and run `swift test`. |

        ## Building and testing

        | `later/` | A table of another section. |
        """

    @Test("The table names the paths of its rows, in the first cell and the others, in code and in links, without a trailing slash")
    func tablePathsAreRead() {
        #expect(ReadmeText.tablePaths(in: Self.table) == ["app", "core", "exporter", "docs/guide.md", "tools", "tools/checks/README.md"])
    }

    @Test("A row is read whatever its spacing, indent or first cell: four rows with paths that do not exist are four paths")
    func rowsAreReadWhateverTheirSpacing() {
        let readme = """
            ## Where things are

            | Path | What it is |
            |---|---|
            |`ghost-a/`| No space after the bar. |
              | `ghost-b/` | An indented row. |
            | [`ghost-c/`](ghost-c/) | A row that starts with a link. |
            |`ghost-d/`|no spaces at all|
            """

        #expect(ReadmeText.tablePaths(in: readme) == ["ghost-a", "ghost-b", "ghost-c", "ghost-d"])
    }

    @Test("In the cells after the first, a code span is a path only if it has a slash and is a single word without wildcards")
    func laterCellsNameOnlyPaths() {
        let readme = """
            ## Where things are

            | Path | What it is |
            |---|---|
            | `a/` | Run `swift test`, see `docs/logging.md`, `docs/adr/*.md`, `x/y z`, `R1` and `Tools/Release/check.py`. |
            | `b` | The first cell is always a path. |
            """

        #expect(ReadmeText.tablePaths(in: readme) == ["a", "docs/logging.md", "Tools/Release/check.py", "b"])
    }

    @Test("A code span with a wildcard, a brace, a bracket or a question mark is a pattern and no path", arguments: [
        "docs/*.md", "docs/{a,b}/x.md", "docs/[ab].md", "docs/a?.md", "docs/<name>/x.md", "docs/a>b.md",
    ])
    func patternsAreNoPaths(span: String) {
        let readme = "## Where things are\n\n| Path | What |\n|---|---|\n| `a/` | See `\(span)` and `real/path.md`. |\n"

        #expect(ReadmeText.tablePaths(in: readme) == ["a", "real/path.md"])
    }

    @Test("The header row is not read, nor is the separator, and a link to the web or to a heading is no path")
    func headerSeparatorAndOutsideLinksAreSkipped() {
        let readme = """
            ## Where things are

            | `Header/` | [Site](https://example.com/x) |
            |:---|---:|
            | `real/` | [Heading](#heading) and [mail](mailto:a@b.c) |
            """

        #expect(ReadmeText.tablePaths(in: readme) == ["real"])
    }

    @Test("The table ends at the next heading of level one or two, and a heading in a code fence or a comment does not end it")
    func tableEndsAtTheNextHeading() {
        let readme = """
            ## Where things are

            | `a/` | One. |

            ```markdown
            ## Not a heading
            ```

            <!--
            ## Not a heading either
            -->

            | `b/` | Two, after the fence and the comment. |

            ### A subsection stays in the table

            | `c/` | Three. |

            # A title

            | `d/` | Four, after the title. |
            """

        #expect(ReadmeText.tablePaths(in: readme) == ["a", "b", "c"])
    }

    @Test("A README with Windows line endings gives the same paths, and one without the heading gives none")
    func tableLineEndingsAndMissingHeading() {
        #expect(ReadmeText.tablePaths(in: Self.table.replacingOccurrences(of: "\n", with: "\r\n")) == ReadmeText.tablePaths(in: Self.table))
        #expect(ReadmeText.tablePaths(in: "# Project\n\n| `a/` | One. |\n").isEmpty)
        #expect(ReadmeText.tablePaths(in: "").isEmpty)
    }

    @Test("The same path in two places is named once")
    func pathsAreNamedOnce() {
        let readme = "## Where things are\n\n| [`a/`](a/) | See `a/` and `b/x`. |\n| `b/x` | Again. |\n"

        #expect(ReadmeText.tablePaths(in: readme) == ["a", "b/x"])
    }

    // MARK: - Placeholders

    @Test("A placeholder is found wherever it stands, in prose, in a comment or in code", arguments: [
        ("Write to CONTACT_EMAIL.", ["CONTACT_EMAIL"]),
        ("Write to support@prestocv.app or [INSERT CONTACT METHOD].", ["[INSERT CONTACT METHOD]"]),
        ("CONTACT_ADDRESS and CONTACT_EMAIL", ["CONTACT_ADDRESS", "CONTACT_EMAIL"]),
        ("YOUR_NAME here", ["YOUR_NAME"]),
        ("TODO: fill in", ["TODO"]),
        ("<!-- FIXME -->", ["FIXME"]),
        ("```\nTBD\n```", ["TBD"]),
        ("[INSERT]", ["[INSERT]"]),
    ] as [(String, [String])])
    func placeholdersAreFound(text: String, placeholders: [String]) {
        #expect(ReadmeText.placeholders(in: text) == placeholders)
    }

    @Test("Plain words that look like a placeholder are not one")
    func plainWordsAreNoPlaceholders() {
        let text = """
            Write to support@prestocv.app. Read CODE_OF_CONDUCT.md and CONTRIBUTING.md. Insert the card and todo list items, \
            and a to-do or a todo are words. The TODOS are not placeholders, nor is a MYTODO.
            """

        #expect(ReadmeText.placeholders(in: text).isEmpty)
    }

    // MARK: - A statement in one paragraph

    @Test("A statement is made when one paragraph, list item or table row holds every phrase, whatever the case")
    func paragraphHoldsThePhrases() {
        let policy = """
            # Security

            - **On GitHub (preferred):** use Private Vulnerability Reporting, with the button in the Security tab.
            - By e-mail, if you cannot use GitHub.
            """

        #expect(ReadmeText.paragraphMentioning(["private vulnerability reporting", "preferred"], in: policy))
    }

    @Test("Phrases in two paragraphs, in a code fence or in a comment make no statement")
    func separatePhrasesMakeNoStatement() {
        let phrases = ["private vulnerability reporting", "preferred"]

        #expect(!ReadmeText.paragraphMentioning(phrases, in: "Use private vulnerability reporting.\n\nThe preferred way is e-mail."))
        #expect(!ReadmeText.paragraphMentioning(phrases, in: "```\nprivate vulnerability reporting, preferred\n```"))
        #expect(!ReadmeText.paragraphMentioning(phrases, in: "<!-- private vulnerability reporting is preferred -->"))
        #expect(!ReadmeText.paragraphMentioning(phrases, in: "# Preferred private vulnerability reporting\n\nA paragraph."), "a heading is no statement")
        #expect(!ReadmeText.paragraphMentioning(phrases, in: ""))
    }
}

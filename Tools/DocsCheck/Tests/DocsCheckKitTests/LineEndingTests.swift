import Foundation
import Testing
@testable import DocsCheckKit

@Suite("Windows line endings change nothing")
struct LineEndingTests {
    private func crlf(_ files: [String: String]) -> [String: String] {
        files.mapValues { $0.replacingOccurrences(of: "\n", with: "\r\n") }
    }

    @Test("a repository written with CRLF, links, link definitions, headings, ADR statuses and the index included, has no findings")
    func everythingWithCRLF() throws {
        var files = acceptedBaseline
        files["README.md"] = "# Title\n\n[a](docs/a.md#section) and a [definition][d]\n\n[d]: docs/a.md\n"
        files["docs/a.md"] = "# A\n\n## Section\n\nSee `docs/a.md`.\n"
        files["docs/architecture/adr/0002-second.md"] = "# 0002. Second\n\n- **Status:** Superseded by [0003](0003-third.md)\n- **Date:** 2026-01-01\n"
        files["docs/architecture/adr/0003-third.md"] = "# 0003. Third\n\n- **Status:** Accepted\n"
        files["docs/architecture/adr/README.md"] = "# ADRs\n\n| # | Decision | Status |\n|---|---|---|\n| [0001](0001-first.md) | First | Accepted |\n"
            + "| [0002](0002-second.md) | Second | Superseded by [0003](0003-third.md) |\n| [0003](0003-third.md) | Third | Accepted |\n"
        #expect(try findings(in: crlf(files)) == [])
    }

    @Test("a link definition and a status line keep their meaning, and a line number is the same as with LF")
    func sameFindingsAsLF() throws {
        let files = [
            "README.md": "# Title\n\n[d]: docs/gone.md\n",
            "docs/architecture/adr/0001-first.md": "# 0001. First\n\n- **Status:** Draft\n",
        ]
        let lf = try findings(in: files)
        #expect(lf == ["README.md:3 link-target-missing", "docs/architecture/adr/0001-first.md:3 adr-status-unknown"])
        #expect(try findings(in: crlf(files)) == lf)
    }

    @Test("the line ending is dropped from the document as the scanner reads it")
    func carriageReturnIsNotText() {
        let document = MarkdownDocument(text: "[d]: docs/a.md\r\n- **Status:** Accepted\r\n## Title\r\n")
        #expect(document.links.map(\.destination) == ["docs/a.md"])
        #expect(document.proseLines.map(\.text) == ["[d]: docs/a.md", "- **Status:** Accepted", "## Title", ""])
        #expect(document.headings.map(\.text) == ["Title"])
    }
}

import Testing
@testable import DocsCheckKit

@Suite("Check 3 · ADR status and index")
struct ADRCheckTests {
    private static let adr = "docs/architecture/adr"

    private func index(_ rows: String...) -> String {
        "# ADRs\n\n| # | Decision | Status |\n|---|---|---|\n" + rows.joined(separator: "\n")
    }

    private func adrFile(_ number: String, status: String?) -> String {
        "# \(number). Title\n\n" + (status.map { "- **Status:** \($0)\n- **Date:** 2026-01-01\n" } ?? "- **Date:** 2026-01-01\n")
    }

    @Test("ADRs with a known status, listed in the index with the same status, pass")
    func consistent() throws {
        let result = try findings(in: [
            "\(Self.adr)/README.md": index("| [0001](0001-first.md) | First | Accepted |", "| [0002](0002-second.md) | Second | Proposed |",
                                           "| [0003](0003-third.md) | Third | Rejected |", "| [0004](0004-fourth.md) | Fourth | Superseded by [0005](0005-fifth.md) |",
                                           "| [0005](0005-fifth.md) | Fifth | Accepted |"),
            "\(Self.adr)/0002-second.md": adrFile("0002", status: "Proposed"),
            "\(Self.adr)/0003-third.md": adrFile("0003", status: "Rejected"),
            "\(Self.adr)/0004-fourth.md": adrFile("0004", status: "Superseded by [0005](0005-fifth.md)"),
            "\(Self.adr)/0005-fifth.md": adrFile("0005", status: "Accepted"),
        ])
        #expect(result == [])
    }

    @Test("an ADR without a status line is a finding")
    func missingStatus() throws {
        let result = try findings(in: ["\(Self.adr)/0001-first.md": adrFile("0001", status: nil)])
        #expect(result == ["\(Self.adr)/0001-first.md:1 adr-status-missing"])
    }

    @Test("a status that the ADR README does not define is a finding at its line")
    func unknownStatus() throws {
        let result = try findings(in: ["\(Self.adr)/0001-first.md": adrFile("0001", status: "Accepted (amended)")])
        #expect(result == ["\(Self.adr)/0001-first.md:3 adr-status-unknown"])
    }

    @Test("a status line in a code block does not count")
    func statusInFence() throws {
        let text = "# 0001. First\n\n```\n- **Status:** Accepted\n```\n"
        #expect(try findings(in: ["\(Self.adr)/0001-first.md": text]) == ["\(Self.adr)/0001-first.md:1 adr-status-missing"])
    }

    @Test("a superseded ADR must name its replacement with a link")
    func supersededWithoutLink() throws {
        let result = try findings(in: [
            "\(Self.adr)/0001-first.md": adrFile("0001", status: "Superseded by 0002"),
            "\(Self.adr)/README.md": index("| [0001](0001-first.md) | First | Superseded by 0002 |"),
        ])
        #expect(result == ["\(Self.adr)/0001-first.md:3 adr-superseded-without-link", "\(Self.adr)/README.md:5 adr-superseded-without-link"])
    }

    @Test("the replacement must be an ADR that exists")
    func successorMissing() throws {
        let result = try findings(in: ["\(Self.adr)/0001-first.md": adrFile("0001", status: "Superseded by [0002](0002-second.md)")])
        #expect(result.contains("\(Self.adr)/0001-first.md:3 adr-successor-missing"))
    }

    @Test("the replacement must be an ADR file, not another document")
    func successorNotAnADR() throws {
        let result = try findings(in: ["\(Self.adr)/0001-first.md": adrFile("0001", status: "Superseded by [the index](README.md)")])
        #expect(result.contains("\(Self.adr)/0001-first.md:3 adr-successor-missing"))
    }

    @Test("an ADR that the index does not list is a finding")
    func notIndexed() throws {
        let result = try findings(in: ["\(Self.adr)/0002-second.md": adrFile("0002", status: "Accepted")])
        #expect(result == ["\(Self.adr)/0002-second.md:1 adr-not-indexed"])
    }

    @Test("an index row for an ADR that has no file is a finding")
    func indexUnknown() throws {
        let result = try findings(in: ["\(Self.adr)/README.md": index("| [0001](0001-first.md) | First | Accepted |", "| [0009](0009-ninth.md) | Ninth | Accepted |")])
        #expect(result.contains("\(Self.adr)/README.md:6 adr-index-unknown"))
    }

    @Test("an index row with another status than its ADR is a finding at the row")
    func statusDiffers() throws {
        let result = try findings(in: ["\(Self.adr)/README.md": index("| [0001](0001-first.md) | First | Proposed |")])
        #expect(result == ["\(Self.adr)/README.md:5 adr-index-status-differs"])
    }

    @Test("a status in the index that the ADR README does not define is a finding")
    func unknownIndexStatus() throws {
        let result = try findings(in: ["\(Self.adr)/README.md": index("| [0001](0001-first.md) | First | Done |")])
        #expect(result == ["\(Self.adr)/README.md:5 adr-status-unknown"])
    }

    @Test("an ADR superseded by another one differs from the index when they name different replacements")
    func differentReplacement() throws {
        let result = try findings(in: [
            "\(Self.adr)/README.md": index("| [0001](0001-first.md) | First | Superseded by [0003](0003-third.md) |", "| [0002](0002-second.md) | S | Accepted |", "| [0003](0003-third.md) | T | Accepted |"),
            "\(Self.adr)/0001-first.md": adrFile("0001", status: "Superseded by [0002](0002-second.md)"),
            "\(Self.adr)/0002-second.md": adrFile("0002", status: "Accepted"),
            "\(Self.adr)/0003-third.md": adrFile("0003", status: "Accepted"),
        ])
        #expect(result == ["\(Self.adr)/README.md:5 adr-index-status-differs"])
    }

    @Test("the README and the template are not ADRs")
    func notADRs() throws {
        #expect(try findings(in: ["\(Self.adr)/template.md": "# NNNN. Title\n\n- **Status:** Proposed", "\(Self.adr)/0001-first.md.bak": "x"]) == [])
    }

    @Test("a missing index or a missing directory is a finding, never a pass")
    func missingIndexOrDirectory() throws {
        #expect(try findings(in: [:], removing: ["\(Self.adr)/README.md"]) == ["\(Self.adr)/README.md:1 adr-index-missing"])
        #expect(try findings(in: [:], removing: ["\(Self.adr)/README.md", "\(Self.adr)/0001-first.md"]) == ["\(Self.adr):1 adr-directory-missing"])
    }

    // MARK: Records are keyed by path, and index rows by their link

    @Test("two ADR files with one number are each a finding, and each is checked on its own")
    func duplicatedNumber() throws {
        let result = try findings(in: [
            "\(Self.adr)/0002-a.md": adrFile("0002", status: "Accepted"),
            "\(Self.adr)/0002-b.md": adrFile("0002", status: "Draft"),
            "\(Self.adr)/README.md": index("| [0001](0001-first.md) | First | Accepted |", "| [0002](0002-a.md) | A | Accepted |", "| [0002](0002-b.md) | B | Draft |"),
        ])
        #expect(result == [
            "\(Self.adr)/0002-a.md:1 adr-number-duplicated", "\(Self.adr)/0002-b.md:1 adr-number-duplicated",
            "\(Self.adr)/0002-b.md:3 adr-status-unknown", "\(Self.adr)/README.md:7 adr-status-unknown",
        ])
    }

    @Test("an index row is matched with the file it links to, so two files of one number keep their own statuses")
    func rowsMatchedByLink() throws {
        let result = try findings(in: [
            "\(Self.adr)/0002-a.md": adrFile("0002", status: "Accepted"),
            "\(Self.adr)/0002-b.md": adrFile("0002", status: "Proposed"),
            "\(Self.adr)/README.md": index("| [0001](0001-first.md) | First | Accepted |", "| [0002](0002-b.md) | B | Accepted |", "| [0002](0002-a.md) | A | Accepted |"),
        ])
        #expect(result == ["\(Self.adr)/0002-a.md:1 adr-number-duplicated", "\(Self.adr)/0002-b.md:1 adr-number-duplicated", "\(Self.adr)/README.md:6 adr-index-status-differs"])
    }

    @Test("a file the index does not link to is not indexed, even when a row has its number")
    func numberIsNotTheKey() throws {
        let result = try findings(in: [
            "\(Self.adr)/0002-a.md": adrFile("0002", status: "Accepted"),
            "\(Self.adr)/README.md": index("| [0001](0001-first.md) | First | Accepted |", "| [0002](0002-other.md) | A | Accepted |"),
        ])
        #expect(result.contains("\(Self.adr)/0002-a.md:1 adr-not-indexed"))
        #expect(result.contains("\(Self.adr)/README.md:6 adr-index-unknown"))
    }

    @Test("a row whose number is not the number of the file it links to is a finding")
    func rowNumberDiffers() throws {
        let result = try findings(in: [
            "\(Self.adr)/0002-a.md": adrFile("0002", status: "Accepted"),
            "\(Self.adr)/README.md": index("| [0001](0001-first.md) | First | Accepted |", "| [0003](0002-a.md) | A | Accepted |"),
        ])
        #expect(result == ["\(Self.adr)/0002-a.md:1 adr-not-indexed", "\(Self.adr)/README.md:6 adr-index-unknown"])
    }

    @Test("a row without a link into the directory is a finding, and a link may be written in any form that resolves")
    func rowLinks() throws {
        let rows = index("| [0001](./0001-first.md) | First | Accepted |", "| 0002 | A | Accepted |", "| [0003](README.md) | R | Accepted |", "| [0002](../adr/0002-a.md) | A | Accepted |")
        let result = try findings(in: ["\(Self.adr)/0002-a.md": adrFile("0002", status: "Accepted"), "\(Self.adr)/README.md": rows])
        #expect(result == ["\(Self.adr)/README.md:6 adr-index-unknown", "\(Self.adr)/README.md:7 adr-index-unknown"])
    }

    @Test("the number a superseded status shows must be the number of the file it links to")
    func shownNumberDiffers() throws {
        func result(_ status: String) throws -> [String] {
            try findings(in: [
                "\(Self.adr)/0001-first.md": adrFile("0001", status: status),
                "\(Self.adr)/0002-second.md": adrFile("0002", status: "Accepted"),
                "\(Self.adr)/README.md": index("| [0001](0001-first.md) | First | \(status) |", "| [0002](0002-second.md) | Second | Accepted |"),
            ])
        }
        #expect(try result("Superseded by [0002](0002-second.md)") == [])
        #expect(try result("Superseded by [ADR 0002](0002-second.md)") == [])
        #expect(try result("Superseded by [the second one](0002-second.md)") == [])
        #expect(try result("Superseded by [0003](0002-second.md)") == ["\(Self.adr)/0001-first.md:3 adr-successor-missing", "\(Self.adr)/README.md:5 adr-successor-missing"])
    }

    @Test("the first status line of an ADR is its status, and a later one is not read")
    func firstStatusLine() throws {
        let both = "# 0001. First\n\n- **Status:** Accepted\n\nLater, a note:\n\n- **Status:** Draft\n"
        #expect(try findings(in: ["\(Self.adr)/0001-first.md": both]) == [])
        let reversed = "# 0001. First\n\n- **Status:** Draft\n\n- **Status:** Accepted\n"
        #expect(try findings(in: ["\(Self.adr)/0001-first.md": reversed]) == ["\(Self.adr)/0001-first.md:3 adr-status-unknown"])
    }
}

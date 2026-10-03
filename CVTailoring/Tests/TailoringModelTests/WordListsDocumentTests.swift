import Testing
import Foundation
@testable import TailoringModel

/// word-lists.md is the documentation of the file format (ADR 0013): these tests read it and hold it to the decoder. A
/// key the decoder knows and the page does not name fails, and so does a key the page names and the decoder does not know.
@Suite("word-lists.md matches the code (#136)")
struct WordListsDocumentTests {
    @Test("the key table names exactly the version and the lists the decoder knows, each once")
    func keyTable() throws {
        let rows = try Page.rows(after: "### Keys")
        let named = try rows.map { try #require(Page.backticked($0[0]).first, "a row without a key: \($0)") }
        #expect(Set(named) == Set(["version", "language"] + WordListKey.allCases.map(\.rawValue)))
        #expect(named.count == Set(named).count, "a key is named twice")
    }

    @Test("every row of the key table says what the list holds, whether it may be empty, and how the checks use it")
    func keyTableIsFilled() throws {
        for row in try Page.table(after: "### Keys") {
            for column in ["Key", "Holds", "May be empty", "Used by"] {
                #expect(!(row[column] ?? "").isEmpty, "the row of \(row["Key"] ?? "?") has no \(column)")
            }
        }
    }

    @Test("the lists the page says may be empty are the ones the decoder accepts empty")
    func mayBeEmptyColumn() throws {
        var yes: Set<String> = []
        for row in try Page.table(after: "### Keys") {
            let key = try #require(Page.backticked(row["Key"] ?? "").first)
            let cell = try #require(row["May be empty"])
            #expect(["yes", "no", "—"].contains(cell), "\(key): \(cell)")
            if cell == "yes" { yes.insert(key) }
            if key == "version" || key == "language" { #expect(cell == "—") }
        }
        #expect(yes == Set(WordListKey.allCases.filter(\.mayBeEmpty).map(\.rawValue)))
    }

    @Test("the shape table names exactly the keys the decoder allows in the file, in a list and in each entry")
    func shapeTable() throws {
        let rows = try Page.rows(after: "### Shapes")
        var shapes: [String: Set<String>] = [:]
        for row in rows { shapes[row[0]] = Set(Page.backticked(row[1])) }
        #expect(shapes["The file"] == Set(WordListFormat.rootKeys))
        #expect(shapes["A list"] == Set(WordListFormat.listKeys))
        #expect(shapes["The list of streets"] == Set(WordListFormat.streetListKeys))
        #expect(shapes["A month name"] == Set(WordListFormat.monthKeys))
        #expect(shapes["A number word"] == Set(WordListFormat.numberKeys))
        #expect(shapes["A group of synonyms"] == Set(WordListFormat.synonymKeys))
        #expect(shapes["A word of a form of address"] == Set(WordListFormat.formKeys))
        #expect(shapes["A word that claims a rank"] == Set(WordListFormat.rankKeys))
        #expect(shapes.count == 8, "a shape the decoder does not know is described")
    }

    @Test("the version and the size limit the page states are the code's")
    func versionAndSize() throws {
        let page = try Page.text()
        let versions = Page.matches(#"## Format, version (\d+)"#, in: page)
        #expect(versions == [String(WordListFormat.version)])
        let sizes = Page.matches(#"at most ([\d,]+) bytes"#, in: page).map { $0.replacingOccurrences(of: ",", with: "") }
        #expect(sizes == [String(WordListFormat.maxFileBytes)])
    }

    @Test("the licences the page allows are the decoder's")
    func licences() throws {
        let lines = Page.matches(#"^- The licences a list may carry: (.*)$"#, in: try Page.text())
        let line = try #require(lines.first, "no line naming the licences")
        #expect(lines.count == 1)
        #expect(Set(Page.backticked(line)) == WordListFormat.allowedLicences)
    }

    @Test("the street orders the page names are the decoder's")
    func streetOrders() throws {
        let lines = Page.matches(#"^- The street orders: (.*)$"#, in: try Page.text())
        #expect(lines.count == 1)
        let line = try #require(lines.first, "no line naming the street orders")
        #expect(Page.backticked(line) == StreetOrder.allCases.map(\.rawValue))
    }

    @Test("the forms of address the page names are the ones the decoder maps")
    func formsOfAddress() throws {
        let lines = Page.matches(#"^- The forms of address: (.*)$"#, in: try Page.text())
        #expect(lines.count == 1)
        let line = try #require(lines.first, "no line naming the forms of address")
        #expect(Set(Page.backticked(line)) == Set(WordListFormat.formsOfAddress.keys))
        #expect(WordListFormat.formsOfAddress["ms"] == .ms && WordListFormat.formsOfAddress["mr"] == .mr)
    }

    @Test("the month range and the smallest group of synonyms the page states are the decoder's")
    func bounds() throws {
        let page = try Page.text()
        let range = try #require(Page.pairs(#"outside (\d+) to (\d+)"#, in: page).first)
        #expect(range.0 == String(WordListFormat.monthNumbers.lowerBound) && range.1 == String(WordListFormat.monthNumbers.upperBound))
        #expect(Page.matches(#"fewer than (\d+) forms"#, in: page) == [String(WordListFormat.minSynonymForms)])
    }

    @Test("the ranks the page names are the ranks the decoder knows")
    func ranks() throws {
        let listed = Page.backticked(try Page.section(from: "### Ranks", to: "#"))
        #expect(listed == TitleRank.allCases.map(\.rawValue))
    }

    @Test("the page names each of the six language codes in its list of languages")
    func languages() throws {
        let listed = Page.backticked(try Page.section(from: "### Languages", to: "#"))
        #expect(Set(listed) == Set(TailoringLanguage.allCases.map(\.code)))
    }
}

// MARK: - Reading the page

private enum Page {
    struct PageError: Error, CustomStringConvertible { let description: String }

    /// The page, from the repository: this file is CVTailoring/Tests/TailoringModelTests/….
    static func text() throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent("docs/architecture/word-lists.md"), encoding: .utf8)
    }

    /// The text between a heading and the next line that starts with `end`.
    static func section(from start: String, to end: String) throws -> String {
        let page = try text()
        guard let a = page.range(of: start), let b = page.range(of: "\n" + end, range: a.upperBound..<page.endIndex) else {
            throw PageError(description: "no section from \(start) to \(end)")
        }
        return String(page[a.upperBound..<b.lowerBound])
    }

    /// The rows of the first table after `heading`, each by the name of its column.
    static func table(after heading: String) throws -> [[String: String]] {
        let page = try text()
        guard let start = page.range(of: heading) else { throw PageError(description: "no heading \(heading)") }
        let lines = page[start.upperBound...].components(separatedBy: "\n").drop { !$0.hasPrefix("|") }.prefix { $0.hasPrefix("|") }
        let header = cells(of: try #require(lines.first))
        return lines.dropFirst(2).map { Dictionary(uniqueKeysWithValues: zip(header, cells(of: $0))) }
    }

    /// The cells of a row. They are split on unescaped pipes; "\|" is a pipe inside a cell.
    static func cells(of line: String) -> [String] {
        line.replacingOccurrences(of: #"\|"#, with: "\u{0}").split(separator: "|", omittingEmptySubsequences: false)
            .dropFirst().dropLast().map { $0.replacingOccurrences(of: "\u{0}", with: "|").trimmingCharacters(in: .whitespaces) }
    }

    /// The cells of each row of the first table after `heading`, without its header and its rule.
    static func rows(after heading: String) throws -> [[String]] {
        let page = try text()
        guard let start = page.range(of: heading) else { throw PageError(description: "no heading \(heading)") }
        let lines = page[start.upperBound...].components(separatedBy: "\n").drop { !$0.hasPrefix("|") }.prefix { $0.hasPrefix("|") }
        // Cells split on unescaped pipes; "\|" is a pipe inside a cell.
        return lines.dropFirst(2).map { line in
            line.replacingOccurrences(of: #"\|"#, with: "\u{0}").split(separator: "|", omittingEmptySubsequences: false)
                .dropFirst().dropLast().map { $0.replacingOccurrences(of: "\u{0}", with: "|").trimmingCharacters(in: .whitespaces) }
        }
    }

    static func backticked(_ text: String) -> [String] { matches("`([^`]+)`", in: text) }

    /// The first two capture groups of every match.
    static func pairs(_ pattern: String, in text: String) -> [(String, String)] {
        let regex: NSRegularExpression
        do { regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) } catch { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            (ns.substring(with: $0.range(at: 1)), ns.substring(with: $0.range(at: 2)))
        }
    }

    /// The first capture group of every match.
    static func matches(_ pattern: String, in text: String) -> [String] {
        let regex: NSRegularExpression
        do { regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) } catch { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
    }
}

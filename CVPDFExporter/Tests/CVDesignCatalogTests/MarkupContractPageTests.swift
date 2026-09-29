import Testing
import Foundation
@testable import CVDesignCatalog

/// markup-contract.md is normative (ADR 0011): these tests read it and hold the code to it. The sets must be equal,
/// and every property's documented values and bounds are probed at their edges against the CSS policy.
@Suite("markup-contract.md matches the code (#83)")
struct MarkupContractPageTests {
    @Test("the selectable elements, classes, section kinds, ratings and pseudo-classes are the contract's")
    func selectable() throws {
        let rows = try Page.table(after: "### Selectable by a design")
        func values(_ kind: String) throws -> Set<String> { Set(Page.backticked(try #require(rows[kind], "no row \(kind)"))) }
        #expect(try values("Elements") == MarkupContract.elements)
        #expect(try values("Classes") == MarkupContract.classes)
        #expect(try values("`[data-section=…]`") == MarkupContract.sectionKinds)
        let ratings = try values("`[data-rating=…]`").compactMap(Int.init)
        #expect(Set((try #require(ratings.min())...(try #require(ratings.max()))).map(String.init)) == MarkupContract.ratings)
        #expect(try Set(values("Pseudo-classes").map { String($0.drop { $0 == ":" }) }) == MarkupContract.pseudoClasses)
    }

    @Test("the structure uses exactly the contract's classes and elements")
    func structure() throws {
        let tree = try Page.section(from: "### Structure", to: "**Inline text")
        #expect(Set(Page.matches(#"\.(cv[a-z-]*)"#, in: tree)) == MarkupContract.classes)
        let elements = Set(Page.matches(#"(?:^|[\s>─])([a-z][a-z0-9]*)(?=[.\[])"#, in: tree)).subtracting(["html"])
        #expect(elements == MarkupContract.elements)
    }

    @Test("the declarations table lists exactly the allowed properties")
    func propertyNames() throws {
        #expect(Set(try Page.properties().map(\.name)) == Set(allowedProperties.keys))
    }

    @Test("each property's keywords are exactly the ones the policy accepts")
    func keywords() throws {
        for property in try Page.properties() {
            #expect(Set(property.spec.keywords) == propertyKeywords[property.name, default: []], "keywords of \(property.name)")
        }
    }

    @Test("the custom properties a design can read are the ones the declarations table uses")
    func customProperties() throws {
        let listed = Set(Page.backticked(try #require(try Page.table(after: "### Selectable by a design")["Custom properties (read only, through `var()`)"])))
        let used = Set(try Page.properties().flatMap(\.spec.variables).map { String($0.dropFirst(4).dropLast()) })
        #expect(listed == used)
    }

    @Test("every documented value is accepted and every value just outside a bound is rejected")
    func bounds() throws {
        for property in try Page.properties() {
            let probes = property.probes()
            #expect(probes.contains { $0.1 } && probes.contains { !$0.1 }, "the page's values for \(property.name) were not understood")
            for (declaration, accepted) in probes {
                let result = (try? CSSPolicy.canonical(".cv{\(declaration);gap:3pt}")) != nil
                #expect(result == accepted, "\(declaration) should be \(accepted ? "accepted" : "rejected")")
            }
        }
    }
}

// MARK: - Reading the page

enum Page {
    struct PageError: Error, CustomStringConvertible { let description: String }

    /// The page, from the repository: this file is CVPDFExporter/Tests/CVDesignCatalogTests/….
    static func text() throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent("docs/architecture/markup-contract.md"), encoding: .utf8)
    }

    static func section(from start: String, to end: String) throws -> String {
        let page = try text()
        guard let a = page.range(of: start), let b = page.range(of: end, range: a.upperBound..<page.endIndex) else {
            throw PageError(description: "no section from \(start) to \(end)")
        }
        return String(page[a.upperBound..<b.lowerBound])
    }

    /// The first table after `heading`, as its first column → second column.
    static func table(after heading: String) throws -> [String: String] {
        let rows = try tableRows(after: heading)
        return Dictionary(rows.map { ($0[0], $0[1]) }, uniquingKeysWith: { first, _ in first })
    }

    static func tableRows(after heading: String) throws -> [[String]] {
        let page = try text()
        guard let start = page.range(of: heading) else { throw PageError(description: "no heading \(heading)") }
        let lines = page[start.upperBound...].components(separatedBy: "\n").drop { !$0.hasPrefix("|") }.prefix { $0.hasPrefix("|") }
        // Cells split on unescaped pipes; "\|" is a pipe inside a cell. Both tables have exactly two columns.
        return try lines.dropFirst(2).map { line in
            let cells = line.replacingOccurrences(of: #"\|"#, with: "\u{0}").split(separator: "|", omittingEmptySubsequences: false)
                .dropFirst().dropLast().map { $0.replacingOccurrences(of: "\u{0}", with: "|").trimmingCharacters(in: .whitespaces) }
            guard cells.count == 2 else { throw PageError(description: "a row without exactly two cells: \(line)") }
            return cells
        }
    }

    static func backticked(_ text: String) -> [String] { matches("`([^`]+)`", in: text) }

    /// The first capture group of every match.
    static func matches(_ pattern: String, in text: String) -> [String] {
        let regex: NSRegularExpression
        do { regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) } catch { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
    }

    /// The declarations table, one entry per property: "`margin-top`, `-bottom`" names margin-top and margin-bottom.
    static func properties() throws -> [Property] {
        let rows = try tableRows(after: "**Declarations.**")
        var specs: [String: Spec] = [:], named: [(String, String)] = []
        for row in rows {
            var base = ""
            for item in backticked(row[0]) {
                let name = item.hasPrefix("-") ? base + item : item
                if !item.hasPrefix("-") { base = String(item[..<(item.lastIndex(of: "-") ?? item.endIndex)]) }   // margin-top → margin
                named.append((name, row[1]))
            }
        }
        for (name, text) in named { specs[name] = Spec(name: name, text: text) }
        // "a colour as for `color`" takes the values of that row.
        return named.map { name, text in
            var spec = specs[name]!
            for other in matches(#"as for `([a-z-]+)`"#, in: text) { spec.variables += specs[other]?.variables ?? [] }
            return Property(name: name, spec: spec)
        }
    }
}

// MARK: - A documented property

struct Spec {
    var keywords: [String] = [], variables: [String] = []
    var pt: ClosedRange<Double>?, em: ClosedRange<Double>?, percent: ClosedRange<Double>?, fr: ClosedRange<Double>?, number: ClosedRange<Double>?
    var count: ClosedRange<Int>?
    /// `gap`: one length takes the column bounds, two lengths are row then column.
    var rowPt: ClosedRange<Double>?, rowEm: ClosedRange<Double>?

    init(name: String, text: String) {
        var text = text.replacingOccurrences(of: #"as for `[a-z-]+`"#, with: "", options: .regularExpression)
        if name == "gap", let row = text.range(of: ": row ") {
            let rows = String(text[row.upperBound...])
            let column = rows.range(of: "column ")
            let row = String(rows[..<(column?.lowerBound ?? rows.endIndex)])
            rowPt = Self.range(#"([\d.]+)–([\d.]+) pt"#, in: row)
            rowEm = Self.range(#"([\d.]+)–([\d.]+) em/rem"#, in: row)
            text = String(rows[(column?.upperBound ?? rows.endIndex)...])
        }
        // Keywords are listed before any explanation, which starts at the first "; " or ". ".
        let listed = text.components(separatedBy: "; ")[0].components(separatedBy: ". ")[0]
        keywords = Page.backticked(listed).filter { $0.range(of: #"^[a-z][a-z-]*$"#, options: .regularExpression) != nil && $0 != "fr" }
        variables = Page.backticked(text).filter { $0.hasPrefix("var(--") }
        pt = Self.range(#"([\d.]+)–([\d.]+) pt"#, in: text)
        em = Self.range(#"([\d.]+)–([\d.]+) em/rem"#, in: text)
        percent = Self.range(#"([\d.]+)–([\d.]+) %"#, in: text)
        fr = Self.range(#"([\d.]+)–([\d.]+) `fr`"#, in: text)
        number = Self.range(#"a number ([\d.]+)–([\d.]+)"#, in: text)
        if let counts = Self.range(#"(\d)–(\d) (?:lengths|tracks)"#, in: text) { count = Int(counts.lowerBound)...Int(counts.upperBound) }
    }

    static func range(_ pattern: String, in text: String) -> ClosedRange<Double>? {
        let regex: NSRegularExpression
        do { regex = try NSRegularExpression(pattern: pattern) } catch { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              let a = Double(ns.substring(with: m.range(at: 1))), let b = Double(ns.substring(with: m.range(at: 2))) else { return nil }
        return a...b
    }
}

struct Property {
    let name: String, spec: Spec

    /// Declarations with whether the page says they are allowed.
    func probes() -> [(String, Bool)] {
        func n(_ v: Double) -> String { let r = (v * 1000).rounded() / 1000; return r == r.rounded() ? String(Int(r)) : String(r) }
        func d(_ value: String) -> String { "\(name):\(value)" }
        var p: [(String, Bool)] = []
        p += spec.keywords.map { (d($0), true) }
        p += spec.variables.map { (d($0), true) }
        if !spec.keywords.isEmpty || !spec.variables.isEmpty { p += [(d("inherit"), false), (d("var(--color-accent)"), false)] }
        if let r = spec.pt {
            p += [(d("\(n(r.lowerBound))pt"), true), (d("\(n(r.upperBound))pt"), true), (d("\(n(r.upperBound + 1))pt"), false),
                  (d("\(n(r.upperBound / 0.75))px"), true), (d("\(n(r.upperBound / 0.75 + 2))px"), false),
                  (d("0"), r.contains(0))]                                  // a bare 0 only where 0 is within the bounds
            if r.lowerBound >= 1 { p.append((d("\(n(r.lowerBound - 1))pt"), false)) }
            if spec.em == nil { p += [(d("1em"), false), (d("1rem"), false)] }
            if spec.percent == nil { p.append((d("50%"), false)) }
        }
        if let r = spec.em {
            p += [(d("\(n(r.lowerBound))em"), true), (d("\(n(r.upperBound))em"), true), (d("\(n(r.upperBound))rem"), true),
                  (d("\(n(r.upperBound + 0.1))em"), false)]
            if r.lowerBound > 0 { p.append((d("\(n(r.lowerBound - 0.05))em"), false)) }
        }
        if let r = spec.percent {
            p += [(d("\(n(r.lowerBound))%"), true), (d("\(n(r.upperBound))%"), true), (d("\(n(r.upperBound + 1))%"), false),
                  (d("\(n(r.lowerBound - 1))%"), false)]
        }
        if let r = spec.fr { p += [(d("\(n(r.lowerBound))fr"), true), (d("\(n(r.upperBound))fr"), true), (d("\(n(r.upperBound + 1))fr"), false)] }
        if let r = spec.number {
            p += [(d(n(r.lowerBound)), true), (d(n(r.upperBound)), true), (d(n(r.upperBound + 1)), false)]
            if r.lowerBound >= 1 { p.append((d(n(r.lowerBound - 1)), false)) }
        }
        if let c = spec.count, let r = spec.fr ?? spec.pt {
            let one = spec.fr != nil ? "\(n(r.upperBound))fr" : "\(n(r.upperBound))pt"
            p += [(d(Array(repeating: one, count: c.upperBound).joined(separator: " ")), true),
                  (d(Array(repeating: one, count: c.upperBound + 1).joined(separator: " ")), false)]
        }
        if name == "gap" {
            guard let row = spec.rowPt, let rowEm = spec.rowEm, let column = spec.pt else { return [] }   // fails the coverage check
            let c = "\(n(column.lowerBound))pt"
            p += [(d("\(n(row.lowerBound))pt \(c)"), true), (d("\(n(row.upperBound))pt \(c)"), true), (d("\(n(row.upperBound + 1))pt \(c)"), false),
                  (d("\(n(rowEm.lowerBound))em \(c)"), true), (d("\(n(rowEm.upperBound))rem \(c)"), true),
                  (d("\(n(rowEm.upperBound + 0.1))em \(c)"), false)]
        }
        return p
    }
}

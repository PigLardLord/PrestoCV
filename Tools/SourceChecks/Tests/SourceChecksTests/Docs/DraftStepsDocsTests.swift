import Foundation
import Testing

// MARK: - Draft Steps Docs Tests

/// ADR 0031's section "A request per section" lists the steps of a draft in order, and the logging guide names the steps a
/// `draft.unwritten` event can give. Both stay true only if they name the cases of `DraftStep`, in its order, and the deadlines of
/// `DraftingLimits.standard`.
@Suite("The steps of a draft in the docs")
struct DraftStepsDocsTests {

    private static let root = Repository.root
    private static let source = "CVGeneratorAI/Sources/CVGeneratorAI/UseCases/DraftAttempt.swift"
    private static let adr = "docs/architecture/adr/0031-let-the-ai-draft-write-around-the-facts.md"
    private static let guide = "docs/logging.md"
    private static let section = "### A request per section"

    private static func text(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// The cases of `DraftStep`, in their order: the lines `case name` of the enum, before its first member.
    private static func stepsInCode() throws -> [String] {
        let lines = try text(source).split(separator: "\n", omittingEmptySubsequences: false)
        let start = try #require(lines.firstIndex { $0.hasPrefix("enum DraftStep") }, "\(source) no longer declares `enum DraftStep`")
        var steps: [String] = []
        for line in lines[(start + 1)...] {
            if line.hasPrefix("}") || line.contains("var ") || line.contains("func ") { break }
            if let match = line.wholeMatch(of: /\s+case ([a-z][A-Za-z]*)/) { steps.append(String(match.output.1)) }
        }
        return steps
    }

    /// The lines of the ADR's section, up to the next heading of its level or above.
    private static func sectionLines() throws -> [Substring] {
        let lines = try text(adr).split(separator: "\n", omittingEmptySubsequences: false)
        let start = try #require(lines.firstIndex { $0 == section }, "\(adr) has no line \"\(section)\"")
        let rest = lines[(start + 1)...]
        let end = rest.firstIndex { $0.hasPrefix("## ") || $0.hasPrefix("### ") } ?? rest.endIndex
        return Array(rest[..<end])
    }

    @Test("ADR 0031 lists the steps of a draft as DraftStep has them, in order")
    func adrListsTheSteps() throws {
        let inCode = try Self.stepsInCode()
        let listed = try Self.sectionLines().compactMap { line in
            line.firstMatch(of: /^\d+\. \*\*[^*]*\(`([a-z][A-Za-z]*)`\)/).map { String($0.output.1) }
        }

        #expect(!inCode.isEmpty, "No case found in `enum DraftStep` of \(Self.source): the pattern no longer matches the code")
        #expect(listed == inCode, "\(Self.adr), \"\(Self.section)\", lists \(listed); DraftStep has \(inCode)")
    }

    @Test("The logging guide names every step after the facts as a step of draft.unwritten")
    func guideNamesTheUnwrittenSteps() throws {
        let inCode = try Self.stepsInCode().dropFirst()
        let row = try #require(
            try Self.text(Self.guide).split(separator: "\n").first { $0.hasPrefix("| `draft.unwritten` |") },
            "\(Self.guide) has no row for draft.unwritten"
        )
        let cell = try #require(row.firstMatch(of: /`step` \(([^)]*)\)/)?.output.1, "The row of draft.unwritten names no `step` (…)")
        let named = cell.matches(of: /`([a-z][A-Za-z]*)`/).map { String($0.output.1) }

        #expect(named == Array(inCode), "\(Self.guide) names \(named) as the steps of draft.unwritten; DraftStep has \(Array(inCode))")
    }

    @Test("ADR 0031 gives the deadlines of DraftingLimits.standard")
    func adrGivesTheDeadlines() throws {
        let code = try Self.text(Self.source)
        let limits = try #require(
            code.firstMatch(of: /static let standard = DraftingLimits\(extraction: \.seconds\((\d+)\), section: \.seconds\((\d+)\)\)/),
            "\(Self.source) no longer gives the limits as `.seconds(n)`"
        )
        let section = try Self.sectionLines().joined(separator: "\n")

        #expect(section.contains("\(limits.output.1) s for the facts"), "The section gives no \"\(limits.output.1) s for the facts\"")
        #expect(section.contains("\(limits.output.2) s for each other request"),
                "The section gives no \"\(limits.output.2) s for each other request\"")
    }
}

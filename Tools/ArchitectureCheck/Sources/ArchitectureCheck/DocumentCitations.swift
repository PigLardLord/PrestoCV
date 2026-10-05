import Foundation

/// `ruleNumberCitation` in the documents that cite the rules: `docs/`, `AGENTS.md` and every `README.md`. The merged
/// ADRs 0001 to 0012 keep the numbers they were written with, ADR 0021 explains them, and the table of former numbers
/// in `rules.md` maps them; none of these is read. A prototype is not read either.
enum DocumentCitations {
    static func isChecked(_ path: String) -> Bool {
        guard path.hasSuffix(".md"), !path.hasPrefix("Prototypes/"), !isRecordOfFormerNumbers(path) else { return false }
        return path.hasPrefix("docs/") || path == "AGENTS.md" || path.split(separator: "/").last == "README.md"
    }

    static func hits(in text: String, at path: String) -> [Hit] {
        let skipped = path == rulesPath ? formerNumbersLines(in: text) : []
        return text.components(separatedBy: "\n").enumerated().flatMap { offset, line in
            skipped.contains(offset + 1) ? [] : CommentCitations.citations(in: line, at: offset + 1)
        }
    }

    private static let rulesPath = "docs/architecture/rules.md"
    private static let formerNumbersHeading = "## Former numbers"

    private static func isRecordOfFormerNumbers(_ path: String) -> Bool {
        path.range(of: #"^docs/architecture/adr/(00(0[1-9]|1[0-2])|0021)-"#, options: .regularExpression) != nil
    }

    /// The lines from the heading of the table of former numbers to the next heading of its level.
    private static func formerNumbersLines(in text: String) -> Set<Int> {
        var inSection = false, lines: Set<Int> = []
        for (offset, line) in text.components(separatedBy: "\n").enumerated() {
            if line.hasPrefix("## ") { inSection = line == formerNumbersHeading }
            if inSection { lines.insert(offset + 1) }
        }
        return lines
    }
}

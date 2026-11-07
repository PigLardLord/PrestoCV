import Foundation

// MARK: - Readme Text

/// Reads the README's "Where things are" table, finds the placeholders that an open-source file must not keep, and finds the
/// paragraph that makes a statement. Everything here is a function of the text, so it is tested without git and without files
/// (`ReadmeTextTests`); `ReadmeTests` holds the repository to it.
enum ReadmeText {

    /// The heading of the table that says what each part of the repository is.
    static let tableHeading = "## Where things are"

    // MARK: - The table

    /// The paths the table names, in the order they are written, each once and without a trailing slash.
    ///
    /// The table is every row up to the next heading of level one or two; a heading in a code fence or in a comment is not a
    /// heading. A row is a line that starts with a bar, whatever its spacing or indent. The header row (the one before the
    /// separator row) and the separator are not read. In the first cell every code span is a path; in the other cells a code
    /// span is a path only if it holds a slash and no white space or wildcard, so that `swift test` and `docs/adr/*.md` are
    /// not. The files that a row links to are paths in every cell.
    static func tablePaths(in readme: String) -> [String] {
        let lines = MarkdownText.lines(of: MarkdownText.withoutFencesAndComments(readme)).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let heading = lines.firstIndex(of: tableHeading) else { return [] }
        let section = Array(lines[(heading + 1)...].prefix { (MarkdownText.headingLevel(of: $0) ?? 3) > 2 })

        var paths: [String] = []
        for (index, row) in section.enumerated() where row.hasPrefix("|") && !MarkdownText.isTableSeparator(row) {
            let isHeader = index + 1 < section.count && MarkdownText.isTableSeparator(section[index + 1])
            guard !isHeader else { continue }
            for (position, cell) in cells(of: row).enumerated() {
                paths += pathsNamed(in: cell, isFirstCell: position == 0)
            }
        }

        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }

    /// The cells of a row, without the bars around the row and without the space around a cell.
    private static func cells(of row: String) -> [String] {
        var cells = row.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        if cells.first == "" { cells.removeFirst() }
        if cells.last == "" { cells.removeLast() }
        return cells
    }

    private static func pathsNamed(in cell: String, isFirstCell: Bool) -> [String] {
        let spans = MarkdownText.codeSpans(in: cell).filter { isFirstCell || looksLikeAPath($0) }
        return (spans + MarkdownText.relativeLinkTargets(in: cell)).compactMap { name in
            var path = name.trimmingCharacters(in: .whitespaces)
            while path.hasSuffix("/") { path.removeLast() }
            return path.isEmpty ? nil : path
        }
    }

    private static func looksLikeAPath(_ span: String) -> Bool {
        span.contains("/") && !span.contains { $0.isWhitespace || "*<>{}[]?|".contains($0) }
    }

    // MARK: - Placeholders

    /// The placeholders in `text`, in the order they stand: `[INSERT ...]`, `CONTACT_...`, `YOUR_...`, `TODO`, `FIXME` and
    /// `TBD`. They are found wherever they stand, in prose, in comments and in code, because an open-source file is published
    /// as it is; a plain word such as `todo` or `TODOS`, and a file name such as `CODE_OF_CONDUCT.md`, is not one.
    static func placeholders(in text: String) -> [String] {
        text.matches(of: #/\[INSERT[^\]\n]*\]|\bCONTACT_[A-Z_]+\b|\bYOUR_[A-Z_]+\b|\bTODO\b|\bFIXME\b|\bTBD\b/#).map { String(text[$0.range]) }
    }

    // MARK: - A statement

    /// Whether one paragraph, list item or table row of `text` holds every phrase, in any case. A heading is no statement, and
    /// neither is a phrase in a code fence or in a comment; the lines of a paragraph are one text, so a phrase may wrap.
    static func paragraphMentioning(_ phrases: [String], in text: String) -> Bool {
        MarkdownText.blocks(in: text).contains { block in
            block.kind != .heading && phrases.allSatisfy { block.text.lowercased().contains($0.lowercased()) }
        }
    }
}

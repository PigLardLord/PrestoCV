import Foundation

/// One line of what a person wrote about an experience, without the bullet that opened it. It is the unit of provenance
/// (ADR 0013): a rewritten line names the statements of the source it comes from.
///
/// `split(_:)` is the only rule that turns a description into statements, and every target uses it. A statement from
/// the split is trimmed and not empty; its size is bounded where it joins a snapshot.
public struct Statement: Hashable, Sendable {
    public let text: String

    /// A statement of text written elsewhere, such as a line a model wrote. The text is trimmed and kept as it is, and
    /// must not be empty or longer than `TailoringLimits.maxTextBytes`.
    public init(text: String) throws(TailoringModelError) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .emptyField(.statement) }
        try Bounds.text(trimmed, .statement)
        self.text = trimmed
    }

    private init(line text: String) { self.text = text }

    /// Splits a description into statements: one per line, where a line ends at any newline (`\r\n` is one).
    /// - Each line is trimmed of whitespace at both ends.
    /// - One leading bullet is removed when a space follows it or it ends the line: `•`, `◦`, `▪`, `‣`, `·`, `-`,
    ///   `*`, `–`, `—`. So "-5% churn" keeps its sign, and a numbered item ("1. ") is not a bullet.
    /// - A line that is empty after that is dropped, so a description of one paragraph is one statement.
    public static func split(_ description: String) -> [Statement] {
        var statements: [Statement] = []
        for line in description.split(whereSeparator: \.isNewline) {
            let text = withoutBullet(line.trimmingCharacters(in: .whitespacesAndNewlines))
            if !text.isEmpty { statements.append(Statement(line: text)) }
        }
        return statements
    }

    private static let bullets: Set<Character> = ["\u{2022}", "\u{25E6}", "\u{25AA}", "\u{2023}", "\u{00B7}", "-", "*", "\u{2013}", "\u{2014}"]

    private static func withoutBullet(_ line: String) -> String {
        guard let first = line.first, bullets.contains(first) else { return line }
        let rest = line.dropFirst()
        guard rest.first?.isWhitespace ?? true else { return line }
        return rest.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

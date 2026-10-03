/// One line of what a person wrote about an experience, without the bullet that opened it. It is the unit of provenance
/// (ADR 0013): a rewritten line names the statements of the source it comes from.
///
/// `split(_:)` is the only rule that turns a description into statements, and every target uses it. Two initialisers
/// build a statement from a line, for two different purposes:
/// - `init(text:)` rebuilds a statement a snapshot already holds, verbatim: bullets are kept, since the snapshot's
///   statements are never split again.
/// - `init(writtenLine:)` makes a statement of a line somebody wrote, a model or a person, by the rule of the split.
///
/// A statement from the split is trimmed, not empty and one line, as is one built by either initialiser. Its size is
/// bounded where it joins a snapshot.
public struct Statement: Hashable, Sendable {
    public let text: String

    /// A statement rebuilt from the text of one a snapshot holds. The blank characters at either end are trimmed
    /// (`Bounds.trimmed`) and the rest is kept verbatim, a leading bullet included. It must not be empty, hold a line
    /// break (`notOneLine`) or be longer than `TailoringLimits.maxTextBytes`. For a line somebody wrote, use
    /// `init(writtenLine:)`.
    public init(text: String) throws(TailoringModelError) {
        let trimmed = Bounds.trimmed(text[...])
        guard !trimmed.isEmpty else { throw .emptyField(.statement) }
        guard !trimmed.contains(where: \.isNewline) else { throw .notOneLine(.statement) }
        try Bounds.text(String(trimmed), .statement)
        self.text = String(trimmed)
    }

    /// A statement from a line a model or a person wrote, by the rule of the split on one line: the blank characters
    /// at either end are trimmed, one leading bullet is removed, and the rest is trimmed again. A line that is empty
    /// after that, such as a bare bullet, is `emptyField`; a line break inside it is `notOneLine`; and it is bounded
    /// by `TailoringLimits.maxTextBytes`.
    public init(writtenLine text: String) throws(TailoringModelError) {
        let trimmed = Bounds.trimmed(text[...])
        guard !trimmed.contains(where: \.isNewline) else { throw .notOneLine(.statement) }
        let line = Self.rule(trimmed)
        guard !line.isEmpty else { throw .emptyField(.statement) }
        try Bounds.text(String(line), .statement)
        self.text = String(line)
    }

    private init(line text: String) { self.text = text }

    /// Splits a description into statements: one per line, where a line ends at any newline (`\r\n` is one).
    /// - Each line is trimmed of its blank characters at both ends: whitespace of any width, and invisible ones such as
    ///   a zero-width space or a byte order mark (`Bounds.isBlank`).
    /// - One leading bullet is removed when a whitespace character follows it, or it ends the line: `•`, `◦`, `▪`, `‣`,
    ///   `·`, `-`, `*`, `–`, `—`, `●`, `○`, `■`, `➢`, `➤`, `✓` and U+F0B7 (the private-use bullet that word processors
    ///   write). What follows it is trimmed again. So "-5% churn" keeps its sign, a numbered item ("1. ") is not a
    ///   bullet, and a bullet followed by a combining mark keeps everything as written, with no mark left orphaned.
    /// - A line that is empty after that is dropped, so a description of one paragraph is one statement.
    public static func split(_ description: String) -> [Statement] {
        var statements: [Statement] = []
        for line in description.split(whereSeparator: \.isNewline) {
            let text = rule(line)
            if !text.isEmpty { statements.append(Statement(line: String(text))) }
        }
        return statements
    }

    private static let bullets: Set<Character> = {
        var set: Set<Character> = []
        set.formUnion(["\u{2022}", "\u{25E6}", "\u{25AA}", "\u{2023}", "\u{00B7}", "-", "*", "\u{2013}", "\u{2014}"])
        set.formUnion(["\u{25CF}", "\u{25CB}", "\u{25A0}", "\u{27A2}", "\u{27A4}", "\u{2713}", "\u{F0B7}"])
        return set
    }()

    /// The rule for one line, which the split and `init(writtenLine:)` share: trim, remove one bullet, trim.
    private static func rule(_ line: Substring) -> Substring {
        withoutBullet(Bounds.trimmed(line))
    }

    private static func withoutBullet(_ line: Substring) -> Substring {
        guard let first = line.first, bullets.contains(first) else { return line }
        let rest = line.dropFirst()
        guard rest.first.map(Bounds.isSpace) ?? true else { return line }
        return Bounds.trimmed(rest)
    }
}

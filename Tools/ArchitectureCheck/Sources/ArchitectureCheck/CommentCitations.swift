import Foundation
import SwiftSyntax

/// `ruleNumberCitation`: a comment that cites a rule by the number it had before ADR 0021 (the letter R and a number
/// from 1 to 14, optionally followed by m). A rule is cited by its name. Strings are not comments, so a string that
/// holds such a number is left alone.
enum CommentCitations {
    private static let pattern = try! NSRegularExpression(pattern: #"\bR(1[0-4]|[1-9])m?\b"#)

    static func hits(in tree: SourceFileSyntax, lines: CodeLines) -> [Hit] {
        tree.tokens(viewMode: .sourceAccurate).flatMap { token in
            hits(in: token.leadingTrivia, from: token.position, lines: lines)
                + hits(in: token.trailingTrivia, from: token.endPositionBeforeTrailingTrivia, lines: lines)
        }
    }

    private static func hits(in trivia: Trivia, from start: AbsolutePosition, lines: CodeLines) -> [Hit] {
        var found: [Hit] = []
        var position = start
        for piece in trivia {
            if let text = commentText(piece) { found += citations(in: text, at: lines.line(at: position)) }
            position = position.advanced(by: piece.sourceLength.utf8Length)
        }
        return found
    }

    private static func commentText(_ piece: TriviaPiece) -> String? {
        switch piece {
        case .lineComment(let text), .blockComment(let text), .docLineComment(let text), .docBlockComment(let text): text
        default: nil
        }
    }

    private static func citations(in comment: String, at firstLine: Int) -> [Hit] {
        let text = comment as NSString
        return pattern.matches(in: comment, range: NSRange(location: 0, length: text.length)).map { match in
            let number = text.substring(with: match.range)
            let line = firstLine + text.substring(to: match.range.location).filter { $0 == "\n" }.count
            return Hit(measured: "ruleNumberCitation", "the comment cites a rule by its former number \(number); cite it by name", line: line)
        }
    }
}

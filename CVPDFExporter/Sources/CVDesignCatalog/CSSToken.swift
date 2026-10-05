import Foundation

/// What the tokenizer reads: the tokens of the CSS subset the policy accepts. Anything else is refused before it can
/// become one.
enum CSSToken: Equatable, Sendable {
    case ident(String), function(String), atKeyword(String), hash(String), string(String)
    case number(Double), percentage(Double), dimension(Double, String)
    case colon, semicolon, comma, lbrace, rbrace, lparen, rparen, lbracket, rbracket
    case delim(Unicode.Scalar), whitespace
}

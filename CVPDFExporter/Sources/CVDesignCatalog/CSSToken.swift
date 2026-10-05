import Foundation

enum CSSToken: Equatable, Sendable {
    case ident(String), function(String), atKeyword(String), hash(String), string(String)
    case number(Double), percentage(Double), dimension(Double, String)
    case colon, semicolon, comma, lbrace, rbrace, lparen, rparen, lbracket, rbracket
    case delim(Unicode.Scalar), whitespace
}

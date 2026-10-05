import Foundation

/// Why design CSS was refused: the first construct outside the allow-list.
public struct CSSRejection: Error, Equatable, Sendable, CustomStringConvertible {
    public let reason: String
    public var description: String { reason }
}

enum CSSToken: Equatable, Sendable {
    case ident(String), function(String), atKeyword(String), hash(String), string(String)
    case number(Double), percentage(Double), dimension(Double, String)
    case colon, semicolon, comma, lbrace, rbrace, lparen, rparen, lbracket, rbracket
    case delim(Unicode.Scalar), whitespace
}

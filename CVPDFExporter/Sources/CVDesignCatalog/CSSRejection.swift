import Foundation

/// Why design CSS was refused: the first construct outside the allow-list.
public struct CSSRejection: Error, Equatable, Sendable, CustomStringConvertible {
    public let reason: String
    public var description: String { reason }
}

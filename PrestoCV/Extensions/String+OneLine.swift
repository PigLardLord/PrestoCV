import Foundation

extension String {
    /// The text on one line: every line break becomes a space, and a break at either end goes away.
    var onOneLine: String {
        split(whereSeparator: \.isNewline).joined(separator: " ")
    }
}

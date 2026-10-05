import Foundation

extension String {
    /// Whole-string match. `^…$` would accept a trailing newline (and U+2028), `\z` does not.
    func fullyMatches(_ pattern: String) -> Bool {
        range(of: "^(?:" + pattern + ")\\z", options: .regularExpression) != nil
    }
}

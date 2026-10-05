import Foundation

extension String {
    /// Whole-string match. `^…$` would accept a trailing newline (and U+2028), `\z` does not.
    /// Shared with `CVRendering`, in the same package; not part of the library's interface.
    package func fullyMatches(_ pattern: String) -> Bool {
        range(of: "^(?:" + pattern + ")\\z", options: .regularExpression) != nil
    }
}

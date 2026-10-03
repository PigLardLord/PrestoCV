import Testing
import TailoringModel

/// A string of exactly `count` UTF-8 bytes, all ASCII.
func ascii(_ count: Int) -> String { String(repeating: "a", count: count) }

/// A string of exactly `count` UTF-8 bytes made of two-byte characters, so a character count and a byte count differ.
func twoByteCharacters(bytes count: Int) -> String { String(repeating: "\u{00E9}", count: count / 2) }

/// A text field of the model, reached through the initialiser that owns it, so a bound is tested where it is enforced.
struct TextFieldCase: Sendable, CustomTestStringConvertible {
    let field: TailoringModelError.Field
    let build: @Sendable (String) throws -> Void
    init(_ field: TailoringModelError.Field, _ build: @escaping @Sendable (String) throws -> Void) {
        self.field = field
        self.build = build
    }
    var testDescription: String { "\(field)" }
}

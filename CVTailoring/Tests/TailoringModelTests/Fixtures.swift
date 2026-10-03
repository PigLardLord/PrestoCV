import TailoringModel

/// A string of exactly `count` UTF-8 bytes, all ASCII.
func ascii(_ count: Int) -> String { String(repeating: "a", count: count) }

/// A string of exactly `count` UTF-8 bytes made of two-byte characters, so a character count and a byte count differ.
func twoByteCharacters(bytes count: Int) -> String { String(repeating: "\u{00E9}", count: count / 2) }

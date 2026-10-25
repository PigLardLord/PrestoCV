import Testing
@testable import PrestoCVImporting

/// A piece of the text is cut and trimmed in one pass over its text, and cut at a place in the time it takes to find the
/// place: a line of a hundred thousand characters is cut many times, and none of them may read the line again (R8).
@Suite("Cutting and trimming a piece of the text")
struct PieceTests {

    // MARK: The rules, as they were written before they were made linear

    /// The cut of the first version, one pass of trimming after another, each over what the last left: the oracle the
    /// linear one has to agree with, character by character and span by span.
    private enum Reference {
        static func sub(_ piece: Piece, _ range: Range<String.Index>) -> Piece {
            let scalars = piece.text.unicodeScalars
            let lower = scalars.distance(from: scalars.startIndex, to: range.lowerBound)
            let upper = scalars.distance(from: scalars.startIndex, to: range.upperBound)
            return Piece(text: String(piece.text[range]), span: SourceSpan(piece.span.lowerBound + lower, piece.span.lowerBound + upper))
        }

        static func trimmed(_ start: Piece) -> Piece {
            let characters = Piece.isTrimmable
            var piece = start
            while true {
                guard let start = piece.text.firstIndex(where: { !characters($0) }),
                      let last = piece.text.lastIndex(where: { !characters($0) }) else {
                    return sub(piece, piece.text.endIndex..<piece.text.endIndex)
                }
                piece = sub(piece, start..<piece.text.index(after: last))
                let opens = piece.text.filter { $0 == "(" || $0 == "[" }.count
                let closes = piece.text.filter { $0 == ")" || $0 == "]" }.count
                if let lastCharacter = piece.text.last, lastCharacter == "(" || lastCharacter == "[" {
                    piece = sub(piece, piece.text.startIndex..<piece.text.index(before: piece.text.endIndex))
                } else if let first = piece.text.first, first == ")" || first == "]" {
                    piece = sub(piece, piece.text.index(after: piece.text.startIndex)..<piece.text.endIndex)
                } else if let first = piece.text.first, first == "(" || first == "[", opens > closes {
                    piece = sub(piece, piece.text.index(after: piece.text.startIndex)..<piece.text.endIndex)
                } else if let lastCharacter = piece.text.last, lastCharacter == ")" || lastCharacter == "]", closes > opens {
                    piece = sub(piece, piece.text.startIndex..<piece.text.index(before: piece.text.endIndex))
                } else if piece.text.first == "(" && piece.text.last == ")" && opens == 1 && closes == 1 {
                    piece = sub(piece, piece.text.index(after: piece.text.startIndex)..<piece.text.index(before: piece.text.endIndex))
                } else {
                    return piece
                }
            }
        }
    }

    private func piece(_ text: String, at offset: Int = 7) -> Piece {
        Piece(text: text, span: SourceSpan(offset, offset + text.unicodeScalars.count))
    }

    // MARK: Trimming

    @Test("Trimming agrees with the passes it replaces, on every text of a few characters")
    func trimmedAgreesOnShortTexts() {
        let alphabet = ["(", ")", "[", "]", " ", "a", "📞"]
        var texts = [""]
        var level = [""]
        for _ in 1...6 {
            level = level.flatMap { text in alphabet.map { text + $0 } }
            texts += level
        }
        for text in texts {
            let whole = piece(text)
            let expected = Reference.trimmed(whole)
            let found = whole.trimmed()
            if found != expected {
                Issue.record("\"\(text)\": trimmed to \(found), not \(expected)")
                return
            }
        }
    }

    @Test("Trimming agrees with the passes it replaces, on longer texts of marks, brackets, accents and emoji")
    func trimmedAgreesOnLongerTexts() {
        let alphabet = ["(", ")", "[", "]", " ", "  ", "a", "bc", ",", "-", "|", "•", "📞", "é", "e\u{301}", "(\u{301}", "🇮🇹", "👩‍💻", "\t", "·"]
        var generator = SplitMix(seed: 20_261_025)
        for _ in 0..<4_000 {
            let length = Int(generator.next() % 40)
            let text = (0..<length).map { _ in alphabet[Int(generator.next() % UInt64(alphabet.count))] }.joined()
            let whole = piece(text, at: Int(generator.next() % 1_000))
            let expected = Reference.trimmed(whole)
            let found = whole.trimmed()
            if found != expected {
                Issue.record("\"\(text)\": trimmed to \(found), not \(expected)")
                return
            }
        }
    }

    @Test("Trimming a long run of brackets is one pass over it, not one pass for each bracket it takes off")
    func trimmedIsLinear() {
        let shapes: [(String, (Int) -> String)] = [
            ("opening", { String(repeating: "(", count: $0 * 2) }),
            ("closing", { String(repeating: ") ", count: $0) }),
            ("nested", { String(repeating: "[(", count: $0) + String(repeating: ")]", count: $0) + String(repeating: "(", count: $0) }),
        ]
        for (name, text) in shapes {
            expectLinear(name, whole: 10_000, cost: { size in
                let whole = piece(text(size))
                return cpuSeconds { _ = whole.trimmed() }
            })
        }
    }

    // MARK: Cutting

    @Test("A cut keeps the span of what it cuts, for ASCII, accents, combining marks and characters of two UTF-16 units")
    func subSpans() {
        for text in ["plain text", "caffè e più", "re\u{301}sume\u{301} ok", "📞 +39 333 🇮🇹 ok 👩‍💻 done", "𝔸𝔹 ab ℂ", ""] {
            let whole = piece(text)
            var indices = Array(text.indices)
            indices.append(text.endIndex)
            for lower in indices.indices {
                for upper in indices.indices where upper >= lower {
                    let range = indices[lower]..<indices[upper]
                    let found = whole.sub(range)
                    let expected = Reference.sub(whole, range)
                    if found != expected {
                        Issue.record("\"\(text)\" at \(lower)..<\(upper): \(found), not \(expected)")
                        return
                    }
                }
            }
        }
    }

    @Test("A cut of a piece that was cut has the span it has in the whole text")
    func subOfSub() {
        let whole = piece("caffè 📞 +39 333 000 0000 e più 🇮🇹 fine", at: 100)
        let outer = whole.sub(whole.text.index(whole.text.startIndex, offsetBy: 3)..<whole.text.index(whole.text.endIndex, offsetBy: -2))
        let inner = outer.sub(outer.text.index(outer.text.startIndex, offsetBy: 4)..<outer.text.index(outer.text.endIndex, offsetBy: -3))
        let expected = Reference.sub(Reference.sub(whole, whole.text.index(whole.text.startIndex, offsetBy: 3)..<whole.text.index(whole.text.endIndex, offsetBy: -2)),
                                     outer.text.index(outer.text.startIndex, offsetBy: 4)..<outer.text.index(outer.text.endIndex, offsetBy: -3))
        #expect(inner == expected)
        #expect(String(inner.text) == inner.text)
    }

    @Test("Cutting a long line many times does not read the line again for each cut, whatever its characters", arguments: ["Leeds, ", "Léeds, ", "📞 Leeds, ", "Leeds, 𝔸"])
    func cuttingIsLinear(unit: String) {
        expectLinear(unit, whole: 100_000 / unit.count, cost: { units in
            let whole = piece(String(repeating: unit, count: units))
            var cuts: [Piece] = []
            let seconds = cpuSeconds {
                var index = whole.text.startIndex
                while index < whole.text.endIndex {
                    let next = whole.text.index(index, offsetBy: 1, limitedBy: whole.text.endIndex) ?? whole.text.endIndex
                    cuts.append(whole.sub(index..<next))
                    index = next
                }
            }
            #expect(cuts.count == whole.text.count)
            return seconds
        })
    }

    // MARK: Finding a span

    @Test("The place of a span in a piece is the place counted in scalars from its start, for every span, whatever its characters")
    func rangeOfSpanAgrees() {
        for text in ["plain text", "caffè e più", "re\u{301}sume\u{301} ok", "📞 +39 333 🇮🇹 ok 👩‍💻 done", "𝔸𝔹 ab ℂ", ""] {
            let whole = piece(text, at: 40)
            let scalars = text.unicodeScalars
            let count = scalars.count
            for lower in 0...count {
                for upper in lower...count {
                    let found = whole.range(of: SourceSpan(40 + lower, 40 + upper))
                    let expected = scalars.index(scalars.startIndex, offsetBy: lower)..<scalars.index(scalars.startIndex, offsetBy: upper)
                    if found != expected {
                        Issue.record("\"\(text)\" at \(lower)..<\(upper): \(found), not \(expected)")
                        return
                    }
                }
            }
        }
    }

    @Test("A span beyond the piece is cut to the piece")
    func rangeOfSpanIsCut() {
        let whole = piece("caffè 📞 ok", at: 10)
        #expect(whole.range(of: SourceSpan(0, 1_000)) == whole.text.startIndex..<whole.text.endIndex)
        #expect(whole.range(of: SourceSpan(1_000, 2_000)) == whole.text.endIndex..<whole.text.endIndex)
        #expect(whole.range(of: SourceSpan(0, 10)) == whole.text.startIndex..<whole.text.startIndex)
    }

    @Test("The places of the spans in a long piece are found without counting from its start for each", arguments: ["Leeds, ", "Léeds, ", "📞 Leeds, ", "Leeds, 𝔸"])
    func rangeOfSpanIsLinear(unit: String) {
        expectLinear(unit, whole: 100_000 / unit.unicodeScalars.count, cost: { units in
            let whole = piece(String(repeating: unit, count: units), at: 5)
            let count = whole.span.count
            var found = 0
            let seconds = cpuSeconds {
                for lower in stride(from: 0, to: count - 1, by: 3) {
                    found += whole.text.utf16.distance(from: whole.text.startIndex, to: whole.range(of: SourceSpan(5 + lower, 5 + lower + 1)).lowerBound) & 1
                }
            }
            #expect(found >= 0)
            return seconds
        })
    }

    @Test("Splitting a long line is linear in the line, whatever its brackets and separators")
    func splitIsLinear() {
        let shapes: [(String, (Int) -> String)] = [
            ("opening", { String(repeating: "(", count: $0 * 2) }),
            ("closing", { String(repeating: ") ", count: $0) }),
            ("groups", { String(repeating: "a | (b, c) ", count: $0 / 2) }),
            ("accents", { String(repeating: "é | [", count: $0) }),
        ]
        for (name, text) in shapes {
            expectLinear(name, whole: 10_000, cost: { size in
                let whole = piece(text(size))
                var pieces: [Piece] = []
                let seconds = cpuSeconds { pieces = whole.split(by: Separators.strong) }
                #expect(pieces.count < 20_001)
                return seconds
            })
        }
    }
}

/// A fixed sequence of numbers, the same on every machine.
struct SplitMix {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

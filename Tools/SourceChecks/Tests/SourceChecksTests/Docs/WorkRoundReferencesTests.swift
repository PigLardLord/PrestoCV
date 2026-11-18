import Foundation
import Testing

// MARK: - The references to rounds of work

/// A reference in a Swift source to a round of work or to a commit: the code is read by people who cannot see either, and the
/// history of the repository can be rewritten, so a hash quoted in a comment points nowhere. A comment explains the code, not
/// the round of work that produced it.
enum WorkRoundReferences {
    /// A round of work: the word "round" or "rounds" and a number, or the rounds of a review or a probe with no number. A
    /// number follows the word, so "round trip", "rounded" and "round to 2 decimals" are not found.
    private static let round = try! NSRegularExpression(pattern: #"\brounds?\s+[0-9]+|\b(?:probe|review|no-go)\s+rounds?\b"#, options: .caseInsensitive)

    /// The end of a comment line that wraps between "round" and its number.
    private static let wrappedRound = try! NSRegularExpression(pattern: #"\brounds?\s*$"#, options: .caseInsensitive)

    /// A commit hash: 7 to 40 lower-case hexadecimal characters (as git prints them) with at least one letter and one digit, so
    /// a word such as "defaced", a number and an upper-case feedback number are not found.
    private static let hash = try! NSRegularExpression(pattern: #"\b(?=[0-9a-f]*[a-f])(?=[0-9a-f]*[0-9])[0-9a-f]{7,40}\b"#)

    /// The numbers (from 1) of the lines of `source` that name a round or a hash. Only the text a reader takes for prose is
    /// read: the comments, and the title of a test or a suite. A hex number or colour, or a UUID, in code is not.
    static func lines(in source: String) -> [Int] {
        let original = source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        let code = SwiftCode(source).code
        let prose = original.indices.map { Self.prose(of: original[$0], code: $0 < code.count ? code[$0] : original[$0]) }
        var found: [Int] = []
        for index in prose.indices {
            let wraps = matches(wrappedRound, in: prose[index]) && index + 1 < prose.count
                && prose[index + 1].drop(while: { $0 == " " || $0 == "/" }).first?.isNumber == true
            if matches(round, in: prose[index]) || matches(hash, in: prose[index]) || wraps { found.append(index + 1) }
        }
        return found
    }

    /// The comment of a line, found as what `SwiftCode` blanks out of it, or the whole line of a `@Test` or `@Suite`.
    private static func prose(of line: String, code: String) -> String {
        let trimmed = line.drop { $0 == " " }
        if trimmed.hasPrefix("@Test(") || trimmed.hasPrefix("@Suite(") { return line }
        let original = Array(line.unicodeScalars), kept = Array(code.unicodeScalars)
        guard original.count == kept.count else { return "" }
        // A comment is blanked to spaces, so the spaces inside it match too: read from the first scalar that differs to the last,
        // and drop the code between them (a comment in the middle of a line).
        let changed = original.indices.filter { original[$0] != kept[$0] }
        guard let first = changed.first, let last = changed.last else { return "" }
        var comment = String.UnicodeScalarView()
        for index in first...last { comment.append(kept[index] == " " ? original[index] : " ") }
        return String(comment)
    }

    private static func matches(_ expression: NSRegularExpression, in text: String) -> Bool {
        expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}

/// The Swift sources of the repository name no round of work and no commit. `Prototypes/ADRValidation/` is left out: it is a
/// frozen record of the validation the ADRs cite (kind "excluded" in `Tools/ArchitectureCheck/rules.json`), and it is kept as it
/// was written.
@Suite("Code comments name no rounds of work")
struct WorkRoundReferencesTests {

    private static let excluded = "Prototypes/ADRValidation/"

    @Test("No tracked Swift source names a round of work or a commit in a comment or in a test name")
    func noSourceNamesARound() throws {
        let sources = try Repository.presentFiles().filter { $0.hasSuffix(".swift") && !$0.hasPrefix(Self.excluded) }
        #expect(sources.contains("PrestoCVCore/Sources/PrestoCVPersistence/FileCVRepository.swift"), "The tracked Swift sources do not include a known file: the list is wrong")
        for path in sources {
            for line in WorkRoundReferences.lines(in: try Repository.text(path)) {
                Issue.record("\(path):\(line) names a round of work or a commit: explain the code, not the round that produced it")
            }
        }
    }

    // MARK: Self-test

    private static func found(_ source: String) -> [Int] { WorkRoundReferences.lines(in: source) }

    @Test("A round of work or a commit in a comment, a MARK or a test name is found, each in its shape")
    func plantedPositives() {
        let planted = [
            "// The reader's classes (probe round 3).",
            "/// Typical duties (#354, round 7).",
            "/// Typical duties (review round 2).",
            "/// The bar (no-go round 3).",
            "/// What it accepted (rounds 3 and 7).",
            "/// A pass (round 4).",
            "/// Accepted at f16cdea1.",
            "// MARK: Round 16",
            "// MARK: - Probe round 13",
            "/// A finding of the review rounds.",
            #"@Test("The classes of round 3")"#,
            #"@Suite("Drafting evaluation: the reader's classes of round 3")"#,
            "let x = 1 // drafts of 5bcc19bf",
        ]
        for line in planted {
            #expect(Self.found("let a = 1\n" + line + "\n") == [2], "Not found: \(line)")
        }
    }

    @Test("A round of work whose number wraps to the next comment line is found, and a round trip that wraps is not")
    func plantedWrap() {
        #expect(Self.found("let a = 1\n/// the model wrote it back (#354, round\n/// 12). Only the job requests drop it.\n") == [2])
        #expect(Self.found("let a = 1\n/// a round\n/// trip through the encoder.\n") == [])
    }

    @Test("Round trip, rounded, round to 2 decimals, a hex number or colour, a UUID and a word are not found")
    func plantedNegatives() {
        let planted = [
            "// A round trip through the encoder.",
            "/// The value is rounded to the nearest cent.",
            "/// Round to 2 decimals.",
            "// The colour is #FF00AA.",
            "let colour = 0xFF00AA80",
            "let hash = \"f16cdea1\"",
            "let id = UUID(uuidString: \"E621E1F8-C36C-495A-93FC-0C247A3E6E5F\")",
            "let url = \"https://example.org/round 3\"",
            "// The word defaced has seven letters, all hexadecimal.",
            "// A number such as 1234567 has no letter.",
            "// The framework bug is Apple's FB16264926.",
            #"@Test("A round trip keeps the text")"#,
        ]
        for line in planted {
            #expect(Self.found("let a = 1\n" + line + "\n") == [], "Found by mistake: \(line)")
        }
    }
}

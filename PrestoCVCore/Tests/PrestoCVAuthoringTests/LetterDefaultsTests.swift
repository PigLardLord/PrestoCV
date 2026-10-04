import Testing
import Foundation
import PrestoCVDomain

private func defaults(salary: String = "", start: String = "", note: String = "") throws -> LetterDefaults {
    try LetterDefaults(salaryExpectation: salary, startDate: start, note: note)
}

@Suite("ADR 0019 · letter defaults")
struct LetterDefaultsTests {
    @Test("the three texts are the user's own words, trimmed, and an empty one is not set")
    func trimmed() throws {
        let value = try defaults(salary: "  55-60k gross \n", start: "from March", note: "")
        #expect(value.salaryExpectation == "55-60k gross" && value.startDate == "from March" && value.note.isEmpty)
        let blank = try defaults(salary: " \n ")
        #expect(!value.isEmpty && LetterDefaults.empty.isEmpty && blank.isEmpty)
    }

    @Test("each text is bounded in UTF-8 bytes, and the bound is the limit itself",
          arguments: LetterDefaults.Field.allCases)
    func bounded(field: LetterDefaults.Field) throws {
        let limit = LetterDefaults.maxBytes(of: field)
        func with(_ text: String) throws -> LetterDefaults {
            switch field {
            case .salaryExpectation: try defaults(salary: text)
            case .startDate: try defaults(start: text)
            case .note: try defaults(note: text)
            }
        }
        #expect(try with(String(repeating: "a", count: limit)).value(of: field).utf8.count == limit)
        #expect(throws: ApplicationError.tooLong(.letterDefault(field))) { _ = try with(String(repeating: "a", count: limit + 1)) }
        #expect(throws: ApplicationError.tooLong(.letterDefault(field))) { _ = try with(String(repeating: "é", count: limit / 2 + 1)) }
    }

    @Test("control characters and bidirectional overrides are refused; only the note may hold a line break",
          arguments: ["a\u{0000}b", "a\tb", "a\r\nb", "a\u{202E}b", "a\u{2066}b"])
    func forbidden(text: String) {
        #expect(throws: ApplicationError.forbiddenCharacters(.letterDefault(.salaryExpectation))) { _ = try defaults(salary: text) }
        #expect(throws: ApplicationError.forbiddenCharacters(.letterDefault(.startDate))) { _ = try defaults(start: text) }
    }

    @Test("the note may hold line breaks, and no other control character")
    func noteLines() throws {
        #expect(try defaults(note: "one\ntwo").note == "one\ntwo")
        #expect(throws: ApplicationError.forbiddenCharacters(.letterDefault(.note))) { _ = try defaults(note: "one\u{0007}two") }
        #expect(throws: ApplicationError.forbiddenCharacters(.letterDefault(.startDate))) { _ = try defaults(start: "one\ntwo") }
    }

    @Test("a field that the override sets wins, and the others stay the person's")
    func overrideWins() throws {
        let person = try defaults(salary: "55k", start: "April", note: "Remote only")
        let applied = person.applying(override: try defaults(salary: "60k", note: "Part time"))
        let expected = try defaults(salary: "60k", start: "April", note: "Part time")
        #expect(applied == expected)
    }

    @Test("an override sets a field and cannot clear one: an empty field leaves the person's text")
    func overrideCannotClear() throws {
        let person = try defaults(salary: "55k", start: "April", note: "Remote only")
        let blank = try defaults(start: "   ")
        #expect(person.applying(override: .empty) == person)
        #expect(person.applying(override: blank) == person)
    }

    @Test("with no defaults, the override is what the letter is held to; applying twice changes nothing more")
    func overrideOnNothing() throws {
        let override = try defaults(start: "May")
        #expect(LetterDefaults.empty.applying(override: override) == override)
        let person = try defaults(salary: "55k")
        #expect(person.applying(override: override).applying(override: override) == person.applying(override: override))
    }

    @Test("stored defaults carry the repository's revision and time, and an unsaved one has neither")
    func stored() throws {
        let value = try defaults(salary: "55k")
        let unsaved = StoredLetterDefaults.unsaved
        #expect(unsaved.defaults.isEmpty && unsaved.revision == 0 && unsaved.updatedAt == nil)
        let saved = StoredLetterDefaults(defaults: value, revision: 2, updatedAt: Date(timeIntervalSince1970: 10))
        #expect(saved.defaults == value && saved.revision == 2 && saved.updatedAt == Date(timeIntervalSince1970: 10))
    }
}

import Foundation

/// What a person wants every letter to say unless a tailoring says otherwise: the salary expectation, the start date and a
/// note, as the user's own text, bounded (ADR 0019). They belong to the person, not to a CV, and are not typed values: the
/// user writes them as they want them said. An empty text is a default that is not set.
///
/// A tailoring's override is a `LetterDefaults` too, and `applying(override:)` is the one rule that combines it with the
/// person's.
public struct LetterDefaults: Hashable, Sendable {
    public enum Field: String, Hashable, Sendable, CaseIterable { case salaryExpectation, startDate, note }

    public let salaryExpectation: String, startDate: String, note: String

    public init(salaryExpectation: String = "", startDate: String = "", note: String = "") throws(ApplicationError) {
        self.salaryExpectation = try Self.text(salaryExpectation, .salaryExpectation)
        self.startDate = try Self.text(startDate, .startDate)
        self.note = try Self.text(note, .note)
    }

    private init(validated salaryExpectation: String, _ startDate: String, _ note: String) {
        self.salaryExpectation = salaryExpectation; self.startDate = startDate; self.note = note
    }

    /// No default is set.
    public static let empty = LetterDefaults(validated: "", "", "")

    /// The most a field holds, in UTF-8 bytes.
    public static func maxBytes(of field: Field) -> Int {
        switch field {
        case .salaryExpectation: 200
        case .startDate: 100
        case .note: 2_000
        }
    }

    public func value(of field: Field) -> String {
        switch field {
        case .salaryExpectation: salaryExpectation
        case .startDate: startDate
        case .note: note
        }
    }

    public var isEmpty: Bool { Field.allCases.allSatisfy { value(of: $0).isEmpty } }

    /// A field that the override sets wins. An override sets a field and cannot clear one: a field it leaves empty keeps
    /// the person's text, and if a letter should not say what a default says, the person edits the letter afterwards.
    public func applying(override: LetterDefaults) -> LetterDefaults {
        func pick(_ field: Field) -> String { override.value(of: field).isEmpty ? value(of: field) : override.value(of: field) }
        return LetterDefaults(validated: pick(.salaryExpectation), pick(.startDate), pick(.note))
    }

    private static func text(_ raw: String, _ field: Field) throws(ApplicationError) -> String {
        try ApplicationTextRule.trimmed(raw, .letterDefault(field), maxBytes: maxBytes(of: field), multiline: field == .note)
    }
}

/// The person's letter defaults as a store holds them: what they say, the revision a save is conditional on, and when they
/// were last saved. Only a store assigns the revision and the time (R6, `package` access). Defaults never saved are
/// `unsaved`: empty, at revision 0.
public struct StoredLetterDefaults: Hashable, Sendable {
    public let defaults: LetterDefaults
    public let revision: Int
    public let updatedAt: Date?

    package init(defaults: LetterDefaults, revision: Int, updatedAt: Date?) {
        self.defaults = defaults; self.revision = revision; self.updatedAt = updatedAt
    }

    public static let unsaved = StoredLetterDefaults(defaults: .empty, revision: 0, updatedAt: nil)
}

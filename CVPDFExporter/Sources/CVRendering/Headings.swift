import Foundation
import CVDocumentModel

/// The words a document prints for its section titles, its open period end and the native language level, in the
/// document's language. `HeadingsCatalog` reads them from the package's translation tables.
public struct Headings: Sendable, Equatable {
    public var experience, education, skills, languages, certifications, profiles, interests, summary, present: String
    public var native: String

    /// The word printed for a language level: the translated "native" for `.native`, the level's code in capitals otherwise.
    public func levelName(_ level: LanguageItem.Level) -> String { level == .native ? native : level.rawValue.uppercased() }
}

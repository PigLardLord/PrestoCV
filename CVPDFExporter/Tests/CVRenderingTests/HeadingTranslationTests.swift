import Testing
import Foundation
@testable import CVRendering
import CVBundledHeadings

/// The six heading tables hold the terms a recruiter in each country expects on a CV (#81). `RenderingTests` checks that
/// each table has the ten keys; these tests check that each value is a real heading in its own language.
@Suite("the heading tables in six languages (#81)")
struct HeadingTranslationTests {
    static let languages = ["en", "it", "de", "es", "fr", "pt"]
    /// The one heading that is the same word in English and in another language of the set.
    static let sameAsEnglish: Set<String> = ["fr/certifications"]
    let catalog = HeadingsCatalog(source: BundleHeadingTableSource())

    func table(_ tag: String) throws -> [String: String] { try #require(try catalog.table(tag)) }

    @Test("the index lists the six languages and each has a table")
    func indexAndTables() throws {
        #expect(Set(try catalog.supportedLanguages()) == Set(Self.languages))
        for tag in Self.languages { _ = try table(tag) }
    }

    @Test("every heading has a value in every language, without surrounding white space", arguments: HeadingsCatalog.keys)
    func everyHeadingInEveryLanguage(key: String) throws {
        for tag in Self.languages {
            let value = try #require(try table(tag)[key], "\(tag) has no \(key)")
            #expect(!value.isEmpty && value == value.trimmingCharacters(in: .whitespacesAndNewlines), "\(tag)/\(key) is empty or padded")
        }
    }

    @Test("a table does not keep the English wording of a heading", arguments: HeadingsCatalog.keys)
    func translatedNotCopied(key: String) throws {
        let english = try #require(try table("en")[key])
        for tag in Self.languages where tag != "en" && !Self.sameAsEnglish.contains("\(tag)/\(key)") {
            #expect(try table(tag)[key] != english, "\(tag)/\(key) is still the English \(english)")
        }
    }

    @Test("no two headings of one language read the same", arguments: Self.languages)
    func headingsAreDistinct(tag: String) throws {
        let values = try table(tag).values
        #expect(Set(values).count == values.count, "\(tag) repeats a heading")
    }
}

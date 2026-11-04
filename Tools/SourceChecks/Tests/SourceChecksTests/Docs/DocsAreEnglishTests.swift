import Foundation
import Testing

// MARK: - Docs Are English Tests

/// The documents of the repository are in English, so that anybody can read them. The one exception is the store listing,
/// which holds the App Store texts in every language the app is sold in: its sections in a language other than English are
/// translations of the English ones, and they are left out of the check (the English sections of the listing are checked).
@Suite("The documents are in English")
struct DocsAreEnglishTests {

    private static let storeListing = "docs/release/store-listing.md"

    @Test("Every tracked Markdown file is in English, apart from the translated sections of the store listing")
    func everyMarkdownFileIsEnglish() throws {
        let documents = try Repository.trackedFiles().filter { $0.hasSuffix(".md") }
            .filter { FileManager.default.fileExists(atPath: Repository.root.appendingPathComponent($0).path) }
        #expect(documents.contains("README.md"), "The tracked Markdown files do not include README.md: the list is wrong")
        #expect(documents.contains(Self.storeListing), "The tracked Markdown files do not include \(Self.storeListing)")

        for path in documents {
            let markdown = try Repository.text(path)
            let checked = path == Self.storeListing ? EnglishText.withoutTranslatedSections(markdown) : markdown
            if let language = EnglishText.language(of: checked), language != .english {
                Issue.record(Comment(rawValue: "\(path) is written in \(language.rawValue), not in English"))
            }
        }
    }

    @Test("The translated sections of the store listing are what the exception leaves out")
    func listingTranslationsAreLeftOut() throws {
        let listing = try Repository.text(Self.storeListing)
        let kept = EnglishText.withoutTranslatedSections(listing)

        #expect(kept.count < listing.count, "\(Self.storeListing) has no translated section: the exception covers nothing")
        #expect(kept.contains("## English (U.S.), en-US"), "The English section of \(Self.storeListing) was left out")
        #expect(!kept.contains("## German, de-DE"), "The German section of \(Self.storeListing) was not left out")
    }
}

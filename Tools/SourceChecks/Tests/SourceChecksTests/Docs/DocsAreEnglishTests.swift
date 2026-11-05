import Foundation
import Testing

// MARK: - Docs Are English Tests

/// The documents of the repository are in English, so that anybody can read them. Each passage of a document is judged on its
/// own (`EnglishText`), so a document that is part English and part another language fails, and the failure names the passage.
/// The one exception is the store listing, which holds the App Store texts in every language the app is sold in: its sections
/// in a language other than English are translations of the English ones, and they are left out of the check (the English
/// sections of the listing are checked).
///
/// The documents are the files of the git index that are in the work tree (`Repository.presentFiles()`), as in every check that
/// reads the repository: an untracked document is not checked until it is added.
@Suite("The documents are in English")
struct DocsAreEnglishTests {

    private static let storeListing = "docs/release/store-listing.md"

    /// The least number of documents that must be judged English for the check to count: a parser that read nothing would judge
    /// none, and one that lost half of the documents would judge half. The repository has more than this, all of them English;
    /// the least is below that so that removing a few documents does not fail the check.
    private static let minimumJudgedEnglish = 40

    @Test("Every tracked Markdown file is in English, apart from the translated sections of the store listing")
    func everyMarkdownFileIsEnglish() throws {
        let documents = try Repository.presentFiles().filter(MarkdownText.isMarkdown)
        #expect(documents.contains("README.md"), "The tracked Markdown files do not include README.md: the list is wrong")
        #expect(documents.contains(Self.storeListing), "The tracked Markdown files do not include \(Self.storeListing)")

        var judgedEnglish = 0
        for path in documents {
            let markdown = try Repository.text(path)
            let checked = path == Self.storeListing ? EnglishText.withoutTranslatedSections(markdown) : markdown
            if let found = EnglishText.firstNotEnglish(in: checked) {
                Issue.record("\(path) has a passage that is not in English (\(found.verdict)): \(found.passage)")
            }
            switch EnglishText.language(of: checked) {
            case .english: judgedEnglish += 1
            case nil: break
            case let language?: Issue.record("\(path) is written in \(language.rawValue), not in English")
            }
        }

        #expect(judgedEnglish >= Self.minimumJudgedEnglish, "Only \(judgedEnglish) of \(documents.count) documents were judged English: the text parser reads too little")
    }

    @Test("The README is judged English, so that a parser that reads nothing cannot make the check pass")
    func readmeIsJudgedEnglish() throws {
        #expect(EnglishText.language(of: try Repository.text("README.md")) == .english)
    }

    @Test("The translated sections of the store listing are what the exception leaves out")
    func listingTranslationsAreLeftOut() throws {
        let listing = try Repository.text(Self.storeListing)
        let kept = EnglishText.withoutTranslatedSections(listing)

        #expect(kept != listing, "\(Self.storeListing) has no translated section: the exception covers nothing")
        #expect(kept.contains("## English (U.S.), en-US"), "The English section of \(Self.storeListing) was left out")
        #expect(!kept.contains("## German, de-DE"), "The German section of \(Self.storeListing) was not left out")
    }
}

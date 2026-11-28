import Foundation
import Testing
@testable import StoreListing

/// The listing and the retired words of this repository, and the edits the tests make to a copy of them.
enum StoreListingFixture {
    static let document = "docs/release/store-listing.md"
    static let retiredWords = "Tools/Release/store-listing-retired-words.json"
    static let locale = "en-US"

    static func listing() throws -> Listing {
        StoreListingRules.parse(try Repository.text(document).components(separatedBy: "\n"))
    }

    static func retired() throws -> RetiredWords {
        try RetiredWords.load(from: Data(contentsOf: Repository.root.appendingPathComponent(retiredWords)))
    }

    /// The real listing with the captions of one locale replaced.
    static func listing(withCaptions captions: [String], in code: String = locale) throws -> Listing {
        var listing = try listing()
        var texts = try #require(listing[code])
        texts.fields["Screenshot captions"] = [captions.joined(separator: "\n")]
        listing[code] = texts
        return listing
    }

    static func captionErrors(_ captions: [String]) throws -> [String] {
        try StoreListingRules.check(listing(withCaptions: captions), retired: retired())
            .filter { $0.lowercased().contains("caption") }
    }

    /// The retired-word errors that `text` adds to the field of a locale of the real listing, with no pending locale.
    static func retiredErrors(_ code: String, _ field: String, _ text: String) throws -> [String] {
        var retired = try retired()
        retired.pendingLocales = []
        var listing = try listing()
        let before = StoreListingRules.checkRetired(listing, retired: retired)
        var texts = try #require(listing[code], "the listing has no locale \(code)")
        texts.fields[field] = [(texts.fields[field]?.first ?? "") + "\n" + text]
        listing[code] = texts
        var added = StoreListingRules.checkRetired(listing, retired: retired)
        for error in before { if let index = added.firstIndex(of: error) { added.remove(at: index) } }
        return added
    }
}

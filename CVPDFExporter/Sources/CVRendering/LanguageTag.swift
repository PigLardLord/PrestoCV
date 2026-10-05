import Foundation
import CVDesignCatalog

/// The one rule for what a document's language may look like: the shape of a BCP 47 tag, so it can reach an
/// attribute or name a heading table without carrying anything else.
enum LanguageTag {
    static func isWellFormed(_ raw: String) -> Bool {
        raw.fullyMatches(#"[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8}){0,3}"#)
    }

    /// The tag as the page prints it: `raw` when it is well formed, and "und" (undetermined) otherwise.
    static func printable(_ raw: String) -> String {
        isWellFormed(raw) ? raw : "und"
    }
}

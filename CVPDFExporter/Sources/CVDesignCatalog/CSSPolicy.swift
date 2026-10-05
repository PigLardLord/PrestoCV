import Foundation

/// Design CSS is parsed into tokens, checked against an allow-list and re-serialised from the tokens
/// (ADR 0011, ValidatingBoundary). What is validated is exactly what is emitted: comments, strings and anything the
/// allow-list does not name cannot reach the document.
enum CSSPolicy {
    /// Returns the canonical re-serialisation of an allowed stylesheet, or the first reason to reject it.
    static func canonical(_ css: String) throws(CSSRejection) -> String {
        try CSSParser.canonical(try CSSTokenizer.tokenize(css))
    }
}

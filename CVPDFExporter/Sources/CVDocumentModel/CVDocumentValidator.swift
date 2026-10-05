import Foundation

/// Anti-corruption layer for documents arriving from outside (a backend request, a file). ValidatingBoundary.
public enum CVDocumentValidator {
    /// Why a document was refused, in words meant for the sender.
    public struct Invalid: Error, Equatable, Sendable { public let reason: String }

    /// The largest JSON document `decode` accepts, checked before decoding.
    public static let maxJSONBytes = 1_048_576

    /// The entry point for a document that arrives as JSON (a backend request, a file): the size is checked before
    /// decoding, and the decoded document is validated.
    public static func decode(json: Data) throws(Invalid) -> CVDocument {
        guard json.count <= maxJSONBytes else { throw Invalid(reason: "document is too large") }
        let document: CVDocument
        do { document = try JSONDecoder().decode(CVDocument.self, from: json) } catch { throw Invalid(reason: "not a CV document") }
        try validate(document)
        return document
    }

    /// Checks a document that was built in code rather than decoded: the person has a name, every text is within its
    /// bound and free of control characters, counts are bounded, and dates, periods and ratings are valid.
    ///
    /// - Throws: `Invalid` for the first problem found.
    public static func validate(_ document: CVDocument) throws(Invalid) {
        var content = DocumentContentCheck()
        try content.check(document)
    }
}

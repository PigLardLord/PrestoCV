import Foundation
import CVDocumentModel

/// What the exporter says about a JSON document: its single entry point for documents from outside.
enum Exporter {
    enum Verdict: Equatable {
        case accepted
        case refused(reason: String)
    }

    /// The reason the validator gives when a period ends before it starts.
    static let periodOrder = "end before start"

    static func verdict(for json: String) -> Verdict {
        do {
            _ = try CVDocumentValidator.decode(json: Data(json.utf8))
            return .accepted
        } catch {
            return .refused(reason: error.reason)
        }
    }

    /// The reason the validator gives when a text is too long in bytes, the document's text is too large, or a text has
    /// control characters.
    static func isTextRule(_ reason: String) -> Bool { reason.contains("too long") }
}

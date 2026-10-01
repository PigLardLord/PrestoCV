import Foundation
import CVDocumentModel

/// What the exporter says about a JSON document: its single entry point for documents from outside.
enum Exporter {
    enum Verdict: Equatable {
        case accepted
        case refused(reason: String)
    }

    /// The rules of the validator that JSON Schema cannot express, as its reasons name them. A reason that names none of
    /// them is a refusal by the decoder or by a rule the schema does express.
    enum Rule: Equatable, Sendable {
        case blankName, periodOrder, textRules, documentSize
    }

    static func rule(of reason: String) -> Rule? {
        switch reason {
        case "name is required": .blankName
        case "end before start": .periodOrder
        case "document is too large": .documentSize
        default: reason.contains("too long") ? .textRules : nil
        }
    }

    static func verdict(for json: String) -> Verdict {
        do {
            _ = try CVDocumentValidator.decode(json: Data(json.utf8))
            return .accepted
        } catch {
            return .refused(reason: error.reason)
        }
    }
}

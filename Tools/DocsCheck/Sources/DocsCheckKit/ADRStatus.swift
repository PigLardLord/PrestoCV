import Foundation

/// The status of an architecture decision record, as the ADR README defines it: Proposed, Accepted, Rejected, or
/// Superseded by a link to the ADR that replaces it.
enum ADRStatus: Equatable {
    case proposed
    case accepted
    case rejected
    /// `link` is the path of the replacement as written, nil when the text names no link into the repository.
    case supersededBy(link: String?)

    private static let supersededPrefix = "Superseded by "

    /// Nil if the text is not a status.
    init?(text: String) {
        let text = text.trimmingCharacters(in: .whitespaces)
        switch text {
        case "Proposed": self = .proposed
        case "Accepted": self = .accepted
        case "Rejected": self = .rejected
        default:
            guard text.hasPrefix(Self.supersededPrefix) else { return nil }
            let rest = String(text.dropFirst(Self.supersededPrefix.count))
            self = .supersededBy(link: MarkdownDocument(text: rest).links.first.flatMap { LinkTarget(destination: $0.destination)?.path })
        }
    }

    /// The number in the file name of the replacement: `0013` for `docs/0013-title.md`. Nil if the link is not to an ADR file.
    var successorNumber: String? {
        guard case .supersededBy(let link?) = self, let name = link.split(separator: "/").last.map(String.init) else { return nil }
        return Self.number(ofADRFileNamed: name)
    }

    /// What the status says, so two statuses can be compared whatever the spelling of their links.
    var summary: String {
        switch self {
        case .proposed: return "Proposed"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        case .supersededBy: return "Superseded by " + (successorNumber ?? "an unknown ADR")
        }
    }

    /// The number of a file named `NNNN-title.md`, nil for any other name.
    static func number(ofADRFileNamed name: String) -> String? {
        let number = name.prefix(4)
        guard number.count == 4, number.allSatisfy({ $0.isASCII && $0.isNumber }), name.dropFirst(4).hasPrefix("-"),
              name.hasSuffix(".md"), name.count > "NNNN-.md".count else { return nil }
        return String(number)
    }
}

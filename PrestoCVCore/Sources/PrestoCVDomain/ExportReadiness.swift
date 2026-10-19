import Foundation

/// Whether a CV can be exported, and what to fix or to add first. Only the person's name is required: a PDF without
/// it does not say whose CV it is. Without an e-mail address or a phone number the CV is still exported, with a
/// warning, since a recruiter would have no way to answer. White space is not a value.
public struct ExportReadiness: Hashable, Sendable {
    public enum Field: Hashable, Sendable {
        case name, email, phone
    }

    /// The fields an export needs
    public static let requiredFields: Set<Field> = [.name]

    /// The fields to fill in before the CV is exported, in the order of the form
    public let blockers: [Field]
    /// The fields worth filling in, without which the CV is still exported, in the order of the form
    public let warnings: [Field]

    public var canExport: Bool { blockers.isEmpty }

    public init(name: String, email: String, phone: String) {
        let missing = [(Field.name, name), (.email, email), (.phone, phone)]
            .filter { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.0)
        blockers = missing.filter(Self.requiredFields.contains)
        warnings = missing.filter { !Self.requiredFields.contains($0) }
    }
}

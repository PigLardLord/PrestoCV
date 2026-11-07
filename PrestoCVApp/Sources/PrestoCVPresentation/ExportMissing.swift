internal import PrestoCVDomain

/// What the CV lacks for an export, as codes the view words (R13), by the domain's `ExportReadiness` (R6): a blocker
/// stops the export, a warning does not.
public struct ExportMissing: Hashable, Sendable {
    public enum Field: Hashable, Sendable {
        case name, email, phone
    }

    /// The fields to fill in before the CV is exported, in the order of the form.
    public let blockers: [Field]
    /// The fields worth filling in, without which the CV is still exported, in the order of the form.
    public let warnings: [Field]

    /// Before the sheet has read the CV.
    static let unknown = ExportMissing(blockers: [], warnings: [])

    private init(blockers: [Field], warnings: [Field]) {
        self.blockers = blockers
        self.warnings = warnings
    }

    init(_ readiness: ExportReadiness) {
        self.init(blockers: readiness.blockers.map(Field.init), warnings: readiness.warnings.map(Field.init))
    }

    /// What `cv` lacks, by the domain's rule.
    init(_ cv: CV) {
        self.init(ExportReadiness(name: cv.personal.fullName, email: cv.personal.email?.value ?? "",
                                  phone: cv.personal.phone?.value ?? ""))
    }
}

extension ExportMissing.Field {
    init(_ field: ExportReadiness.Field) {
        switch field {
        case .name: self = .name
        case .email: self = .email
        case .phone: self = .phone
        }
    }
}

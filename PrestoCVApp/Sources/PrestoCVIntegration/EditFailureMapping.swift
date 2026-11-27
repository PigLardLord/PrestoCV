import PrestoCVApplication
import PrestoCVWorkflowPorts

extension EditFailure {
    /// Every error of a use case has its failure; the switch is exhaustive so a new error cannot be forgotten (R7).
    init(_ error: AuthoringError) {
        switch error {
        case .notEnoughContent: self = .notEnoughContent
        case .conflict(let revision): self = .conflict(storedRevision: revision)
        case .deletedElsewhere: self = .deletedElsewhere
        case .tooLarge: self = .tooLarge
        case .unavailable: self = .unavailable
        case .textTooLong(let field): self = .textTooLong(field)
        case .tooManyEntries(let section): self = .tooManyEntries(section)
        case .cvTooLarge: self = .cvTooLarge
        }
    }
}

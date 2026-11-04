import PrestoCVCore
import enum PrestoCVDomain.FieldCheck
import struct PrestoCVDomain.ExportReadiness

/// Each contact field is checked by the rules of PrestoCVDomain when the person leaves it, not at every key: what it said
/// then is what its status tells, until they leave it again.
extension CVEditorViewModel {

    /// The person's name: required, since a PDF is made only with it (`ExportReadiness`).
    var nameStatus: FieldStatus {
        FieldStatus(validity: .none, isRequired: ExportReadiness.requiredFields.contains(.name), note: .required)
    }

    /// The e-mail address: a PDF is made without one, with a warning, so the field is optional. It is checked once it
    /// is left.
    var emailStatus: FieldStatus {
        switch FieldCheck.email(leftContactText[.email] ?? "") {
        case .empty:
            return FieldStatus(validity: .none, isRequired: false, note: nil)
        case .plausible:
            return FieldStatus(validity: .valid, isRequired: false, note: nil)
        case .implausible:
            return FieldStatus(validity: .invalid, isRequired: false, note: .invalidEmail)
        }
    }

    /// The phone number: a warning when it has no digit, which does not stop the CV from being saved. How the number
    /// is written is up to the person.
    var phoneStatus: FieldStatus {
        switch FieldCheck.phoneNumber(leftContactText[.phone] ?? "") {
        case .empty, .plausible:
            return FieldStatus(validity: .none, isRequired: false, note: .phoneHelp)
        case .implausible:
            return FieldStatus(validity: .warning, isRequired: false, note: .phoneWithoutDigits)
        }
    }

    /// The portfolio: a web address, doubtful without http or https and a host.
    var portfolioStatus: FieldStatus {
        switch FieldCheck.webAddress(leftContactText[.portfolio] ?? "") {
        case .empty:
            return FieldStatus(validity: .none, isRequired: false, note: .webAddressHelp)
        case .plausible:
            return FieldStatus(validity: .valid, isRequired: false, note: .webAddressHelp)
        case .implausible:
            return FieldStatus(validity: .warning, isRequired: false, note: .webAddressHelp)
        }
    }
}

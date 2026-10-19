import PrestoCVCore

extension CVEditorViewModel {

    /// The e-mail address: required, since a PDF is made only with one, and checked once something is typed.
    var emailStatus: FieldStatus {
        switch FieldCheck.email(cv.personalInfo.email) {
        case .empty:
            return FieldStatus(validity: .none, isRequired: true, note: .required)
        case .plausible:
            return FieldStatus(validity: .valid, isRequired: true, note: .required)
        case .implausible:
            return FieldStatus(validity: .invalid, isRequired: true, note: .invalidEmail)
        }
    }

    /// The phone number: a warning when it has no digit, which does not stop the CV from being saved. How the number
    /// is written is up to the person.
    var phoneStatus: FieldStatus {
        switch FieldCheck.phoneNumber(cv.personalInfo.phone) {
        case .empty, .plausible:
            return FieldStatus(validity: .none, isRequired: false, note: .phoneHelp)
        case .implausible:
            return FieldStatus(validity: .warning, isRequired: false, note: .phoneWithoutDigits)
        }
    }

    /// The portfolio: a web address, doubtful without http.
    var portfolioStatus: FieldStatus {
        switch FieldCheck.webAddress(cv.personalInfo.portfolio) {
        case .empty:
            return FieldStatus(validity: .none, isRequired: false, note: .webAddressHelp)
        case .plausible:
            return FieldStatus(validity: .valid, isRequired: false, note: .webAddressHelp)
        case .implausible:
            return FieldStatus(validity: .warning, isRequired: false, note: .webAddressHelp)
        }
    }
}

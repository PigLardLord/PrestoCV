import SwiftUI

extension FieldStatus {
    /// What a labeled field shows for this status, with its line in the language of the app: in the colour of an error
    /// while the text is invalid, as help otherwise.
    var fieldState: FieldState {
        validity == .invalid
            ? FieldState(validation: validationState, isRequired: isRequired, errorMessage: noteText)
            : FieldState(validation: validationState, isRequired: isRequired, helpText: noteText)
    }

    private var validationState: FieldLabel.ValidationState {
        switch validity {
        case .none: return .none
        case .valid: return .valid
        case .invalid: return .invalid
        case .warning: return .warning
        }
    }

    private var noteText: String {
        switch note {
        case .required: return "field.help.required".localized
        case .invalidEmail: return "field.email.error_invalid".localized
        case .phoneHelp: return "field.phone.help".localized
        case .phoneWithoutDigits: return "field.phone.no_digits".localized
        case .webAddressHelp: return "field.url.help".localized
        }
    }
}

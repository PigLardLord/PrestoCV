import PrestoCVPresentation
import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    /// Fits a text field to the kind of text it asks for: on iOS the keyboard, the content type that AutoFill reads, the
    /// capitals and the corrections. A Mac has no on-screen keyboard and its AutoFill reads no such types, so there only
    /// the corrections change.
    func fieldInput(_ input: FieldInput) -> some View {
        #if os(iOS)
        keyboardType(input.keyboard)
            .textContentType(input.contentType)
            .textInputAutocapitalization(input.capitals)
            .autocorrectionDisabled(!input.isCorrected)
        #else
        autocorrectionDisabled(!input.isCorrected)
        #endif
    }
}

private extension FieldInput {
    /// Whether the system may correct what the person types: only in prose. A name, an address or a number is written as
    /// it is.
    var isCorrected: Bool {
        switch self {
        case .jobTitle, .sentence, .paragraph: true
        case .personName, .organization, .city, .email, .phone, .webAddress, .year, .plain: false
        }
    }
}

#if os(iOS)
private extension FieldInput {
    var keyboard: UIKeyboardType {
        switch self {
        case .email: .emailAddress
        case .phone: .phonePad
        case .webAddress: .URL
        case .year: .numberPad
        case .personName, .jobTitle, .organization, .city, .plain, .sentence, .paragraph: .default
        }
    }

    var contentType: UITextContentType? {
        switch self {
        case .personName: .name
        case .jobTitle: .jobTitle
        case .organization: .organizationName
        case .city: .addressCity
        case .email: .emailAddress
        case .phone: .telephoneNumber
        case .webAddress: .URL
        case .year, .plain, .sentence, .paragraph: nil
        }
    }

    var capitals: TextInputAutocapitalization {
        switch self {
        case .personName, .jobTitle, .organization, .city: .words
        case .sentence, .paragraph: .sentences
        case .email, .phone, .webAddress, .year, .plain: .never
        }
    }
}
#endif

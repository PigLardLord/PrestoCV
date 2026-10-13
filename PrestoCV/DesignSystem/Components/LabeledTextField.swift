import SwiftUI

/// A reusable text field component with a label above it
/// Follows the design system tokens for consistent styling
struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var isSecure: Bool = false
    var isRequired: Bool = false
    var validationState: ValidationState = .none
    var errorMessage: String? = nil
    var helpText: String? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil
    var onCommit: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    
    typealias ValidationState = FieldLabel.ValidationState
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            FieldLabel.conditional(
                text: label,
                isRequired: isRequired,
                validationState: validationState,
                isFocused: isFocused
            )
            
            FieldInput(
                text: $text,
                placeholder: placeholder,
                isSecure: isSecure,
                keyboardType: keyboardType,
                textContentType: textContentType,
                validationState: validationState,
                isFocused: $isFocused,
                onEditingChanged: onEditingChanged,
                onCommit: onCommit
            )
            
            FieldMessage.conditional(
                validationState: validationState,
                errorMessage: errorMessage,
                helpText: helpText
            )
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - Convenience Initializers
extension LabeledTextField {
    static func email(
        label: String = "field.email".localized,
        text: Binding<String>,
        placeholder: String = "field.email.placeholder".localized,
        isRequired: Bool = false,
        onCommit: (() -> Void)? = nil
    ) -> LabeledTextField {
        let validationState: ValidationState = {
            let email = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if email.isEmpty { return .none }
            return email.contains("@") && email.contains(".") ? .valid : .invalid
        }()
        
        return LabeledTextField(
            label: label,
            text: text,
            placeholder: placeholder,
            keyboardType: .emailAddress,
            textContentType: .emailAddress,
            isRequired: isRequired,
            validationState: validationState,
            errorMessage: validationState == .invalid ? "field.email.error_invalid".localized : nil,
            helpText: isRequired ? "field.help.required".localized : "field.email.help".localized,
            onCommit: onCommit
        )
    }
    
    static func phone(
        label: String = "field.phone".localized,
        text: Binding<String>,
        placeholder: String = "field.phone.placeholder".localized,
        isRequired: Bool = false,
        onCommit: (() -> Void)? = nil
    ) -> LabeledTextField {
        LabeledTextField(
            label: label,
            text: text,
            placeholder: placeholder,
            keyboardType: .phonePad,
            textContentType: .telephoneNumber,
            isRequired: isRequired,
            helpText: "field.phone.help".localized,
            onCommit: onCommit
        )
    }
    
    static func url(
        label: String = "field.url".localized,
        text: Binding<String>,
        placeholder: String = "https://example.com",
        helpText: String? = "field.url.help".localized,
        onCommit: (() -> Void)? = nil
    ) -> LabeledTextField {
        let validationState: ValidationState = {
            let url = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if url.isEmpty { return .none }
            return url.lowercased().hasPrefix("http") ? .valid : .warning
        }()
        
        return LabeledTextField(
            label: label,
            text: text,
            placeholder: placeholder,
            keyboardType: .URL,
            textContentType: .URL,
            validationState: validationState,
            helpText: helpText,
            onCommit: onCommit
        )
    }
}

struct LabeledTextField_Previews: PreviewProvider {
    @State static var text = "Sample text"
    @State static var email = ""
    @State static var phone = ""
    @State static var url = ""
    
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            LabeledTextField(label: "Label", text: $text, placeholder: "Enter text")
            
            LabeledTextField.email(text: $email) {
                print("Email submitted")
            }
            
            LabeledTextField.phone(text: $phone)
            
            LabeledTextField.url(text: $url)
            
            // Without label
            LabeledTextField(label: "", text: $text, placeholder: "No label field")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
import SwiftUI

/// What a labeled field shows beside its text: whether the text is valid, whether the field must be filled in, and the
/// line under it. Whoever owns the field decides it; the field only shows it.
struct FieldState: Equatable {
    var validation: FieldLabel.ValidationState = .none
    var isRequired = false
    /// Shown under the field while the text is invalid
    var errorMessage: String? = nil
    /// Shown under the field otherwise
    var helpText: String? = nil
}

/// A reusable text field component with a label above it
/// Follows the design system tokens for consistent styling
struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var isSecure: Bool = false
    var state = FieldState()
    var onCommit: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            FieldLabel.conditional(
                text: label,
                isRequired: state.isRequired,
                validationState: state.validation,
                isFocused: isFocused
            )
            
            FieldInput(
                text: $text,
                accessibilityLabel: label,
                placeholder: placeholder,
                isSecure: isSecure,
                keyboardType: keyboardType,
                textContentType: textContentType,
                validationState: state.validation,
                isFocused: $isFocused,
                onCommit: onCommit
            )
            
            FieldMessage.conditional(
                validationState: state.validation,
                errorMessage: state.errorMessage,
                helpText: state.helpText
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
        state: FieldState,
        onCommit: (() -> Void)? = nil
    ) -> LabeledTextField {
        LabeledTextField(
            label: label,
            text: text,
            placeholder: placeholder,
            keyboardType: .emailAddress,
            textContentType: .emailAddress,
            state: state,
            onCommit: onCommit
        )
    }
    
    static func phone(
        label: String = "field.phone".localized,
        text: Binding<String>,
        placeholder: String = "field.phone.placeholder".localized,
        state: FieldState,
        onCommit: (() -> Void)? = nil
    ) -> LabeledTextField {
        LabeledTextField(
            label: label,
            text: text,
            placeholder: placeholder,
            keyboardType: .phonePad,
            textContentType: .telephoneNumber,
            state: state,
            onCommit: onCommit
        )
    }
    
    static func url(
        label: String = "field.url".localized,
        text: Binding<String>,
        placeholder: String = "https://example.com",
        state: FieldState,
        onCommit: (() -> Void)? = nil
    ) -> LabeledTextField {
        LabeledTextField(
            label: label,
            text: text,
            placeholder: placeholder,
            keyboardType: .URL,
            textContentType: .URL,
            state: state,
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
            
            LabeledTextField.email(text: $email, state: FieldState(isRequired: true, helpText: "field.help.required".localized)) {
                print("Email submitted")
            }
            
            LabeledTextField.phone(text: $phone, state: FieldState(validation: .warning, helpText: "field.phone.no_digits".localized))
            
            LabeledTextField.url(text: $url, state: FieldState(validation: .valid, helpText: "field.url.help".localized))
            
            // Without label
            LabeledTextField(label: "", text: $text, placeholder: "No label field")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
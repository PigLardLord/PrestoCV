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
    var onEditingChanged: ((Bool) -> Void)? = nil
    var onCommit: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            if !label.isEmpty {
                Text(label)
                    .font(DesignTokens.Typography.footnote.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(DesignTokens.Colors.backgroundTertiary)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .onSubmit {
                        onCommit?()
                    }
            } else {
                TextField(placeholder, text: $text)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(DesignTokens.Colors.backgroundTertiary)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .onSubmit {
                        onCommit?()
                    }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - Convenience Initializers
extension LabeledTextField {
    static func email(
        label: String = "Email",
        text: Binding<String>,
        placeholder: String = "Enter your email",
        onCommit: (() -> Void)? = nil
    ) -> LabeledTextField {
        LabeledTextField(
            label: label,
            text: text,
            placeholder: placeholder,
            keyboardType: .emailAddress,
            textContentType: .emailAddress,
            onCommit: onCommit
        )
    }
    
    static func password(
        label: String = "Password",
        text: Binding<String>,
        placeholder: String = "Enter your password",
        onCommit: (() -> Void)? = nil
    ) -> LabeledTextField {
        LabeledTextField(
            label: label,
            text: text,
            placeholder: placeholder,
            isSecure: true,
            onCommit: onCommit
        )
    }
    
    static func phone(
        label: String = "Phone",
        text: Binding<String>,
        placeholder: String = "Enter your phone number",
        onCommit: (() -> Void)? = nil
    ) -> LabeledTextField {
        LabeledTextField(
            label: label,
            text: text,
            placeholder: placeholder,
            keyboardType: .phonePad,
            textContentType: .telephoneNumber,
            onCommit: onCommit
        )
    }
    
    static func url(
        label: String = "URL",
        text: Binding<String>,
        placeholder: String = "Enter URL",
        onCommit: (() -> Void)? = nil
    ) -> LabeledTextField {
        LabeledTextField(
            label: label,
            text: text,
            placeholder: placeholder,
            keyboardType: .URL,
            textContentType: .URL,
            onCommit: onCommit
        )
    }
}

struct LabeledTextField_Previews: PreviewProvider {
    @State static var text = "Sample text"
    @State static var email = ""
    @State static var password = ""
    @State static var phone = ""
    @State static var url = ""
    
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            LabeledTextField(label: "Label", text: $text, placeholder: "Enter text")
            
            LabeledTextField.email(text: $email) {
                print("Email submitted")
            }
            
            LabeledTextField.password(text: $password) {
                print("Password submitted")
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
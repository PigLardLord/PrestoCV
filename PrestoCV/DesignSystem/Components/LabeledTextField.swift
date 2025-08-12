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
    
    enum ValidationState {
        case none
        case valid
        case invalid
        case warning
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            if !label.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Text(label)
                        .font(DesignTokens.Typography.footnote.font)
                        .foregroundColor(labelColor)
                    
                    if isRequired {
                        Text("*")
                            .font(DesignTokens.Typography.footnote.font)
                            .foregroundColor(DesignTokens.Colors.error)
                    }
                    
                    Spacer()
                    
                    // Validation icon
                    if validationState != .none {
                        Image(systemName: validationIcon)
                            .font(DesignTokens.Typography.caption1.font)
                            .foregroundColor(validationColor)
                    }
                }
            }
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text, onEditingChanged: { editing in
                        isFocused = editing
                        onEditingChanged?(editing)
                    })
                    .focused($isFocused)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(backgroundColor)
            .cornerRadius(DesignTokens.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .stroke(borderColor, lineWidth: borderWidth)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            )
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .onSubmit {
                onCommit?()
            }
            
            // Help text or error message
            if let errorMessage = errorMessage, validationState == .invalid {
                Text(errorMessage)
                    .font(DesignTokens.Typography.caption1.font)
                    .foregroundColor(DesignTokens.Colors.error)
                    .padding(.top, DesignTokens.Spacing.xxxs)
            } else if let helpText = helpText {
                Text(helpText)
                    .font(DesignTokens.Typography.caption1.font)
                    .foregroundColor(DesignTokens.Colors.tertiary)
                    .padding(.top, DesignTokens.Spacing.xxxs)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
    
    // MARK: - Computed Properties
    
    private var labelColor: Color {
        switch validationState {
        case .invalid:
            return DesignTokens.Colors.error
        case .valid:
            return DesignTokens.Colors.success
        case .warning:
            return DesignTokens.Colors.warning
        case .none:
            return isFocused ? DesignTokens.Colors.accent : DesignTokens.Colors.secondary
        }
    }
    
    private var borderColor: Color {
        switch validationState {
        case .invalid:
            return DesignTokens.Colors.error
        case .valid:
            return DesignTokens.Colors.success
        case .warning:
            return DesignTokens.Colors.warning
        case .none:
            return isFocused ? DesignTokens.Colors.accent : DesignTokens.Colors.border
        }
    }
    
    private var borderWidth: CGFloat {
        isFocused || validationState != .none ? 1.5 : 1
    }
    
    private var backgroundColor: Color {
        isFocused ? DesignTokens.Colors.background : DesignTokens.Colors.backgroundTertiary
    }
    
    private var validationIcon: String {
        switch validationState {
        case .valid:
            return "checkmark.circle.fill"
        case .invalid:
            return "exclamationmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .none:
            return ""
        }
    }
    
    private var validationColor: Color {
        switch validationState {
        case .valid:
            return DesignTokens.Colors.success
        case .invalid:
            return DesignTokens.Colors.error
        case .warning:
            return DesignTokens.Colors.warning
        case .none:
            return DesignTokens.Colors.tertiary
        }
    }
}

// MARK: - Convenience Initializers
extension LabeledTextField {
    static func email(
        label: String = "Email",
        text: Binding<String>,
        placeholder: String = "Enter your email",
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
            errorMessage: validationState == .invalid ? "Please enter a valid email address" : nil,
            helpText: isRequired ? "Required field" : "We'll use this for professional contact",
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
            helpText: "Include country code for international contacts",
            onCommit: onCommit
        )
    }
    
    static func url(
        label: String = "URL",
        text: Binding<String>,
        placeholder: String = "https://example.com",
        helpText: String? = "Include https:// for web links",
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
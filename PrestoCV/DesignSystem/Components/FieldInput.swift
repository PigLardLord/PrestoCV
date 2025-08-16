import SwiftUI

/// A reusable input component that handles both secure and regular text fields with styling
struct FieldInput: View {
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let validationState: FieldLabel.ValidationState
    @FocusState.Binding var isFocused: Bool
    let onEditingChanged: ((Bool) -> Void)?
    let onCommit: (() -> Void)?
    
    init(
        text: Binding<String>,
        placeholder: String = "",
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        validationState: FieldLabel.ValidationState = .none,
        isFocused: FocusState<Bool>.Binding,
        onEditingChanged: ((Bool) -> Void)? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.validationState = validationState
        self._isFocused = isFocused
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }
    
    var body: some View {
        InputField(
            text: $text,
            placeholder: placeholder,
            isSecure: isSecure,
            isFocused: $isFocused,
            onEditingChanged: onEditingChanged
        )
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(backgroundColor)
        .cornerRadius(DesignTokens.CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                .stroke(borderColor, lineWidth: borderWidth)
                .animation(DesignTokens.Animations.fastEaseInOut, value: isFocused)
        )
        .keyboardType(keyboardType)
        .textContentType(textContentType)
        .onSubmit {
            onCommit?()
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
        isFocused || validationState != .none ? DesignTokens.BorderWidth.medium : DesignTokens.BorderWidth.thin
    }
    
    private var backgroundColor: Color {
        isFocused ? DesignTokens.Colors.background : DesignTokens.Colors.backgroundTertiary
    }
}

/// Internal component that handles the actual text field rendering
private struct InputField: View {
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    @FocusState.Binding var isFocused: Bool
    let onEditingChanged: ((Bool) -> Void)?
    
    var body: some View {
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
}
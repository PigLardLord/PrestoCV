import SwiftUI

/// A reusable input component that handles both secure and regular text fields with styling.
///
/// The focus has one source of truth: the `FocusState` that the caller owns and `.focused` binds to the field.
/// Nothing in the field writes it back from an editing callback; on iOS 27 two writers took the focus from each
/// other in a loop, and the app ran at 100% CPU as soon as a second field was tapped.
struct FieldInput: View {
    @Binding var text: String
    let accessibilityLabel: String
    let placeholder: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let validationState: FieldLabel.ValidationState
    @FocusState.Binding var isFocused: Bool
    let onCommit: (() -> Void)?
    
    init(
        text: Binding<String>,
        accessibilityLabel: String = "",
        placeholder: String = "",
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        validationState: FieldLabel.ValidationState = .none,
        isFocused: FocusState<Bool>.Binding,
        onCommit: (() -> Void)? = nil
    ) {
        self._text = text
        self.accessibilityLabel = accessibilityLabel
        self.placeholder = placeholder
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.validationState = validationState
        self._isFocused = isFocused
        self.onCommit = onCommit
    }
    
    var body: some View {
        InputField(
            text: $text,
            accessibilityLabel: accessibilityLabel,
            placeholder: placeholder,
            isSecure: isSecure,
            isFocused: $isFocused,
            onCommit: onCommit
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
    let accessibilityLabel: String
    let placeholder: String
    let isSecure: Bool
    @FocusState.Binding var isFocused: Bool
    let onCommit: (() -> Void)?
    
    private var label: String {
        accessibilityLabel.isEmpty ? placeholder : accessibilityLabel
    }
    
    var body: some View {
        field
            .focused($isFocused)
            .accessibilityLabel(label)
    }
    
    @ViewBuilder
    private var field: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
                .onSubmit { onCommit?() }
        } else {
            GrowingTextField(placeholder, text: $text, accessibilityLabel: label, onReturn: onCommit)
        }
    }
}

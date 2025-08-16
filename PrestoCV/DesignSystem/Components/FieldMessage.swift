import SwiftUI

/// A reusable component for displaying field messages (help text or error messages)
struct FieldMessage: View {
    let validationState: FieldLabel.ValidationState
    let errorMessage: String?
    let helpText: String?
    
    var body: some View {
        MessageContent(
            validationState: validationState,
            errorMessage: errorMessage,
            helpText: helpText
        )
    }
}

/// Internal component that handles message content rendering logic
private struct MessageContent: View {
    let validationState: FieldLabel.ValidationState
    let errorMessage: String?
    let helpText: String?
    
    var body: some View {
        if let errorMessage = errorMessage, validationState == .invalid {
            ErrorMessage(text: errorMessage)
        } else if let helpText = helpText {
            HelpMessage(text: helpText)
        }
    }
}

/// Component for displaying error messages
private struct ErrorMessage: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(DesignTokens.Typography.caption1.font)
            .foregroundColor(DesignTokens.Colors.error)
            .padding(.top, DesignTokens.Spacing.xxxs)
    }
}

/// Component for displaying help text
private struct HelpMessage: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(DesignTokens.Typography.caption1.font)
            .foregroundColor(DesignTokens.Colors.tertiary)
            .padding(.top, DesignTokens.Spacing.xxxs)
    }
}

// MARK: - Conditional Rendering

extension FieldMessage {
    /// Creates a FieldMessage only if there's content to display
    static func conditional(
        validationState: FieldLabel.ValidationState,
        errorMessage: String? = nil,
        helpText: String? = nil
    ) -> some View {
        Group {
            if (errorMessage != nil && validationState == .invalid) || helpText != nil {
                FieldMessage(
                    validationState: validationState,
                    errorMessage: errorMessage,
                    helpText: helpText
                )
            }
        }
    }
}
import SwiftUI

/// A reusable field label component that handles label text, required indicator, and validation icons
struct FieldLabel: View {
    let text: String
    let isRequired: Bool
    let validationState: ValidationState
    let isFocused: Bool
    
    enum ValidationState {
        case none
        case valid
        case invalid
        case warning
        
        var icon: String? {
            switch self {
            case .valid:
                return "checkmark.circle.fill"
            case .invalid:
                return "exclamationmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .none:
                return nil
            }
        }
        
        var color: Color {
            switch self {
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
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Text(text)
                .font(DesignTokens.Typography.footnote.font)
                .foregroundColor(labelColor)
            
            RequiredIndicator(isVisible: isRequired)
            
            Spacer()
            
            ValidationIcon(validationState: validationState)
        }
    }
    
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
}

/// A component that shows a required indicator (asterisk)
private struct RequiredIndicator: View {
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            Text("*")
                .font(DesignTokens.Typography.footnote.font)
                .foregroundColor(DesignTokens.Colors.error)
        }
    }
}

/// A component that shows validation state icons
private struct ValidationIcon: View {
    let validationState: FieldLabel.ValidationState
    
    var body: some View {
        if let icon = validationState.icon {
            Image(systemName: icon)
                .font(DesignTokens.Typography.caption1.font)
                .foregroundColor(validationState.color)
        }
    }
}

// MARK: - Conditional Rendering

extension FieldLabel {
    /// Creates a FieldLabel only if the text is not empty
    static func conditional(
        text: String,
        isRequired: Bool = false,
        validationState: ValidationState = .none,
        isFocused: Bool = false
    ) -> some View {
        Group {
            if !text.isEmpty {
                FieldLabel(
                    text: text,
                    isRequired: isRequired,
                    validationState: validationState,
                    isFocused: isFocused
                )
            }
        }
    }
}
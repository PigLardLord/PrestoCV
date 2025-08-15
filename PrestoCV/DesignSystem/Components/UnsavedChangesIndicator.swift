import SwiftUI

/// A small circular indicator that shows when there are unsaved changes
struct UnsavedChangesIndicator: View {
    let isVisible: Bool
    let size: CGFloat
    let color: Color
    
    init(
        isVisible: Bool,
        size: CGFloat = DesignTokens.IndicatorSize.small,
        color: Color = DesignTokens.Colors.warning
    ) {
        self.isVisible = isVisible
        self.size = size
        self.color = color
    }
    
    var body: some View {
        Group {
            if isVisible {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .accessibilityLabel("Unsaved changes")
                    .accessibilityHint("There are unsaved changes in this form")
            }
        }
    }
}

// MARK: - Convenience Initializers
extension UnsavedChangesIndicator {
    /// Standard warning indicator for unsaved changes
    static func warning(isVisible: Bool) -> UnsavedChangesIndicator {
        UnsavedChangesIndicator(
            isVisible: isVisible,
            size: DesignTokens.IndicatorSize.small,
            color: DesignTokens.Colors.warning
        )
    }
    
    /// Error indicator (red) for validation issues
    static func error(isVisible: Bool) -> UnsavedChangesIndicator {
        UnsavedChangesIndicator(
            isVisible: isVisible,
            size: DesignTokens.IndicatorSize.small,
            color: DesignTokens.Colors.error
        )
    }
    
    /// Success indicator (green) for saved changes
    static func success(isVisible: Bool) -> UnsavedChangesIndicator {
        UnsavedChangesIndicator(
            isVisible: isVisible,
            size: DesignTokens.IndicatorSize.small,
            color: DesignTokens.Colors.success
        )
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.md) {
        HStack {
            Text("Save")
            UnsavedChangesIndicator.warning(isVisible: true)
        }
        
        HStack {
            Text("Error")
            UnsavedChangesIndicator.error(isVisible: true)
        }
        
        HStack {
            Text("Success")
            UnsavedChangesIndicator.success(isVisible: true)
        }
        
        HStack {
            Text("Hidden")
            UnsavedChangesIndicator.warning(isVisible: false)
        }
    }
    .padding()
}
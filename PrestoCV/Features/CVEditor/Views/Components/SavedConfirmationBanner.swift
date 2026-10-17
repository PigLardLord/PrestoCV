import SwiftUI

/// The short confirmation that a CV was saved, at the top of the editor. It takes no tap and stops nothing: the
/// person goes on editing, or leaves with Done.
struct SavedConfirmationBanner: View {
    var body: some View {
        Label {
            Text("editor.saved".localized)
                .typography(.subheadline)
                .foregroundColor(DesignTokens.Colors.primary)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(DesignTokens.Colors.accent)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(.regularMaterial, in: Capsule())
        .defaultShadow()
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.top, DesignTokens.Spacing.xs)
        .accessibilityElement(children: .combine)
        .allowsHitTesting(false)
        // It stays for a moment over the form: at the largest text sizes it would cover a third of it
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

extension View {
    /// Shows the confirmation of a save over the top of this view while `isShown`.
    func savedConfirmation(isShown: Bool) -> some View {
        modifier(SavedConfirmationOverlay(isShown: isShown))
    }
}

private struct SavedConfirmationOverlay: ViewModifier {
    let isShown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            ZStack {
                if isShown {
                    SavedConfirmationBanner()
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(DesignTokens.Animations.standardEaseInOut, value: isShown)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    SavedConfirmationBanner()
}
#endif

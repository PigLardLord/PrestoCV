import SwiftUI

/// Where the title of a screen is drawn.
///
/// The navigation bar draws its title on one line at the size the person chose, so a long title ends in "…" once the
/// text is large. From the accessibility sizes on, the title moves into the middle of an inline bar, where it wraps
/// over two lines and shrinks a little if it still does not fit.
enum ScreenTitlePlacement: Equatable {
    case large
    case inline
    case wrapped

    static func resolve(wantsLargeTitle: Bool, dynamicTypeSize: DynamicTypeSize) -> ScreenTitlePlacement {
        if dynamicTypeSize.isAccessibilitySize {
            return .wrapped
        }
        return wantsLargeTitle ? .large : .inline
    }
}

private struct ScreenTitle: ViewModifier {
    let title: String
    let wantsLargeTitle: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let placement = ScreenTitlePlacement.resolve(wantsLargeTitle: wantsLargeTitle, dynamicTypeSize: dynamicTypeSize)
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(placement == .large ? .large : .inline)
            .toolbar {
                if placement == .wrapped {
                    ToolbarItem(placement: .principal) {
                        Text(title)
                            .font(DesignTokens.Typography.headline.font)
                            .fontWeight(DesignTokens.Typography.headline.fontWeight)
                            .foregroundColor(DesignTokens.Colors.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            // The bar is no taller at the largest sizes: the title may grow as far as it fits
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
    }
}

extension View {
    /// The title of a screen, which stays whole at the largest text sizes. See `ScreenTitlePlacement`.
    func screenTitle(_ title: String, large: Bool = false) -> some View {
        modifier(ScreenTitle(title: title, wantsLargeTitle: large))
    }
}

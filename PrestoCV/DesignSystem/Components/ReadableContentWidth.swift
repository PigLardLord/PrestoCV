import SwiftUI

/// Keeps what the scroll views of a screen show to a readable width, centred, when the screen is wider than that.
///
/// The scroll views still fill the screen, so their background and their scroll bar stay at its edges: only the
/// rows and the fields are narrower. A screen that is no wider than the readable width, as every iPhone is, is
/// laid out as before.
struct ReadableContentWidth: ViewModifier {
    @State private var width: CGFloat = 0

    /// The margin on each side that leaves a column of `DesignTokens.Layout.readableContentWidth`.
    static func margin(forWidth width: CGFloat) -> CGFloat {
        guard width.isFinite else { return 0 }
        return max(0, (width - DesignTokens.Layout.readableContentWidth) / 2)
    }

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, Self.margin(forWidth: width), for: .scrollContent)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
    }
}

extension View {
    /// See `ReadableContentWidth`.
    func readableContentWidth() -> some View {
        modifier(ReadableContentWidth())
    }
}

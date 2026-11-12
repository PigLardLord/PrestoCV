import SwiftUI

extension View {
    /// Limits the view to the readable width and centres it in the space it is given.
    func readableWidth() -> some View {
        frame(maxWidth: ReadableWidth.maximum)
            .frame(maxWidth: .infinity)
    }

    /// Keeps the rows of a scrolling list or form at the readable width, centred in the space the safe area leaves,
    /// while its background fills the space it is given. Where that space is narrower, the rows keep the system's
    /// margins.
    func readableScrollContent() -> some View {
        modifier(ReadableScrollContent())
    }
}

private struct ReadableScrollContent: ViewModifier {
    @State private var margins = ReadableMargins(width: 0, leadingInset: 0, trailingInset: 0)

    func body(content: Content) -> some View {
        content
            .contentMargins(.leading, margins.leading, for: .scrollContent)
            .contentMargins(.trailing, margins.trailing, for: .scrollContent)
            // The form lies in the safe area, and its safe area insets say how far its scroll view reaches past it,
            // under what covers the edges
            .onGeometryChange(for: ReadableMargins.self) { proxy in
                ReadableMargins(
                    width: proxy.size.width, leadingInset: proxy.safeAreaInsets.leading,
                    trailingInset: proxy.safeAreaInsets.trailing)
            } action: { margins = $0 }
    }
}

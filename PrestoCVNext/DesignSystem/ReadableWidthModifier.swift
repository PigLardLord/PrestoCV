import SwiftUI

extension View {
    /// Limits the view to the readable width and centres it in the space it is given.
    func readableWidth() -> some View {
        frame(maxWidth: ReadableWidth.maximum)
            .frame(maxWidth: .infinity)
    }

    /// Keeps the rows of a scrolling list or form at the readable width, centred, while its background fills the space
    /// it is given.
    func readableScrollContent() -> some View {
        modifier(ReadableScrollContent())
    }
}

private struct ReadableScrollContent: ViewModifier {
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, max(0, (width - ReadableWidth.maximum) / 2), for: .scrollContent)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

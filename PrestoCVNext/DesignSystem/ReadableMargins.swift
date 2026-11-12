import SwiftUI

/// The leading and trailing margins that keep the rows of a scrolling form at the readable width, centred in the space
/// the safe area leaves. The form lies in that space, but its scroll view reaches under what covers the edges, and a
/// margin given to a scroll view counts from the scroll view's own edge: it replaces both the safe area and the
/// system's margin. A space too narrow for the readable width and a medium spacing on each side gets no margin, and the
/// form keeps the system's.
struct ReadableMargins: Equatable {
    /// From the scroll view's leading edge to the rows; nil keeps the system's margin.
    let leading: CGFloat?
    /// From the scroll view's trailing edge to the rows; nil keeps the system's margin.
    let trailing: CGFloat?

    /// - Parameters:
    ///   - width: The form's width: the space the safe area leaves.
    ///   - leadingInset: How far the scroll view reaches past the form's leading edge, under what covers it: a list
    ///     beside the form, a notch.
    ///   - trailingInset: How far the scroll view reaches past the form's trailing edge.
    init(width: CGFloat, leadingInset: CGFloat, trailingInset: CGFloat) {
        guard width >= ReadableWidth.maximum + 2 * Spacing.medium else {
            leading = nil
            trailing = nil
            return
        }
        let extra = (width - ReadableWidth.maximum) / 2
        leading = leadingInset + extra
        trailing = trailingInset + extra
    }
}

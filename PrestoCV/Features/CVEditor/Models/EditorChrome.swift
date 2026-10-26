import SwiftUI

/// How the editor spends the height it has around the form.
///
/// In landscape, and at the largest text sizes, the navigation bar, the notice above the form and the tab bar leave the form
/// little room.
struct EditorChrome: Equatable {
    let verticalSizeClass: UserInterfaceSizeClass?
    let dynamicTypeSize: DynamicTypeSize

    /// The share of the editor's height that the notice above the form may take where the form is short of room.
    static let noticeShareOfHeight: CGFloat = 0.25

    /// Where the form is short of room, the tab bar shrinks while it is scrolled, as in Apple's own apps.
    var minimizesTabBar: Bool {
        isShortOfRoom
    }

    /// The height of the notice above the form, `fullHeight` points tall with all its lines, in an editor `editorHeight` points
    /// tall, where the form is short of room: at most `noticeShareOfHeight` of the editor; the notice scrolls beyond it, and the
    /// form keeps the rest. Nil where the form has room, or before the editor's height is known: the notice shows all its lines.
    func noticeHeight(fullHeight: CGFloat, editorHeight: CGFloat) -> CGFloat? {
        guard isShortOfRoom, editorHeight > 0 else { return nil }
        return min(fullHeight, editorHeight * Self.noticeShareOfHeight)
    }

    private var isShortOfRoom: Bool {
        verticalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
    }
}

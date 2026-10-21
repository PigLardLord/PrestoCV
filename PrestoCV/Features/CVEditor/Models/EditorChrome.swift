import SwiftUI

/// How the editor spends the height it has around the form.
///
/// In landscape, and at the largest text sizes, the navigation bar and the tab bar leave the form little room.
struct EditorChrome: Equatable {
    let verticalSizeClass: UserInterfaceSizeClass?
    let dynamicTypeSize: DynamicTypeSize

    /// Where the form is short of room, the tab bar shrinks while it is scrolled, as in Apple's own apps.
    var minimizesTabBar: Bool {
        verticalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
    }
}

import SwiftUI

/// How the editor spends the height it has: what sits above and below the form.
///
/// In landscape, and at the largest text sizes, the navigation bar, the tab bar and the export button used to leave
/// the form about one row.
struct EditorChrome: Equatable {
    let verticalSizeClass: UserInterfaceSizeClass?
    let dynamicTypeSize: DynamicTypeSize

    /// In landscape the bar below the form would take a fifth of the height: the export button goes up beside Save.
    var exportsFromNavigationBar: Bool {
        verticalSizeClass == .compact
    }

    /// Where the form is short of room, the tab bar shrinks while it is scrolled, as in Apple's own apps.
    var minimizesTabBar: Bool {
        verticalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
    }
}

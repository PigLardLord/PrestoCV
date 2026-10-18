import SwiftUI

/// Where the first run puts its ways to start: after the welcome, or before it.
///
/// At the accessibility sizes the welcome alone used to fill the screen, and in landscape on an iPhone it left room
/// for one button: there the ways to start come first, and the welcome follows them.
enum FirstRunLayout: Equatable {
    case welcomeFirst
    case actionsFirst

    static func resolve(dynamicTypeSize: DynamicTypeSize, verticalSizeClass: UserInterfaceSizeClass?) -> FirstRunLayout {
        if dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact {
            return .actionsFirst
        }
        return .welcomeFirst
    }
}

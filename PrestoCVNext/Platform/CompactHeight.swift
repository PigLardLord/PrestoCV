import SwiftUI

extension EnvironmentValues {
    /// Whether the height is compact, as on an iPhone in landscape. Size classes are iOS only; a Mac window is never
    /// compact, so there it is false.
    var isCompactHeight: Bool {
        #if os(iOS)
        verticalSizeClass == .compact
        #else
        false
        #endif
    }
}

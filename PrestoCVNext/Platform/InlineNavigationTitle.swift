import SwiftUI

extension View {
    /// Shows the navigation title in the bar's small, inline style. The large style is iOS only; on macOS the title has
    /// one style, so there it changes nothing.
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

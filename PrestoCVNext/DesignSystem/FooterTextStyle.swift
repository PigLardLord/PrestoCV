import SwiftUI

extension View {
    /// The look of a note under a list or a group of controls, such as the line that says the examples are invented: small
    /// and secondary, so that it reads after what it is about.
    func footerTextStyle() -> some View {
        font(.footnote)
            .foregroundStyle(.secondary)
    }
}

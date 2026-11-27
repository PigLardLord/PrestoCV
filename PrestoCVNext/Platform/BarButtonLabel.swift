import SwiftUI

/// The label of a bar button that carries an accessibility value. On iOS 27.0 a toolbar button whose label is a
/// `Label` loses its accessibility value, enabled or not, so VoiceOver no longer reads it after the name; an image
/// named by its accessibility label keeps it, on iOS 26 as on 27. The bar shows the same icon either way, and the
/// large content viewer still shows the title. A Mac keeps the `Label`. On iOS 26 the bar's item host repeats the
/// name and the value, so a UI test also finds an `Other` with the button's identifier; the host is not an
/// accessibility element, and VoiceOver stops on the button once.
struct BarButtonLabel: View {
    private let title: LocalizedStringKey
    private let systemImage: String

    init(_ title: LocalizedStringKey, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        #if os(iOS)
        Image(systemName: systemImage)
            .accessibilityLabel(Text(title))
            .accessibilityShowsLargeContentViewer {
                Label(title, systemImage: systemImage)
            }
        #else
        Label(title, systemImage: systemImage)
        #endif
    }
}

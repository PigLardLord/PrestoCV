import SwiftUI

/// The layer over the import screen while the text is read: what it waits for, which VoiceOver moves to, and Cancel,
/// which leaves the screen and its text as they were. It is opaque, so the text under it can be neither read nor
/// touched.
struct ImportingOverlay: View {
    /// Stops the read.
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            LoadingView("import.reading")
                .fixedSize(horizontal: false, vertical: true)
            Button(action: cancel) {
                WholeWordsText("import.cancel")
                    .frame(minHeight: TapTarget.minimumHeight)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: CornerRadius.control))
            .accessibilityIdentifier("import.cancel")
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .contentShape(.rect)
    }
}

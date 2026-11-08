import SwiftUI

/// The main action of a screen: filled with the tint, at least as tall as the smallest tap target.
struct PrimaryButton: View {
    private let title: LocalizedStringResource
    private let action: () -> Void

    init(_ title: LocalizedStringResource, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            WholeWordsText(title)
                .frame(maxWidth: .infinity, minHeight: TapTarget.minimumHeight)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: CornerRadius.control))
        .controlSize(.large)
    }
}

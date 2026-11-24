import SwiftUI

/// The system's paste button for text, bordered and at least as tall as the smallest tap target. The system draws its
/// words and asks no permission: the tap is the person's own paste. It hands over the strings on the main actor, as a
/// view model takes them; the system calls its own action off it.
struct PasteTextButton: View {
    private let onPaste: @MainActor @Sendable ([String]) -> Void

    /// - Parameter onPaste: What the strings pasted go to, one per item of the clipboard.
    init(onPaste: @escaping @MainActor @Sendable ([String]) -> Void) {
        self.onPaste = onPaste
    }

    var body: some View {
        let onPaste = onPaste
        PasteButton(payloadType: String.self) { strings in
            Task { @MainActor in onPaste(strings) }
        }
        .labelStyle(.titleOnly)
        .buttonBorderShape(.roundedRectangle(radius: CornerRadius.control))
        .controlSize(.large)
        .frame(minHeight: TapTarget.minimumHeight)
        .accessibilityIdentifier("import.paste")
    }
}

import SwiftUI

/// A text field for one value. It grows to more lines when its text does not fit, instead of cutting it off.
/// Return ends the entry, as it does in a one-line field, instead of starting another line.
struct GrowingTextField: View {
    let title: String
    @Binding var text: String
    let accessibilityLabel: String
    let onReturn: (() -> Void)?
    
    init(_ title: String, text: Binding<String>, accessibilityLabel: String? = nil, onReturn: (() -> Void)? = nil) {
        self.title = title
        self._text = text
        self.accessibilityLabel = accessibilityLabel ?? title
        self.onReturn = onReturn
    }
    
    var body: some View {
        TextField(title, text: $text, axis: .vertical)
            .lineLimit(1...5)
            .accessibilityLabel(accessibilityLabel)
            .onChange(of: text) { _, newValue in
                guard newValue.contains(where: \.isNewline) else { return }
                text = newValue.onOneLine
                onReturn?()
                UIApplication.shared.dismissKeyboard()
            }
    }
}

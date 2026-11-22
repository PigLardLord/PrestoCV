import SwiftUI
import UniformTypeIdentifiers

/// The system's paste button for the import: a text, or a PDF such as one copied in Files. Bordered and at least as tall
/// as the smallest tap target. The system draws its words and asks no permission: the tap is the person's own paste. It
/// hands over what each item of the clipboard holds, on the main actor, as a view model takes it; the system calls its
/// own action off it.
struct PasteImportButton: View {
    private let onPaste: @MainActor @Sendable (_ strings: [String], _ pdfs: [Data]) -> Void

    /// - Parameter onPaste: What was pasted goes to: the strings and the PDFs, each in the clipboard's order.
    init(onPaste: @escaping @MainActor @Sendable (_ strings: [String], _ pdfs: [Data]) -> Void) {
        self.onPaste = onPaste
    }

    var body: some View {
        let onPaste = onPaste
        PasteButton(payloadType: PastedItem.self) { items in
            let strings = items.compactMap(\.string), pdfs = items.compactMap(\.pdf)
            Task { @MainActor in onPaste(strings, pdfs) }
        }
        .labelStyle(.titleOnly)
        .buttonBorderShape(.roundedRectangle(radius: CornerRadius.control))
        .controlSize(.large)
        .frame(minHeight: TapTarget.minimumHeight)
        .accessibilityIdentifier("import.paste")
    }
}

/// One item of the clipboard: the bytes of a PDF when it holds one, its text otherwise. The PDF comes first, as the
/// system takes the first representation an item has.
private enum PastedItem: Transferable {
    case pdf(Data)
    case text(String)

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .pdf) { PastedItem.pdf($0) }
        ProxyRepresentation(importing: { (text: String) in PastedItem.text(text) })
    }

    var pdf: Data? {
        if case .pdf(let data) = self { data } else { nil }
    }

    var string: String? {
        if case .text(let text) = self { text } else { nil }
    }
}

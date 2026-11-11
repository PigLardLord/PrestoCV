import PrestoCVPresentation
import SwiftUI

/// The PDF of the export on the whole screen, under the name of its file, to read it and zoom in on it. It renders the
/// model's PDF and forwards Done; the sheet's model decides what it shows (R5).
struct FullPDFView: View {
    let full: FullPDF
    /// Closes the whole screen; the sheet keeps its PDF.
    let done: () -> Void

    var body: some View {
        NavigationStack {
            PDFPages(pdf: full.document.pdf, id: full.id, isForTheEyeOnly: false)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(Text(verbatim: full.fileName))
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: done) {
                            Label("export.full.done", systemImage: "checkmark")
                        }
                        .accessibilityIdentifier("export.full.done")
                    }
                }
        }
    }
}

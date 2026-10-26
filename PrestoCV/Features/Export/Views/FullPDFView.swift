import SwiftUI

/// The PDF full screen, over the export sheet: every page, one under the other, to scroll through and to enlarge by
/// pinching. It shows the file that the sheet shares, so what is read here is what goes out.
struct FullPDFView: View {
    let pdf: ExportedPDF
    /// Closes the viewer, back to the sheet as it was
    let close: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            PDFPreviewView(url: pdf.url)
                // The pages scroll under the home indicator
                .ignoresSafeArea(edges: .bottom)
                .screenTitle(pdf.fileName)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        BarButton(title: String(localized: "common.done"), systemImage: "checkmark", screenTextSize: dynamicTypeSize) {
                            close()
                        }
                    }
                }
        }
    }
}

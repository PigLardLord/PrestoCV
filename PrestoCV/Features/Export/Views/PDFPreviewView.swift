import SwiftUI
import PDFKit

/// The pages of a rendered PDF, one under the other, to scroll through
struct PDFPreviewView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        // The pages are shown as they print, on paper, in a dark interface too
        view.overrideUserInterfaceStyle = .light
        view.backgroundColor = UIColor(white: 0.93, alpha: 1)
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard view.document?.documentURL != url else { return }
        view.document = PDFDocument(url: url)
    }
}

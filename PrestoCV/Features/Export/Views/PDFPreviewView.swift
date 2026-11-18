import SwiftUI
import PDFKit

/// The pages of a PDF as the export sheet and the full screen viewer show them: one under the other, on paper, to
/// scroll through. A page is never smaller than the width of the screen, and a pinch enlarges it up to `zoomLimit` times
/// that, to read the small print.
final class PDFPagesView: PDFView {
    /// How many times the width of the screen a page can be enlarged to
    static let zoomLimit: CGFloat = 4

    /// How close two scales are for the same one
    private static let tolerance: CGFloat = 0.001

    /// The scale that fitted the width at the last layout; nil while the pages of a document are not laid out yet
    private var fittedScale: CGFloat?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override var document: PDFDocument? {
        didSet {
            fittedScale = nil
            setNeedsLayout()
        }
    }

    /// The fit, and so the range of the zoom, follows the width: when the device is turned or the window resized.
    ///
    /// PDFKit stops fitting the pages to the width as soon as a limit of the zoom is set (`autoScales` turns off), so
    /// pages that are at the fit are kept there here, wider and narrower; pages that were enlarged keep their size,
    /// within the new range.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard document != nil else { return }
        let fit = scaleFactorForSizeToFit
        guard fit > 0 else { return }

        let wereAtTheFit = fittedScale.map { abs(scaleFactor - $0) < Self.tolerance } ?? true
        limitZoom(toFit: fit)
        if wereAtTheFit, abs(scaleFactor - fit) >= Self.tolerance {
            scaleFactor = fit
        }
        fittedScale = fit
    }

    /// The smallest page is the fit and the largest is `zoomLimit` times it; the minimum is never set above the maximum
    private func limitZoom(toFit fit: CGFloat) {
        let largest = fit * Self.zoomLimit
        guard abs(minScaleFactor - fit) >= Self.tolerance || abs(maxScaleFactor - largest) >= Self.tolerance else { return }
        if fit > maxScaleFactor {
            maxScaleFactor = largest
            minScaleFactor = fit
        } else {
            minScaleFactor = fit
            maxScaleFactor = largest
        }
    }

    private func configure() {
        // PDFKit fits the first page by itself until the first layout sets the limits of the zoom
        autoScales = true
        displayMode = .singlePageContinuous
        displayDirection = .vertical
        displaysPageBreaks = true
        // The pages are shown as they print, on paper, in a dark interface too
        overrideUserInterfaceStyle = .light
        backgroundColor = UIColor(white: 0.93, alpha: 1)
    }
}

/// The pages of a rendered PDF, one under the other, to scroll through
struct PDFPreviewView: UIViewRepresentable {
    let url: URL
    /// The pages are only to look at, because something else stands for them to assistive technology. PDFKit gives their
    /// text to it, and SwiftUI's `accessibilityHidden` marks its own node without setting a flag on this view, so the view
    /// is hidden here too.
    var isForTheEyeOnly = false

    func makeUIView(context: Context) -> PDFPagesView {
        let view = PDFPagesView()
        view.document = PDFDocument(url: url)
        hide(view)
        return view
    }

    /// The document is shown first and the pages hidden after it, so that a new document cannot bring PDFKit's elements
    /// back to pages for the eye only
    func updateUIView(_ view: PDFPagesView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
        hide(view)
    }

    /// PDFKit gives the text of the pages to assistive technology as elements of the view. On iOS 27 the hidden flag alone
    /// no longer keeps them out of the tree that the system's automation reads, so pages for the eye only also list no
    /// element, and nil gives PDFKit's own elements back. The flag tells that the list was emptied here: PDFKit's elements
    /// are never read to find it out.
    private func hide(_ view: PDFPagesView) {
        if isForTheEyeOnly {
            view.accessibilityElementsHidden = true
            view.accessibilityElements = []
        } else if view.accessibilityElementsHidden {
            view.accessibilityElementsHidden = false
            view.accessibilityElements = nil
        }
    }
}

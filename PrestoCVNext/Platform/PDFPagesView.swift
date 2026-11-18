import PDFKit
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The pages of a PDF, one under the other on a light gray ground, fitted to the width and zoomed in up to four times.
///
/// Setting the scale limits turns PDFKit's own fit (`autoScales`) off, so the view keeps the fit by hand: at each layout the
/// smallest scale is the fit and the largest four times it, and a view that stood at the old fit moves to the new one,
/// while a zoom the person chose stays.
final class PDFPagesView: PDFView {
    /// How far the person zooms in, as a multiple of the fit.
    static let zoomLimit: CGFloat = 4
    private static let tolerance: CGFloat = 0.001

    /// The fit of the last layout with a document, nil before it.
    private var fittedScale: CGFloat?

    /// The PDF to show once the update under way is done, nil when none waits.
    private var waitingPDF: Data?

    /// The step that shows the waiting PDF once the update is done, nil when none is due.
    private(set) var showing: Task<Void, Never>?

    /// Whether assistive technologies skip the pages, because the screen tells what they hold in another way.
    var isForTheEyeOnly = false {
        didSet { applyHiding() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    /// Shows a document at the fit, from its first page.
    ///
    /// A method, not an override of `document`: PDFKit reads `document` on its own queues (the page analyzer that looks
    /// for form fields as pages come into view), and an override is main-actor code, which traps when read there.
    func show(_ shown: PDFDocument?) {
        document = shown
        fittedScale = nil
        askForLayout()
    }

    /// Shows a PDF once the update under way is done; of several given meanwhile, the last.
    ///
    /// A new document takes PDFKit's old pages out of the window, and one of them may hold the focus. Given up inside
    /// SwiftUI's update, the focus makes SwiftUI read its graph again in the middle of that update, and the update never
    /// ends: the app stops answering (#407). After the update, it is an ordinary change of focus.
    func showAfterTheUpdate(_ pdf: Data) {
        waitingPDF = pdf
        guard showing == nil else { return }
        showing = Task { @MainActor [weak self] in
            guard let self else { return }
            self.showing = nil
            guard let pdf = self.waitingPDF else { return }
            self.waitingPDF = nil
            self.show(PDFDocument(data: pdf))
        }
    }

    /// Keeps the fit and the zoom limits after a layout.
    private func fit() {
        guard document != nil else { return }
        let fit = scaleFactorForSizeToFit
        guard fit > 0 else { return }
        let wereAtTheFit = fittedScale.map { abs(scaleFactor - $0) < Self.tolerance } ?? true
        limitZoom(toFit: fit)
        if wereAtTheFit, abs(scaleFactor - fit) >= Self.tolerance { scaleFactor = fit }
        fittedScale = fit
    }

    /// Sets the limits to the fit and to four times it. PDFKit refuses a smallest scale above the largest one, so the limit
    /// that moves away from the other is set first.
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
        autoScales = true
        displayMode = .singlePageContinuous
        displayDirection = .vertical
        displaysPageBreaks = true
        paintThePagesLight()
        applyHiding()
    }

    // MARK: - Platform

    #if os(iOS)
    override func layoutSubviews() {
        super.layoutSubviews()
        fit()
    }

    private func askForLayout() { setNeedsLayout() }

    /// A page stays white in dark mode, as it prints.
    private func paintThePagesLight() {
        overrideUserInterfaceStyle = .light
        backgroundColor = UIColor(white: 0.93, alpha: 1)
    }

    private func applyHiding() { accessibilityElementsHidden = isForTheEyeOnly }
    #else
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        fit()
    }

    private func askForLayout() { needsLayout = true }

    /// A page stays white in dark mode, as it prints.
    private func paintThePagesLight() {
        appearance = NSAppearance(named: .aqua)
        backgroundColor = NSColor(white: 0.93, alpha: 1)
    }

    /// AppKit has no flag that hides a view's children (`accessibilityHidden` is the app's attribute): the view gives
    /// none while it is for the eye only.
    private func applyHiding() { NSAccessibility.post(element: self, notification: .layoutChanged) }

    override func accessibilityChildren() -> [Any]? {
        isForTheEyeOnly ? [] : super.accessibilityChildren()
    }

    override func isAccessibilityElement() -> Bool {
        isForTheEyeOnly ? false : super.isAccessibilityElement()
    }
    #endif
}

/// A PDF's pages in SwiftUI (`PDFPagesView`). The document is read again only when `id` changes, so that a redraw keeps
/// the person's zoom and scroll; a new one is shown once SwiftUI's update is done (`showAfterTheUpdate`).
#if os(iOS)
struct PDFPages<ID: Hashable>: UIViewRepresentable {
    let pdf: Data
    let id: ID
    let isForTheEyeOnly: Bool

    func makeCoordinator() -> ShownDocument<ID> { ShownDocument() }

    func makeUIView(context: Context) -> PDFPagesView { make(context.coordinator) }

    func updateUIView(_ view: PDFPagesView, context: Context) { update(view, context.coordinator) }
}
#else
struct PDFPages<ID: Hashable>: NSViewRepresentable {
    let pdf: Data
    let id: ID
    let isForTheEyeOnly: Bool

    func makeCoordinator() -> ShownDocument<ID> { ShownDocument() }

    func makeNSView(context: Context) -> PDFPagesView { make(context.coordinator) }

    func updateNSView(_ view: PDFPagesView, context: Context) { update(view, context.coordinator) }
}
#endif

extension PDFPages {
    /// The first document is shown at once: the view is in no window yet, so nothing in it holds the focus.
    private func make(_ shown: ShownDocument<ID>) -> PDFPagesView {
        let view = PDFPagesView(frame: .zero)
        view.isForTheEyeOnly = isForTheEyeOnly
        shown.id = id
        view.show(PDFDocument(data: pdf))
        return view
    }

    /// The flag is set on each update: SwiftUI's `accessibilityHidden` does not reach into a hosted view.
    private func update(_ view: PDFPagesView, _ shown: ShownDocument<ID>) {
        view.isForTheEyeOnly = isForTheEyeOnly
        guard shown.id != id else { return }
        shown.id = id
        view.showAfterTheUpdate(pdf)
    }
}

/// The identity of the document a `PDFPages` view shows.
@MainActor
final class ShownDocument<ID: Hashable> {
    var id: ID?
}

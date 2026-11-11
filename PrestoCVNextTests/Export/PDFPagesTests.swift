import SwiftUI
import Testing
@testable import PrestoCVNext

/// The export sheet shows the PDF's pages for the eye only: its own lines say what the PDF holds, so assistive
/// technologies skip the pages. SwiftUI's `accessibilityHidden` does not reach into a hosted view, so the pages hide
/// themselves. They also keep their fit and zoom by hand, as setting the zoom limits turns PDFKit's own fit off.
@Suite("PDFPages: the pages of a PDF, fitted, zoomed up to four times, and hidden when they are for the eye only")
@MainActor
struct PDFPagesTests {
    #if os(iOS)
    /// A PDF of one A4 page with a dark bar on it.
    private func onePagePDF() -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            context.beginPage()
            UIColor.black.setFill()
            context.fill(CGRect(x: 40, y: 40, width: 200, height: 30))
        }
    }

    /// The pages of a view once it is on a screen of an iPhone's size.
    private func pagesView(of pages: some View) -> PDFPagesView? {
        let host = UIHostingController(rootView: pages)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        defer { window.isHidden = true }
        return find(in: host.view)
    }

    private func find(in view: UIView) -> PDFPagesView? {
        if let pages = view as? PDFPagesView { return pages }
        return view.subviews.lazy.compactMap { find(in: $0) }.first
    }

    @Test("Pages for the eye only give assistive technologies nothing to read, and other pages are read")
    func pagesForTheEyeOnlyAreHidden() throws {
        let pdf = onePagePDF()
        let hidden = try #require(pagesView(of: PDFPages(pdf: pdf, id: 1, isForTheEyeOnly: true)), "The PDF is shown")
        let read = try #require(pagesView(of: PDFPages(pdf: pdf, id: 1, isForTheEyeOnly: false)), "The PDF is shown")

        #expect(hidden.accessibilityElementsHidden, "The text PDFKit gives a screen reader is not given")
        #expect(read.accessibilityElementsHidden == false, "Pages that are not for the eye only are read")
    }

    @Test("The pages open fitted to the width, and zoom in up to four times the fit and never out of it")
    func zoomGoesFromTheFitToFourTimesIt() throws {
        let pages = try #require(pagesView(of: PDFPages(pdf: onePagePDF(), id: 1, isForTheEyeOnly: true)))

        #expect(pages.document?.pageCount == 1, "The view shows the PDF it is given")
        let fit = pages.scaleFactorForSizeToFit
        try #require(fit > 0, "The pages have room to fit in")
        #expect(abs(pages.scaleFactor - fit) < 0.001, "The pages open at the fit")
        #expect(abs(pages.minScaleFactor - fit) < 0.001, "The person cannot zoom out of the fit")
        #expect(abs(pages.maxScaleFactor - fit * PDFPagesView.zoomLimit) < 0.001, "The person zooms in up to four times")
    }

    /// PDFKit's page analyzer, which looks for form fields as pages come into view, reads the view's document on a queue
    /// of its own. Main-actor code there, such as an override of `document`, traps and ends the app: this test then
    /// fails by a crash.
    @Test("PDFKit reads the shown document from a queue of its own, as it does while it looks for form fields")
    func documentIsReadOffTheMainActor() async throws {
        let pages = try #require(pagesView(of: PDFPages(pdf: onePagePDF(), id: 1, isForTheEyeOnly: false)))

        let read = await documentRead(offTheMainActorFrom: pages)
        #expect(read, "The queue reads the document the view shows")
    }
    #else
    @Test("Pages for the eye only give assistive technologies nothing to read")
    func pagesForTheEyeOnlyAreHidden() {
        let pages = PDFPagesView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))

        pages.isForTheEyeOnly = true
        #expect(pages.isAccessibilityElement() == false, "The pages are no element of their own")
        #expect(pages.accessibilityChildren()?.isEmpty ?? true, "The text PDFKit gives a screen reader is not given")
    }

    /// PDFKit reads the view's document on queues of its own; main-actor code there, such as an override of `document`,
    /// traps and ends the app: this test then fails by a crash.
    @Test("PDFKit reads the document from a queue of its own")
    func documentIsReadOffTheMainActor() async {
        let pages = PDFPagesView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))

        let read = await documentRead(offTheMainActorFrom: pages)
        #expect(read == false, "The queue reads that the view shows no document yet")
    }
    #endif

    /// Whether a queue other than the main one, reading the view's document as PDFKit does, finds one.
    private func documentRead(offTheMainActorFrom pages: PDFPagesView) async -> Bool {
        await withCheckedContinuation { (read: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global().async {
                read.resume(returning: pages.perform(NSSelectorFromString("document")) != nil)
            }
        }
    }
}

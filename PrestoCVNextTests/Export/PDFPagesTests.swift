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
        pdf(pages: 1)
    }

    /// A PDF of A4 pages, each with a dark bar on it.
    private func pdf(pages: Int) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            for _ in 0..<pages {
                context.beginPage()
                UIColor.black.setFill()
                context.fill(CGRect(x: 40, y: 40, width: 200, height: 30))
            }
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

    /// Makes SwiftUI run its update of a hosted view now: `layoutIfNeeded` alone finds no layout due and leaves the new
    /// root view waiting.
    private func runTheUpdate(of host: UIHostingController<PDFPages<Int>>) {
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
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

    /// A new document takes PDFKit's old pages out of the window, and one of them may hold the focus: given up inside
    /// SwiftUI's update, the focus made the update start again without end, and the app stopped answering when a look
    /// was picked (#407). So the update leaves the shown document in place, and the new one comes once it is done.
    @Test("A new PDF is shown once SwiftUI's update is done, the last of those given meanwhile")
    func newPDFIsShownAfterTheUpdate() async throws {
        let host = UIHostingController(rootView: PDFPages(pdf: pdf(pages: 1), id: 1, isForTheEyeOnly: true))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        let pages = try #require(find(in: host.view), "The PDF is shown")

        host.rootView = PDFPages(pdf: pdf(pages: 2), id: 2, isForTheEyeOnly: true)
        runTheUpdate(of: host)
        let showing = try #require(pages.showing, "The update asks for the new PDF")
        #expect(pages.document?.pageCount == 1, "The update leaves the shown document in place")
        host.rootView = PDFPages(pdf: pdf(pages: 3), id: 3, isForTheEyeOnly: true)
        runTheUpdate(of: host)
        #expect(pages.showing == showing, "A PDF given while one waits takes its place, with no second step")
        #expect(pages.document?.pageCount == 1, "The second update leaves the shown document in place too")

        await showing.value
        #expect(pages.document?.pageCount == 3, "Once the update is done, the view shows the last PDF it was given")
        #expect(pages.showing == nil, "Nothing waits once it is shown")
        #expect(find(in: host.view) === pages, "The same view shows the new PDF, so the person's place is kept")
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

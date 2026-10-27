import Testing
import Foundation
import PDFKit
import UIKit
@testable import PrestoCV

/// The pages of the PDF as the export sheet and the full screen viewer show them: one under the other, on paper, to be
/// enlarged by pinching but not made smaller than the width of the screen.
@MainActor
@Suite("PDFPagesView Tests")
struct PDFPagesViewTests {

    private func makeDocument(pages: Int) throws -> PDFDocument {
        let size = CGSize(width: 595, height: 842)
        let data = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size)).pdfData { context in
            for _ in 0..<pages {
                context.beginPage()
                UIColor.black.setFill()
                context.fill(CGRect(x: 40, y: 40, width: 200, height: 30))
            }
        }
        return try #require(PDFDocument(data: data))
    }

    private func makeView(width: CGFloat = 390, pages: Int = 3) throws -> PDFPagesView {
        let view = PDFPagesView()
        view.frame = CGRect(x: 0, y: 0, width: width, height: 700)
        view.document = try makeDocument(pages: pages)
        view.layoutIfNeeded()
        return view
    }

    @Test("Every page is shown, one under the other, to scroll through")
    func pagesAreShownOneUnderTheOther() throws {
        let view = try makeView()

        #expect(view.document?.pageCount == 3)
        #expect(view.displayMode == .singlePageContinuous)
        #expect(view.displayDirection == .vertical)
        #expect(view.displaysPageBreaks)
    }

    @Test("The pages are shown on paper, in a dark interface too")
    func pagesAreOnPaper() throws {
        let view = try makeView()

        #expect(view.overrideUserInterfaceStyle == .light)
    }

    @Test("A page cannot be made smaller than the width of the screen")
    func pagesStopAtTheFit() throws {
        let view = try makeView()

        #expect(view.scaleFactorForSizeToFit > 0)
        #expect(view.minScaleFactor == view.scaleFactorForSizeToFit)
    }

    @Test("A page can be enlarged by pinching, up to four times the fit")
    func pagesCanBeEnlarged() throws {
        let view = try makeView()

        #expect(view.maxScaleFactor == view.scaleFactorForSizeToFit * PDFPagesView.zoomLimit)
        #expect(view.maxScaleFactor > view.minScaleFactor)
        #expect(PDFPagesView.zoomLimit == 4)
    }

    @Test("The pages fit the width at first")
    func pagesFitTheWidth() throws {
        let view = try makeView()

        #expect(abs(view.scaleFactor - view.scaleFactorForSizeToFit) < 0.001)
    }

    @Test("The pages keep the width of the screen when the device is turned or the window resized, wider and narrower")
    func pagesFollowTheWidth() throws {
        let view = try makeView(width: 390)

        view.frame = CGRect(x: 0, y: 0, width: 820, height: 700)
        view.layoutIfNeeded()
        #expect(abs(view.scaleFactor - view.scaleFactorForSizeToFit) < 0.001, "wider: the page is as wide as the view")

        view.frame = CGRect(x: 0, y: 0, width: 300, height: 700)
        view.layoutIfNeeded()
        #expect(abs(view.scaleFactor - view.scaleFactorForSizeToFit) < 0.001, "narrower: the page is not wider than the view")
    }

    @Test("Pages enlarged by pinching stay as enlarged when the width changes, within the new range")
    func enlargedPagesStayEnlarged() throws {
        let view = try makeView(width: 820)
        let enlarged = view.scaleFactorForSizeToFit * 1.5
        view.scaleFactor = enlarged

        view.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        view.layoutIfNeeded()

        #expect(abs(view.scaleFactor - enlarged) < 0.001)
        #expect(view.scaleFactor > view.scaleFactorForSizeToFit)
        #expect(view.scaleFactor <= view.maxScaleFactor)
    }

    @Test("A new document is fitted to the width, whatever the zoom of the one before")
    func newDocumentIsFitted() throws {
        let view = try makeView()
        view.scaleFactor = view.scaleFactorForSizeToFit * 2

        view.document = try makeDocument(pages: 2)
        view.layoutIfNeeded()

        #expect(abs(view.scaleFactor - view.scaleFactorForSizeToFit) < 0.001)
        #expect(view.minScaleFactor == view.scaleFactorForSizeToFit)
    }

    @Test("The range of the zoom follows the width, as when the device is turned or the window resized")
    func zoomRangeFollowsTheWidth() throws {
        let view = try makeView(width: 390)
        let narrowFit = view.scaleFactorForSizeToFit

        view.frame = CGRect(x: 0, y: 0, width: 820, height: 700)
        view.layoutIfNeeded()

        #expect(view.scaleFactorForSizeToFit > narrowFit)
        #expect(view.minScaleFactor == view.scaleFactorForSizeToFit)
        #expect(view.maxScaleFactor == view.scaleFactorForSizeToFit * PDFPagesView.zoomLimit)
    }

    /// `zoomedBy` is how many times the old fit the pages were enlarged to before the width changed (1 is at the fit);
    /// `endsAt` is how many times the new fit they are expected to end at
    @Test(
        "The range of the zoom follows a width that changes by more than the zoom limit",
        arguments: [
            (from: 200.0, to: 1000.0, zoomedBy: 1.0, endsAt: 1.0),
            (from: 1000.0, to: 200.0, zoomedBy: 1.0, endsAt: 1.0),
            (from: 200.0, to: 1000.0, zoomedBy: 2.0, endsAt: 1.0),
            (from: 1000.0, to: 200.0, zoomedBy: 3.0, endsAt: 4.0)
        ]
    )
    func zoomRangeFollowsAWidthThatChangesALot(from: Double, to: Double, zoomedBy: Double, endsAt: Double) throws {
        let view = try makeView(width: from)
        let oldFit = view.scaleFactorForSizeToFit
        view.scaleFactor = oldFit * zoomedBy

        view.frame = CGRect(x: 0, y: 0, width: to, height: 700)
        view.layoutIfNeeded()

        let fit = view.scaleFactorForSizeToFit
        #expect(max(fit / oldFit, oldFit / fit) > PDFPagesView.zoomLimit, "the width changed by more than the zoom limit")
        #expect(view.minScaleFactor == fit, "the smallest page is the new fit")
        #expect(view.maxScaleFactor == fit * PDFPagesView.zoomLimit, "the largest is the zoom limit times the new fit")
        #expect(abs(view.scaleFactor - fit * endsAt) < 0.001, "the pages end within the new range, as close to their size as it lets them")
    }
}

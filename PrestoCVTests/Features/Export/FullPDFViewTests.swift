import Testing
import SwiftUI
import PDFKit
import UIKit
@testable import PrestoCV

/// The full screen viewer shows the file that the export sheet shares, with all its pages.
@MainActor
@Suite("FullPDFView Tests")
struct FullPDFViewTests {

    private func makePDF(named name: String, pages: Int) throws -> ExportedPDF {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        let size = CGSize(width: 595, height: 842)
        try UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size)).writePDF(to: url) { context in
            for _ in 0..<pages {
                context.beginPage()
                UIColor.black.setFill()
                context.fill(CGRect(x: 40, y: 40, width: 200, height: 30))
            }
        }
        return ExportedPDF(url: url, pageCount: pages, thumbnail: nil)
    }

    /// The pages of a view, once it is on a screen
    private func pagesView(of viewer: some View) -> PDFPagesView? {
        let host = UIHostingController(rootView: viewer)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        defer { window.isHidden = true }
        return find(PDFPagesView.self, in: host.view)
    }

    private func find<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let match = find(type, in: subview) { return match }
        }
        return nil
    }

    @Test("The viewer shows the file of the PDF, with every page")
    func showsTheFileWithEveryPage() throws {
        let pdf = try makePDF(named: "Maria Rossi CV.pdf", pages: 3)
        defer { try? FileManager.default.removeItem(at: pdf.url.deletingLastPathComponent()) }

        let pages = try #require(pagesView(of: FullPDFView(pdf: pdf, close: {})), "the viewer has the pages of a PDF")

        #expect(pages.document?.documentURL == pdf.url, "it shows the file that the sheet shares")
        #expect(pages.document?.pageCount == 3, "every page of it")
    }

    @Test("The viewer gives its pages to assistive technology")
    func theViewerIsReadable() throws {
        let pdf = try makePDF(named: "Maria Rossi CV.pdf", pages: 2)
        defer { try? FileManager.default.removeItem(at: pdf.url.deletingLastPathComponent()) }

        let pages = try #require(pagesView(of: FullPDFView(pdf: pdf, close: {})))

        #expect(pages.accessibilityElementsHidden == false, "the viewer is where a screen reader reads every page")
    }

    @Test("Pages that are for the eye only are kept from assistive technology, whatever SwiftUI says")
    func pagesForTheEyeOnlyAreHidden() throws {
        let pdf = try makePDF(named: "Maria Rossi CV.pdf", pages: 2)
        defer { try? FileManager.default.removeItem(at: pdf.url.deletingLastPathComponent()) }

        let seen = try #require(pagesView(of: PDFPreviewView(url: pdf.url)))
        let forTheEye = try #require(pagesView(of: PDFPreviewView(url: pdf.url, isForTheEyeOnly: true)))

        #expect(seen.accessibilityElementsHidden == false, "by default the pages are read")
        #expect(forTheEye.accessibilityElementsHidden, "the text that PDFKit gives to a screen reader is not given")
    }

    @Test("A different file is shown for a different PDF")
    func showsTheFileItIsGiven() throws {
        let first = try makePDF(named: "First.pdf", pages: 1)
        let second = try makePDF(named: "Second.pdf", pages: 2)
        defer {
            try? FileManager.default.removeItem(at: first.url.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.url.deletingLastPathComponent())
        }

        let pages = try #require(pagesView(of: FullPDFView(pdf: second, close: {})))

        #expect(pages.document?.documentURL == second.url)
        #expect(pages.document?.documentURL != first.url)
        #expect(pages.document?.pageCount == 2)
    }
}

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
                // Text, so that PDFKit has something to give to assistive technology
                ("Maria Rossi" as NSString).draw(at: CGPoint(x: 40, y: 100), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
            }
        }
        return ExportedPDF(url: url, pageCount: pages, thumbnail: nil)
    }

    /// A view on a screen of an iPhone's size, with its host, so that a test can give it new values
    private func show<Shown: View>(_ view: Shown) -> (host: UIHostingController<Shown>, window: UIWindow) {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        return (host, window)
    }

    /// Gives a shown view new values. SwiftUI hands them to the hosted UIKit view in the host's next layout pass, and
    /// `layoutIfNeeded()` alone starts none: the host is marked for layout first
    private func update<Shown: View>(_ shown: (host: UIHostingController<Shown>, window: UIWindow), to view: Shown) {
        shown.host.rootView = view
        shown.host.view.setNeedsLayout()
        shown.host.view.layoutIfNeeded()
    }

    /// The pages of a view, once it is on a screen
    private func pagesView(of viewer: some View) -> PDFPagesView? {
        let shown = show(viewer)
        defer { shown.window.isHidden = true }
        return find(PDFPagesView.self, in: shown.host.view)
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
        #expect(pages.accessibilityElements?.isEmpty != true, "PDFKit's own elements are left as they are")
    }

    @Test("Pages that are for the eye only are kept from assistive technology, whatever SwiftUI says")
    func pagesForTheEyeOnlyAreHidden() throws {
        let pdf = try makePDF(named: "Maria Rossi CV.pdf", pages: 2)
        defer { try? FileManager.default.removeItem(at: pdf.url.deletingLastPathComponent()) }

        let seen = try #require(pagesView(of: PDFPreviewView(url: pdf.url)))
        let forTheEye = try #require(pagesView(of: PDFPreviewView(url: pdf.url, isForTheEyeOnly: true)))

        #expect(seen.accessibilityElementsHidden == false, "by default the pages are read")
        #expect(forTheEye.accessibilityElementsHidden, "the text that PDFKit gives to a screen reader is not given")
        #expect(
            forTheEye.accessibilityElements?.isEmpty == true,
            "no element either: on iOS 27 the hidden flag alone leaves PDFKit's text in the tree that UI automation reads")
    }

    @Test("Pages for the eye only stay without elements when they show another file")
    func pagesForTheEyeOnlyStayHiddenForAnotherFile() throws {
        let first = try makePDF(named: "First.pdf", pages: 1)
        let second = try makePDF(named: "Second.pdf", pages: 2)
        defer {
            try? FileManager.default.removeItem(at: first.url.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.url.deletingLastPathComponent())
        }
        let shown = show(PDFPreviewView(url: first.url, isForTheEyeOnly: true))
        defer { shown.window.isHidden = true }
        let pages = try #require(find(PDFPagesView.self, in: shown.host.view))

        update(shown, to: PDFPreviewView(url: second.url, isForTheEyeOnly: true))

        try #require(pages.document?.documentURL == second.url, "the same pages show the other file")
        #expect(pages.accessibilityElementsHidden, "they are still kept from assistive technology")
        #expect(pages.accessibilityElements?.isEmpty == true, "and still list no element")
    }

    @Test("Pages that stop being for the eye only give PDFKit's elements back")
    func pagesReadAgainGiveTheirElementsBack() throws {
        let pdf = try makePDF(named: "Maria Rossi CV.pdf", pages: 2)
        defer { try? FileManager.default.removeItem(at: pdf.url.deletingLastPathComponent()) }
        let shown = show(PDFPreviewView(url: pdf.url, isForTheEyeOnly: true))
        defer { shown.window.isHidden = true }
        let pages = try #require(find(PDFPagesView.self, in: shown.host.view))

        update(shown, to: PDFPreviewView(url: pdf.url))

        #expect(pages.accessibilityElementsHidden == false, "the pages are read again")
        #expect(pages.accessibilityElements?.isEmpty != true, "with PDFKit's elements, not the empty list")
    }

    @Test("Pages that become for the eye only lose their elements")
    func pagesThatBecomeForTheEyeOnlyAreHidden() throws {
        let pdf = try makePDF(named: "Maria Rossi CV.pdf", pages: 2)
        defer { try? FileManager.default.removeItem(at: pdf.url.deletingLastPathComponent()) }
        let shown = show(PDFPreviewView(url: pdf.url))
        defer { shown.window.isHidden = true }
        let pages = try #require(find(PDFPagesView.self, in: shown.host.view))

        update(shown, to: PDFPreviewView(url: pdf.url, isForTheEyeOnly: true))

        #expect(pages.accessibilityElementsHidden, "the pages are kept from assistive technology")
        #expect(pages.accessibilityElements?.isEmpty == true, "and list no element")
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

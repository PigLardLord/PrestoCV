import Testing
import Foundation
import PDFKit
@testable import CVPDFExporter

/// When the iOS renderer prints a document tightened onto one page, and when it prints it as it lays itself out.
/// The documents are blocks of a fixed height, with rules of their own under `fit-one-page`: how many blocks there are
/// and how much the rules take off says how many pages each print takes.
@MainActor
@Suite("One page fit in the iOS renderer", .serialized, .timeLimit(.minutes(2)))
struct OnePageFitRenderingTests {

    private static let options = ExportOptions(pageSize: .a4, margins: .uniform(43), maxPages: 10)

    /// `count` blocks of 100 pixels, each `tightened` pixels high under the tightening rules
    private static func document(blocks count: Int, tightened: Int) -> String {
        let blocks = (1...count).map { "<div class=\"block\">Block \($0)</div>" }.joined(separator: "\n")
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <style>
            * { margin: 0; padding: 0; }
            body { font: 12px -apple-system, sans-serif; }
            .block { height: 100px; break-inside: avoid; }
            html.\(OnePageFit.className) .block { height: \(tightened)px; }
        </style>
        </head>
        <body>
        \(blocks)
        </body>
        </html>
        """
    }

    private static func render(_ html: String) async throws -> PDFDocument {
        let data = try await EnhancedWKWebViewPDFRenderer().renderToPDF(html: html, options: options)
        return try #require(PDFDocument(data: data), "The renderer made a readable PDF")
    }

    private static func pageNumber(of text: String, in pdf: PDFDocument) -> Int? {
        (0..<pdf.pageCount).first { index in
            let lines = pdf.page(at: index)?.string?.components(separatedBy: .newlines) ?? []
            return lines.contains { $0.trimmingCharacters(in: .whitespaces) == text }
        }.map { $0 + 1 }
    }

    @Test("a document of two pages that its tightened spacing brings onto one page is printed on one page")
    func twoPagesThatFitTightenedTakeOne() async throws {
        let pdf = try await Self.render(Self.document(blocks: 12, tightened: 50))

        #expect(pdf.pageCount == 1)
        #expect(Self.pageNumber(of: "Block 12", in: pdf) == 1)
    }

    @Test("a document of two pages that its tightened spacing does not bring onto one page is printed as it lays itself out")
    func twoPagesThatDoNotFitKeepTheirLayout() async throws {
        let pdf = try await Self.render(Self.document(blocks: 16, tightened: 80))

        #expect(pdf.pageCount == 2)
        // With its own spacing the first page holds nine or ten blocks; tightened, it would hold eleven
        #expect(Self.pageNumber(of: "Block 11", in: pdf) == 2)
    }

    @Test("a document of three pages is printed as it lays itself out, even when tightened it would take fewer")
    func threePagesKeepTheirLayout() async throws {
        let pdf = try await Self.render(Self.document(blocks: 25, tightened: 40))

        #expect(pdf.pageCount == 3)
    }

    @Test("a document of one page is printed as it lays itself out")
    func onePageKeepsItsLayout() async throws {
        let pdf = try await Self.render(Self.document(blocks: 3, tightened: 10))
        let untouched = try await Self.render(Self.document(blocks: 3, tightened: 100))

        #expect(pdf.pageCount == 1)
        let height = try #require(Self.distance(from: "Block 1", to: "Block 3", in: pdf))
        let ownHeight = try #require(Self.distance(from: "Block 1", to: "Block 3", in: untouched))
        #expect(abs(height - ownHeight) < 1, "Two blocks take \(height) points instead of \(ownHeight)")
    }

    /// How far below the first text the second one is on the first page
    private static func distance(from first: String, to second: String, in pdf: PDFDocument) -> CGFloat? {
        guard let page = pdf.page(at: 0),
              let upper = pdf.findString(first, withOptions: []).first,
              let lower = pdf.findString(second, withOptions: []).first else { return nil }
        return upper.bounds(for: page).minY - lower.bounds(for: page).minY
    }
}

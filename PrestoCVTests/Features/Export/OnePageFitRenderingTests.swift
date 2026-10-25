import Testing
import Foundation
import PDFKit
@testable import CVPDFExporter

extension RealRendererSuites {
    /// When the iOS renderer prints a document tightened onto one page, and when it prints it as it lays itself out.
    /// The documents are blocks of a fixed height, with rules of their own under `fit-one-page` and under
    /// `fit-one-page-compact`: how many blocks there are and how much the rules take off says how many pages each print takes.
    @MainActor
    @Suite("One page fit in the iOS renderer", .serialized, .timeLimit(.minutes(2)))
    struct OnePageFitRenderingTests {

        private static let options = ExportOptions(pageSize: .a4, margins: .uniform(43), maxPages: 10)

        /// `count` blocks of 100 pixels, each `tightened` pixels high under the tightening rules, and `compact` pixels
        /// high under the compact ones, when a height is given
        private static func document(blocks count: Int, tightened: Int, compact: Int? = nil) -> String {
            let blocks = (1...count).map { "<div class=\"block\">Block \($0)</div>" }.joined(separator: "\n")
            let compactRule = compact.map { "html.\(OnePageFit.className).\(OnePageFit.compactClassName) .block { height: \($0)px; }" } ?? ""
            return """
            <!DOCTYPE html>
            <html lang="en">
            <head>
            <style>
                * { margin: 0; padding: 0; }
                body { font: 12px -apple-system, sans-serif; }
                .block { height: 100px; break-inside: avoid; }
                html.\(OnePageFit.className) .block { height: \(tightened)px; }
                \(compactRule)
            </style>
            </head>
            <body>
            \(blocks)
            </body>
            </html>
            """
        }

        private static func render(_ html: String, fit: OnePageFit = OnePageFit()) async throws -> PDFDocument {
            let data = try await ExportTestEnvironment.makeRenderer(onePageFit: fit).renderToPDF(html: html, options: options)
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

        @Test("a document that only the compact step brings onto one page is printed on one page")
        func compactStepBringsItOntoOnePage() async throws {
            let pdf = try await Self.render(Self.document(blocks: 12, tightened: 80, compact: 50))

            #expect(pdf.pageCount == 1)
            #expect(Self.pageNumber(of: "Block 12", in: pdf) == 1)
        }

        @Test("the lightest step that brings a document onto one page is the one that is kept")
        func lightestStepWins() async throws {
            let withCompactRules = try await Self.render(Self.document(blocks: 12, tightened: 50, compact: 30))
            let withoutCompactRules = try await Self.render(Self.document(blocks: 12, tightened: 50))

            #expect(withCompactRules.pageCount == 1)
            let height = try #require(Self.distance(from: "Block 1", to: "Block 3", in: withCompactRules))
            let tightenedHeight = try #require(Self.distance(from: "Block 1", to: "Block 3", in: withoutCompactRules))
            #expect(abs(height - tightenedHeight) < 1, "Two blocks take \(height) points instead of \(tightenedHeight)")
        }

        @Test("a document that no step brings onto one page is printed as it lays itself out")
        func noStepKeepsTheLayout() async throws {
            let pdf = try await Self.render(Self.document(blocks: 16, tightened: 80, compact: 70))
            let asItLaysItself = try await Self.render(Self.document(blocks: 16, tightened: 80, compact: 70), fit: .disabled)

            #expect(pdf.pageCount == 2)
            #expect(Self.pageNumber(of: "Block 11", in: pdf) == Self.pageNumber(of: "Block 11", in: asItLaysItself))
            #expect(Self.pageNumber(of: "Block 11", in: pdf) == 2)
        }

        @Test("a renderer without steps prints a document of two pages as it lays itself out")
        func disabledKeepsTheLayout() async throws {
            let pdf = try await Self.render(Self.document(blocks: 12, tightened: 50, compact: 30), fit: .disabled)

            #expect(pdf.pageCount == 2)
        }

        // MARK: - The margin at the foot of the page

        /// A document of one block, `height` points tall in the print
        private static func tallDocument(height: Double, pointsPerPixel: Double) -> String {
            """
            <!DOCTYPE html>
            <html lang="en">
            <head>
            <style>
                * { margin: 0; padding: 0; }
                body { font: 12px -apple-system, sans-serif; }
                .tall { height: \(height / pointsPerPixel)px; }
            </style>
            </head>
            <body><div class="tall">Tall block</div></body>
            </html>
            """
        }

        /// How many points a pixel of the page takes in the print: the print scales the page to the width between the margins
        private static func pointsPerPixel() async throws -> Double {
            let pdf = try await render(document(blocks: 3, tightened: 100), fit: .disabled)
            let twoBlocks = try #require(distance(from: "Block 1", to: "Block 3", in: pdf))
            return Double(twoBlocks) / 200
        }

        @Test("the margin at the foot of the page gives way in a step that shrinks it, and not below its minimum")
        func footMarginGivesWayDownToItsMinimum() async throws {
            let pointsPerPixel = try await Self.pointsPerPixel()
            let usual = Self.options.pageSize.height - 2 * Self.options.margins.top
            let shrunk = Self.options.pageSize.height - Self.options.margins.top - OnePageFit.minimumBottomMargin
            let shrinking = OnePageFit(steps: [.init(classNames: [OnePageFit.className], shrinksBottomMargin: true)])
            let keeping = OnePageFit(steps: [.init(classNames: [OnePageFit.className], shrinksBottomMargin: false)])

            // Taller than a page with its usual foot margin, and no taller than a page with the smallest
            let betweenTheTwo = Self.tallDocument(height: (usual + shrunk) / 2, pointsPerPixel: pointsPerPixel)
            let tooTall = Self.tallDocument(height: shrunk + 12, pointsPerPixel: pointsPerPixel)

            #expect(try await Self.render(betweenTheTwo, fit: .disabled).pageCount == 2)
            #expect(try await Self.render(betweenTheTwo, fit: keeping).pageCount == 2)
            #expect(try await Self.render(betweenTheTwo, fit: shrinking).pageCount == 1)
            #expect(try await Self.render(tooTall, fit: shrinking).pageCount == 2, "The foot margin does not shrink below its minimum")
        }

        /// How far below the first text the second one is on the first page
        private static func distance(from first: String, to second: String, in pdf: PDFDocument) -> CGFloat? {
            guard let page = pdf.page(at: 0),
                  let upper = pdf.findString(first, withOptions: []).first,
                  let lower = pdf.findString(second, withOptions: []).first else { return nil }
            return upper.bounds(for: page).minY - lower.bounds(for: page).minY
        }
    }
}

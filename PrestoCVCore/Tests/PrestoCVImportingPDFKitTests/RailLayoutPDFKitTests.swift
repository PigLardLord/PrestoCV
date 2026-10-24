#if canImport(PDFKit)
import CoreText
import Foundation
import PDFKit
import Testing
import PrestoCVImporting
import PrestoCVImportingPDFKit

/// A CV drawn as a PDF when the test runs, its section headings bold and right-aligned in a narrow column on the left,
/// each beside the first line of its section, ten points off the heading's right edge (#287): the words, boxes and
/// weights that PDFKit reads from the page are what the import reads the sections from. Every CV here is invented.
@Suite("Reading a CV with its headings in a column beside the sections with PDFKit")
struct RailLayoutPDFKitTests {

    private static let edge = CGFloat(162)
    private static let body = CGFloat(172)

    /// A line of the page: `heading` is drawn bold and right-aligned to the headings' column on the line's baseline.
    private struct Line {
        var heading: String?
        let text: String
        var bold = false
        var size: CGFloat = 9.3
        /// Where the text stands, when it is not the sections' column.
        var x: CGFloat?
        /// The text of a second cell, drawn from `x`.
        var cells: [(x: CGFloat, text: String, bold: Bool)] = []
        /// The space left above the line.
        var gap: CGFloat = 4
    }

    private func line(_ text: String, size: CGFloat, bold: Bool, face: DrawnFace) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: face.font(size, bold: bold)]))
    }

    private func draw(_ text: String, at x: CGFloat, baseline: CGFloat, size: CGFloat, bold: Bool, face: DrawnFace, in context: CGContext) {
        context.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(line(text, size: size, bold: bold, face: face), context)
    }

    /// A one-page PDF drawn when the test runs in `face`, its lines from the top of the page down.
    private func drawnPDF(_ lines: [Line], face: DrawnFace) throws -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        var top = CGFloat(40)
        for line in lines {
            top += line.gap + line.size
            let baseline = box.height - top
            if let heading = line.heading {
                let width = CGFloat(CTLineGetTypographicBounds(self.line(heading, size: 9.5, bold: true, face: face), nil, nil, nil))
                draw(heading, at: Self.edge - width, baseline: baseline, size: 9.5, bold: true, face: face, in: context)
            }
            draw(line.text, at: line.x ?? Self.body, baseline: baseline, size: line.size, bold: line.bold, face: face, in: context)
            for cell in line.cells {
                draw(cell.text, at: cell.x, baseline: baseline, size: line.size, bold: cell.bold, face: face, in: context)
            }
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    /// The CV: a header across the page, then each section with its heading beside its first line.
    private func cv(skillsHeading: String, skillsFirst: Bool) -> [Line] {
        let skills = [
            Line(heading: skillsHeading, text: "Languages", bold: true, cells: [(314, "Swift, Kotlin", false)], gap: 20),
            Line(text: "Frameworks", bold: true, cells: [(314, "SwiftUI, Combine", false)], gap: 12),
            Line(text: "Platforms", bold: true, cells: [(314, "Docker, AWS", false)], gap: 12),
        ]
        let experience = [
            Line(heading: "Work Experience", text: "Software Engineer", bold: true, size: 11.5, gap: 20),
            Line(text: "Example Ltd, Leeds", bold: true, size: 9.5),
            Line(text: "03/2019 – 05/2024", size: 9),
            Line(text: "Built the billing service for retail customers."),
            Line(text: "Moved the checkout to a new payment provider."),
            Line(text: "Taught two colleagues how to review code."),
        ]
        return [
            Line(text: "Alex Example", bold: true, size: 22, x: 46, gap: 0),
            Line(text: "Software Engineer", bold: true, size: 12, x: 46, gap: 4),
            Line(text: "alex.example@example.org · Leeds, United Kingdom", size: 9, x: 46, gap: 4),
        ] + (skillsFirst ? skills + experience : experience + skills) + [
            Line(heading: "Education", text: "BSc Computer Science", bold: true, gap: 20),
            Line(text: "University of Example · 2012 – 2016", size: 9),
            Line(heading: "Languages", text: "English: C1", bold: true, gap: 20),
            Line(text: "German: B2", bold: true, gap: 8),
        ]
    }

    private func importer() -> ImportCV {
        ImportCV(pdfReader: PDFKitTextExtractor(), limits: .standard)
    }

    @Test("A drawn PDF with its headings in a column beside the sections has every section read", arguments: DrawnFace.allCases, [true, false])
    func wholeCV(face: DrawnFace, skillsFirst: Bool) async throws {
        for heading in ["Core Technologies", "Technologies", "Tools", "Technical Skills"] {
            let result = try await importer().importPDF(drawnPDF(cv(skillsHeading: heading, skillsFirst: skillsFirst), face: face))
            let label = "\(face.testDescription), \(heading), skills first: \(skillsFirst)"
            #expect(result.cv.skills.map(\.value) == ["Swift", "Kotlin", "SwiftUI", "Combine", "Docker", "AWS"], "\(label): \(result.cv.skills.map(\.value))")
            #expect(result.cv.experience.map { $0.role?.value } == ["Software Engineer"], "\(label)")
            #expect(result.cv.experience.first?.employer?.value == "Example Ltd", "\(label)")
            #expect(result.cv.education.count == 1, "\(label): \(result.cv.education.count)")
            #expect(result.cv.languages.map(\.name.value) == ["English", "German"], "\(label): \(result.cv.languages.map(\.name.value))")
            #expect(result.unplaced.isEmpty, "\(label): text not imported: \(result.unplaced.map(\.text))")
        }
    }
}
#endif

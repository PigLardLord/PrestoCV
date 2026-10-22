#if canImport(PDFKit)
import CoreText
import Foundation
import PDFKit
import Testing
import PrestoCVImporting
import PrestoCVImportingPDFKit

/// A CV drawn as a PDF when the test runs, its skills under the headings that CVs give them (#287): the words, boxes
/// and weights that PDFKit reads from the page are what the import reads the skills from. Every CV here is invented.
@Suite("Reading the skills of a drawn CV with PDFKit")
struct SkillsHeadingsPDFKitTests {

    /// The headings of the skills in the six languages, as the vocabulary lists them for each one.
    static let headings: [String] = [
        "Technologies", "Tech stack", "Tools", "Technical skills", "Core skills", "Key skills", "Competencies",
        "Competenze tecniche", "Conoscenze informatiche", "Tecnologie", "Strumenti",
        "Kenntnisse", "Technische Kenntnisse", "IT-Kenntnisse", "Technologien",
        "Compétences techniques", "Outils", "Stack technique",
        "Conocimientos técnicos", "Herramientas", "Tecnologías",
        "Competências técnicas", "Ferramentas", "Tecnologias",
    ]

    private struct Line {
        let text: String
        let bold: Bool
        let size: CGFloat
        /// The space left above the line.
        let gap: CGFloat
    }

    /// A one-page PDF drawn when the test runs, its lines from the top of the page down, in Helvetica.
    private func drawnPDF(_ lines: [Line]) throws -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        var top = CGFloat(50)
        for line in lines {
            top += line.gap + line.size
            let font = CTFontCreateWithName((line.bold ? "Helvetica-Bold" : "Helvetica") as CFString, line.size, nil)
            let drawn = CTLineCreateWithAttributedString(NSAttributedString(string: line.text, attributes: [.font: font]))
            context.textPosition = CGPoint(x: 50, y: box.height - top)
            CTLineDraw(drawn, context)
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    /// The CV: a name, a job, and the skills under `heading`.
    private func cv(skillsHeading heading: String) -> [Line] {
        [
            Line(text: "Alex Example", bold: true, size: 20, gap: 0),
            Line(text: "Software Engineer", bold: false, size: 11, gap: 6),
            Line(text: "Experience", bold: true, size: 13, gap: 24),
            Line(text: "Software Engineer, Example Ltd", bold: true, size: 11, gap: 8),
            Line(text: "03/2019 – 05/2024", bold: false, size: 10, gap: 3),
            Line(text: heading, bold: true, size: 13, gap: 24),
            Line(text: "Swift, SwiftUI, Combine", bold: false, size: 10, gap: 8),
            Line(text: "Kotlin; Docker", bold: false, size: 10, gap: 3),
        ]
    }

    private func importer() -> ImportCV {
        ImportCV(pdfReader: PDFKitTextExtractor(), limits: .standard)
    }

    @Test("A drawn PDF with its skills under the heading, bold or in capitals, has them read as skills", arguments: headings)
    func skillsUnderTheHeading(heading: String) async throws {
        for form in [heading, heading.uppercased()] {
            let result = try await importer().importPDF(drawnPDF(cv(skillsHeading: form)))
            #expect(result.cv.skills.map(\.value) == ["Swift", "SwiftUI", "Combine", "Kotlin", "Docker"], "\(form)")
            #expect(result.unplaced.isEmpty, "\(form): text not imported: \(result.unplaced.map(\.text))")
            #expect(result.cv.experience.count == 1, "\(form): the skills must not go into the experience")
        }
    }

    @Test("A drawn PDF with a sentence of a job that holds the word of a heading has no skills")
    func sentenceWithTheWord() async throws {
        let lines = [
            Line(text: "Alex Example", bold: true, size: 20, gap: 0),
            Line(text: "Experience", bold: true, size: 13, gap: 24),
            Line(text: "Software Engineer, Example Ltd", bold: true, size: 11, gap: 8),
            Line(text: "03/2019 – 05/2024", bold: false, size: 10, gap: 3),
            Line(text: "Built internal tools for the support team", bold: false, size: 10, gap: 3),
        ]
        let result = try await importer().importPDF(drawnPDF(lines))
        #expect(result.cv.skills.isEmpty, "\(result.cv.skills.map(\.value))")
        #expect(result.cv.experience.count == 1)
    }
}
#endif

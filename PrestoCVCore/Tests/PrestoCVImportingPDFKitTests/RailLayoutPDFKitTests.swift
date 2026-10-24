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
        /// The grey of a band behind the foot of the line.
        var shade: CGFloat?
    }

    /// How the section headings are drawn: in a grey, and crossed by a black hairline.
    private struct Headings {
        var gray: CGFloat = 0
        var hairline: DrawnShade.Hairline?
    }

    private func line(_ text: String, size: CGFloat, bold: Bool, face: DrawnFace, gray: CGFloat = 0) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: face.font(size, bold: bold),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: gray, alpha: 1),
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    private func draw(_ text: String, at x: CGFloat, baseline: CGFloat, size: CGFloat, bold: Bool, face: DrawnFace, in context: CGContext) {
        context.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(line(text, size: size, bold: bold, face: face), context)
    }

    /// A one-page PDF drawn when the test runs in `face`, its lines from the top of the page down.
    private func drawnPDF(_ lines: [Line], face: DrawnFace, headings: Headings = Headings()) throws -> Data {
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
                let drawn = self.line(heading, size: 9.5, bold: true, face: face, gray: headings.gray)
                let origin = CGPoint(x: Self.edge - CGFloat(CTLineGetTypographicBounds(drawn, nil, nil, nil)), y: baseline)
                context.textPosition = origin
                CTLineDraw(drawn, context)
                if let hairline = headings.hairline {
                    DrawnShade.hairline(hairline, across: drawn, at: origin, size: 9.5, in: context)
                }
            }
            if let shade = line.shade {
                let origin = CGPoint(x: line.x ?? Self.body, y: baseline)
                DrawnShade.fill(shade, reach: .foot, behind: self.line(line.text, size: line.size, bold: line.bold, face: face), at: origin, size: line.size, in: context)
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
    private func cv(skillsHeading: String, skillsFirst: Bool, employer: Line = Line(text: "Example Ltd, Leeds", bold: true, size: 9.5)) -> [Line] {
        let skills = [
            Line(heading: skillsHeading, text: "Languages", bold: true, cells: [(314, "Swift, Kotlin", false)], gap: 20),
            Line(text: "Frameworks", bold: true, cells: [(314, "SwiftUI, Combine", false)], gap: 12),
            Line(text: "Platforms", bold: true, cells: [(314, "Docker, AWS", false)], gap: 12),
        ]
        let experience = [
            Line(heading: "Work Experience", text: "Software Engineer", bold: true, size: 11.5, gap: 20),
            employer,
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

    @Test("A regular employer line on a band behind its foot is read as the employer: the band is not ink of the letters",
          arguments: DrawnFace.allCases, [nil, 0.63, 0.8] as [CGFloat?])
    func employerOnABand(face: DrawnFace, gray: CGFloat?) async throws {
        // An employer of capitals alone on a line is read as a heading when it is bold, which is what a band would make it
        let employer = Line(text: "ACME", size: 9.5, shade: gray)
        let result = try await importer().importPDF(drawnPDF(cv(skillsHeading: "Technologies", skillsFirst: false, employer: employer), face: face))
        let label = "\(face.testDescription), band \(String(describing: gray))"
        #expect(result.cv.experience.map { $0.role?.value } == ["Software Engineer"], "\(label): \(result.cv.experience.map { $0.role?.value })")
        #expect(result.cv.experience.first?.employer?.value == "ACME", "\(label): \(String(describing: result.cv.experience.first?.employer?.value))")
        #expect(result.cv.skills.count == 6, "\(label): \(result.cv.skills.count)")
        #expect(result.unplaced.isEmpty, "\(label): text not imported: \(result.unplaced.map(\.text))")
    }

    @Test("Grey headings crossed by a black hairline are bold, and their sections are read: the hairline is not the letters' ink",
          arguments: DrawnFace.allCases, DrawnShade.Hairline.allCases)
    func greyHeadingsCrossedByAHairline(face: DrawnFace, hairline: DrawnShade.Hairline) async throws {
        let pdf = try drawnPDF(cv(skillsHeading: "Technologies", skillsFirst: false), face: face, headings: Headings(gray: 0.31, hairline: hairline))
        let label = "\(face.testDescription), \(hairline.testDescription)"
        guard case .pages(let pages) = try await PDFKitTextExtractor().layout(ofPDF: pdf, limits: .standard) else {
            Issue.record("\(label): no pages")
            return
        }
        // The headings stand under the header, in the column left of the sections ("Languages" is also a row of the skills)
        let headings = pages.flatMap(\.words).filter { $0.frame.y > 100 && $0.frame.maxX <= Self.edge + 1 }
        #expect(headings.map(\.text).sorted() == ["Education", "Experience", "Languages", "Technologies", "Work"], "\(label): \(headings.map(\.text))")
        #expect(headings.allSatisfy { $0.isBold }, "\(label): \(headings.map { "\($0.text) \($0.isBold)" })")
        let result = try await importer().importPDF(pdf)
        #expect(result.cv.skills.map(\.value) == ["Swift", "Kotlin", "SwiftUI", "Combine", "Docker", "AWS"], "\(label): \(result.cv.skills.map(\.value))")
        #expect(result.cv.experience.map { $0.role?.value } == ["Software Engineer"], "\(label)")
        #expect(result.cv.education.count == 1, "\(label): \(result.cv.education.count)")
        #expect(result.cv.languages.map(\.name.value) == ["English", "German"], "\(label): \(result.cv.languages.map(\.name.value))")
        #expect(result.unplaced.isEmpty, "\(label): text not imported: \(result.unplaced.map(\.text))")
    }
}
#endif

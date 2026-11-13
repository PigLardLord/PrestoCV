import Foundation
import Testing
@testable import PrestoCVImporting

/// A heading the vocabulary does not know ("OWN VENTURES"), written in the look of the headings it knows, opens a section
/// of its own: its lines stay visible as text not imported under that heading, and are not read as jobs of the section
/// before it (ADR 0027). Only the known headings vouch for it, never the lines that could be headings themselves.
@Suite("An unknown heading in the look of the known ones (#454)")
struct UnknownHeadingTests {

    private func importText(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
    }

    private func importPDF(_ sketch: PageSketch) async throws -> ImportResult {
        try await ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([sketch.page])), limits: .standard).importPDF(Data([1]))
    }

    // MARK: The CV of the issue

    /// The lines of the CV, each with whether it is a heading.
    private static let lines: [(text: String, isHeading: Bool)] = [
        ("iOS Engineer", false),
        ("tobias.renn@example.com · Leipzig, Germany", false),
        ("SUMMARY", true),
        ("iOS engineer with ten years of apps for field teams.", false),
        ("EXPERIENCE", true),
        ("Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany", false),
        ("July 2017 – Present · Cloud tools for logistics teams", false),
        ("• Led the move to SwiftUI.", false),
        ("• Built the offline sync engine.", false),
        ("Mobile Developer — Northwind Labs, Lucca, Italy", false),
        ("May 2014 – June 2017 · Field service app for retail teams", false),
        ("• Built the offline order screens.", false),
        ("• Wrote the release scripts for the store builds.", false),
        ("OWN VENTURES", true),
        ("Tidepool Notes — maker, solo", false),
        ("2022 – Present · a markdown notes app for iPad", false),
        ("• Designed and shipped the app on the App Store.", false),
        ("Harbor Timer — co-founder", false),
        ("2018 – 2019 · a shift timer for dock workers", false),
        ("• Wrote the watch app.", false),
        ("SKILLS", true),
        ("Swift, SwiftUI, Combine", false),
        ("LANGUAGES", true),
        ("German — native", false),
        ("English — fluent", false),
    ]

    /// The words of the six lines under OWN VENTURES, without their bullets.
    private static let ventures = [
        "Tidepool Notes — maker, solo",
        "2022 – Present · a markdown notes app for iPad",
        "Designed and shipped the app on the App Store.",
        "Harbor Timer — co-founder",
        "2018 – 2019 · a shift timer for dock workers",
        "Wrote the watch app.",
    ]

    /// The CV as pasted text; with `blankLines`, a blank line before each heading.
    private static func pastedCV(blankLines: Bool) -> String {
        var text = ["Tobias Renn"]
        for line in lines {
            if line.isHeading, blankLines { text.append("") }
            text.append(line.text)
        }
        return text.joined(separator: "\n")
    }

    /// The CV drawn on a page: every line at the same x, the headings at 11 pt over a body of 10 pt (not emphasized),
    /// not bold, after a wider gap.
    private static func drawnCV() -> PageSketch {
        var sketch = PageSketch()
        sketch.put("Tobias Renn", x: 50, y: 50, size: 20, bold: true)
        var y = 80.0
        for line in lines {
            if line.isHeading { y += 18 }
            sketch.put(line.text, x: 50, y: y, size: line.isHeading ? 11 : 10)
            y += line.isHeading ? 15 : 14
        }
        return sketch
    }

    /// Checks the import of the issue's CV: two jobs, the six lines under OWN VENTURES as text not imported with that
    /// heading, the skills and the languages read, nothing lost.
    private func expectTheVenturesStayVisible(_ result: ImportResult, _ label: String) {
        let jobs = result.cv.experience
        #expect(jobs.count == 2, "\(label): \(jobs.map { [$0.role?.value, $0.employer?.value] })")
        let jobTexts = jobs.flatMap { job in
            [job.role?.value, job.employer?.value, job.location?.value].compactMap { $0 } + job.details.map(\.value)
        }
        for word in ["Tidepool", "Harbor", "VENTURES", "markdown", "watch app"] {
            #expect(!jobTexts.contains { $0.contains(word) }, "\(label): \(word) in a job: \(jobTexts)")
        }
        let underVentures = result.unplaced.filter { $0.heading == "OWN VENTURES" }.map(\.text).joined(separator: "\n")
        for line in Self.ventures {
            #expect(underVentures.contains(line), "\(label): «\(line)» not under OWN VENTURES: \(result.unplaced.map { ($0.heading, $0.text) })")
        }
        #expect(result.cv.skills.map(\.value).contains("Swift"), "\(label): \(result.cv.skills.map(\.value))")
        #expect(result.cv.languages.count == 2, "\(label): \(result.cv.languages.map(\.name.value))")
        #expect(Coverage.lost(result).isEmpty, "\(label): \(Coverage.describe(Coverage.lost(result)))")
    }

    @Test("Pasted without blank lines, as in the issue: the ventures are a section of their own, not jobs")
    func pastedWithoutBlankLines() throws {
        expectTheVenturesStayVisible(try importText(Self.pastedCV(blankLines: false)), "no blank lines")
    }

    @Test("Pasted with a blank line before each heading: the ventures are a section of their own, not jobs")
    func pastedWithBlankLines() throws {
        expectTheVenturesStayVisible(try importText(Self.pastedCV(blankLines: true)), "blank lines")
    }

    @Test("Drawn in a PDF, the headings a size larger than the text but not emphasized: the ventures are a section of their own")
    func drawnInAPDF() async throws {
        expectTheVenturesStayVisible(try await importPDF(Self.drawnCV()), "PDF")
    }

    // MARK: What does not open a section

    private func kinds(_ text: String) -> [SectionKind] {
        pasted(text).1.map(\.kind)
    }

    @Test("An employer in capitals on a line of its own, above each job, opens no section")
    func employersInCapitals() throws {
        let text = """
        Tobias Renn
        iOS Engineer
        tobias.renn@example.com

        EXPERIENCE
        KESTREL CLOUD GMBH
        Senior iOS Engineer
        July 2017 – Present
        • Led the move to SwiftUI.

        NORTHWIND LABS
        Mobile Developer
        May 2014 – June 2017
        • Built the offline order screens.

        SKILLS
        Swift, SwiftUI

        LANGUAGES
        German — native
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
        let result = try importText(text)
        #expect(result.cv.experience.count == 2, "\(result.cv.experience.map { [$0.role?.value, $0.employer?.value] })")
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.describe(Coverage.lost(result)))")
    }

    @Test("One known heading in capitals vouches for nothing")
    func oneKnownHeading() {
        let text = """
        Tobias Renn
        iOS Engineer

        EXPERIENCE
        Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
        July 2017 – Present
        • Led the move to SwiftUI.

        OWN VENTURES
        Tidepool Notes — maker, solo
        • Designed and shipped the app on the App Store.

        Skills
        Swift, SwiftUI
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
    }

    @Test("A line in capitals followed by a period is a job, not a heading")
    func capitalsBeforeAPeriod() {
        let text = """
        Tobias Renn
        iOS Engineer

        EXPERIENCE
        Kestrel Cloud — Leipzig, Germany
        • Led the move to SwiftUI.

        PLATFORM ENGINEER
        July 2017 – Present
        • Built the offline sync engine.

        SKILLS
        Swift

        LANGUAGES
        German — native
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
    }

    @Test("Sub-headings in capitals inside a section open no section")
    func subHeadingsInCapitals() {
        #expect(SectionVocabulary.kind(ofHeading: "TECHNICAL") == nil)
        #expect(SectionVocabulary.kind(ofHeading: "LEADERSHIP") == nil)
        let text = """
        Tobias Renn
        iOS Engineer

        EXPERIENCE
        Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
        July 2017 – Present

        SKILLS

        TECHNICAL
        Swift, SwiftUI

        LEADERSHIP
        Mentoring, hiring

        LANGUAGES
        German — native
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
    }

    @Test("An acronym in capitals inside a section opens no section")
    func acronym() {
        let text = """
        Tobias Renn
        iOS Engineer

        EXPERIENCE
        Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
        July 2017 – Present

        SKILLS
        Swift
        Kotlin

        HTML
        CSS

        LANGUAGES
        German — native
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
    }

    @Test("A title in capitals in the head of the CV opens no section")
    func titleInCapitals() {
        let text = """
        TOBIAS RENN

        MOBILE ENGINEER
        tobias.renn@example.com

        SUMMARY
        iOS engineer with ten years of apps for field teams.

        EXPERIENCE
        Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
        July 2017 – Present

        SKILLS
        Swift
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
    }

    @Test("A line in capitals without the gap the known headings have opens no section")
    func gapDiffers() {
        let text = """
        Tobias Renn
        iOS Engineer

        EXPERIENCE
        Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
        July 2017 – Present
        • Led the move to SwiftUI.
        OWN VENTURES
        Tidepool Notes — maker, solo
        • Designed and shipped the app on the App Store.

        SKILLS
        Swift, SwiftUI

        LANGUAGES
        German — native
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
    }
}

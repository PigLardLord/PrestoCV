import Testing
import Foundation
import CVDocumentModel
import CVDesignCatalog
@testable import CVRendering
import CVRenderingTestSupport
import CVBundledHeadings

/// The naive reader of a printed CV (#121), tried on the text of the document itself, one text node per line, which is
/// what a design that keeps each field on its own line prints. The reading of real PDFs runs on macOS.
@Suite("A naive parser reads the text a CV prints (#121)")
struct AtsTextReaderTests {
    static let catalog = HeadingsCatalog(source: BundleHeadingTableSource())

    static func lines(_ document: CVDocument) throws -> [String] {
        let headings = try catalog.headings(for: document.language)
        return DocumentHTMLBuilder().render(document, stylesheet: try stylesheet(), palette: palette, headings: headings).textNodes
    }

    static func read(_ lines: [String], of document: CVDocument = AtsFixture.document(language: "en")) throws -> AtsReading {
        AtsReading(text: lines.joined(separator: "\n"), document: document, headings: try catalog.headings(for: document.language))
    }

    @Test("a document printed one field per line passes every floor with a full score, in each language", arguments: AtsFixture.languages)
    func intact(language: String) throws {
        let document = AtsFixture.document(language: language)
        let reading = try Self.read(try Self.lines(document), of: document)
        #expect(reading.failedFloors.isEmpty && reading.score == 1, "\(language): \(reading.failedFloors) \(reading.score)")
    }

    @Test("a section whose heading is lost, or comes out of order, fails the sections floor")
    func sections() throws {
        let lines = try Self.lines(AtsFixture.document(language: "en"))
        #expect(try Self.read(lines.filter { $0 != "Education" }).failedFloors.contains(.sections))
        let swapped = lines.map { $0 == "Skills" ? "Education" : $0 == "Education" ? "Skills" : $0 }
        #expect(try Self.read(swapped).failedFloors.contains(.sections))
    }

    @Test("a lost email fails the email floor, and the others hold")
    func email() throws {
        let lines = try Self.lines(AtsFixture.document(language: "en")).filter { $0 != "marta.bellini@example.org" }
        #expect(try Self.read(lines).failedFloors == [.email])
    }

    @Test("a role cut off from its employer or from its period fails the roles floor")
    func roles() throws {
        let lines = try Self.lines(AtsFixture.document(language: "en"))
        let at = try #require(lines.firstIndex(of: "Quality engineer"))
        var farFromPeriod = lines
        farFromPeriod.insert(contentsOf: ["a", "b", "c", "d"], at: at + 2)
        #expect(try Self.read(farFromPeriod).failedFloors == [.roles])
        var merged = lines
        merged.replaceSubrange(at...(at + 1), with: ["Quality engineer Pasta Dorata"])
        #expect(try Self.read(merged).failedFloors == [.roles])
    }

    @Test("roles printed out of chronological order fail the chronology floor")
    func chronology() throws {
        var document = AtsFixture.document(language: "en")
        guard case .experience(var roles)? = document.sections.dropFirst().first else { Issue.record("no experience"); return }
        roles.swapAt(0, 1)
        document.sections[1] = .experience(roles)
        #expect(try Self.read(try Self.lines(document)).failedFloors == [.chronology])
    }

    @Test("the score counts the fields a text holds, and a floor can fail while it stays high")
    func score() throws {
        let lines = try Self.lines(AtsFixture.document(language: "en")).filter { $0 != "Hiking" }
        let reading = try Self.read(lines)
        #expect(reading.recovered == reading.expected - 1 && reading.score < 1 && reading.score > 0.9)
    }
}

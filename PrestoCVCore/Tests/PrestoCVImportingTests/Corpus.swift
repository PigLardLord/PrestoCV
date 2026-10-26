import Foundation
@testable import PrestoCVImporting

/// The synthetic corpus of `ImportFixtures`, read from the test bundle (R16).
enum Corpus {
    struct Entry: Decodable {
        let id: String
        let language: String
        let form: String
        let kind: String
        let source: String
        let expected: String
        let pdf: String?
    }

    struct Expected: Decodable {
        struct Person: Decodable {
            let name: String?
            let title: String?
            let email: String?
            let phone: String?
            let location: String?
            let links: [String]
            let summary: String?
        }
        struct Period: Decodable, Equatable {
            let start: [Int?]
            let end: End
        }
        enum End: Decodable, Equatable {
            case current
            case date([Int?])
            /// A single date: the text states no range.
            case none

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if container.decodeNil() {
                    self = .none
                } else if let text = try? container.decode(String.self), text == "current" {
                    self = .current
                } else {
                    self = .date(try container.decode([Int?].self))
                }
            }
        }
        struct Experience: Decodable {
            let role: String?
            let employer: String?
            let location: String?
            let start: [Int?]
            let end: End
            let details: Int
        }
        struct Education: Decodable {
            let degree: String?
            let school: String?
            let location: String?
            let start: [Int?]
            let end: End
        }
        struct Language: Decodable {
            let name: String
            let level: String?
        }
        struct Certification: Decodable {
            let name: String
            let issuer: String?
            let year: Int?
        }

        let id: String
        let language: String
        let form: String
        let person: Person
        let experience: [Experience]
        let education: [Education]
        let skills: [String]
        let languages: [Language]
        let certifications: [Certification]
        let interests: [String]
    }

    /// The words of a layout as the generator wrote them: short keys keep the files small.
    private struct CompactLayout: Decodable {
        struct Page: Decodable {
            let width: Double
            let height: Double
            let words: [Word]
        }
        struct Word: Decodable {
            let t: String
            let x: Double
            let y: Double
            let w: Double
            let h: Double
            let s: Double
            let b: Bool
        }
        let pages: [Page]
    }

    static var directory: URL {
        get throws {
            guard let url = Bundle.module.url(forResource: "ImportFixtures", withExtension: nil) else {
                throw CocoaError(.fileNoSuchFile)
            }
            return url
        }
    }

    static func entries() throws -> [Entry] {
        try JSONDecoder().decode([Entry].self, from: Data(contentsOf: directory.appendingPathComponent("index.json")))
    }

    static func expected(of entry: Entry) throws -> Expected {
        try JSONDecoder().decode(Expected.self, from: Data(contentsOf: directory.appendingPathComponent(entry.expected)))
    }

    static func text(of entry: Entry) throws -> String {
        try String(contentsOf: directory.appendingPathComponent(entry.source), encoding: .utf8)
    }

    static func pages(of entry: Entry) throws -> [ExtractedPage] {
        let layout = try JSONDecoder().decode(CompactLayout.self, from: Data(contentsOf: directory.appendingPathComponent(entry.source)))
        return layout.pages.map { page in
            ExtractedPage(width: page.width, height: page.height, words: page.words.map {
                ExtractedWord(text: $0.t, frame: Rect(x: $0.x, y: $0.y, width: $0.w, height: $0.h), fontSize: $0.s, isBold: $0.b)
            })
        }
    }

    /// Imports a fixture, a text as pasted text and a layout as the PDF a reader that saw it gives.
    static func importResult(of entry: Entry) async throws -> ImportResult {
        if entry.kind == "text" { return try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(try text(of: entry)) }
        let reader = ScriptedPDFReader(layout: .pages(try pages(of: entry)))
        return try await ImportCV(pdfReader: reader, limits: .standard).importPDF(Data([1]))
    }
}

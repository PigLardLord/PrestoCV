import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// The PDF of a CV is named in the language it is printed in, by the naming rule of PrestoCVDomain, with the pattern
/// the app's catalog has for that language.
@Suite("ExportFileName Tests")
struct ExportFileNameTests {

    private static let patterns: [DocumentLanguage: String] = [.english: "%@ – CV", .german: "%@ – Lebenslauf", .portuguese: "%@ – Currículo"]
    private let fileNames = ExportFileName(titlePattern: { ExportFileNameTests.patterns[$0] ?? "%@ – CV" })

    private func cv(printedIn language: DocumentLanguage?) -> CVModel {
        CVModel(name: "Analyst", personalInfo: PersonalInfo(name: "Ada Lovelace"), documentLanguage: language?.rawValue)
    }

    // MARK: - The language of the PDF

    @Test("the file and the title are named in the language the CV is printed in", arguments: [
        (DocumentLanguage.german, "Ada Lovelace – Lebenslauf"),
        (.portuguese, "Ada Lovelace – Currículo"),
        (.english, "Ada Lovelace – CV"),
    ])
    func namedInThePrintedLanguage(language: DocumentLanguage, title: String) {
        #expect(fileNames.title(for: cv(printedIn: language)) == title)
        #expect(fileNames.fileName(for: cv(printedIn: language)) == "\(title).pdf")
    }

    @Test("a CV without a language of its own is named in English")
    func namedInEnglishWithoutLanguage() {
        #expect(fileNames.fileName(for: cv(printedIn: nil)) == "Ada Lovelace – CV.pdf")
    }

    @Test("the app reads the pattern of each language of the PDF from its catalog, whatever language it is shown in",
          arguments: [(DocumentLanguage.english, "%@ – CV"), (.german, "%@ – Lebenslauf"), (.portuguese, "%@ – Currículo"),
                      (.italian, "%@ – CV"), (.spanish, "%@ – CV"), (.french, "%@ – CV")])
    func patternsComeFromTheCatalog(language: DocumentLanguage, pattern: String) {
        #expect(DocumentTitlePatterns(bundle: Bundle(for: AppRouter.self)).pattern(in: language) == pattern)
    }

    // MARK: - Writing the file

    /// Names that no file system accepts as they are, in the shapes that make a name long in bytes
    private static let hardNames: [String] = [
        String(repeating: "👩‍💻", count: 100),
        String(repeating: "e\u{0301}", count: 300),
        String(repeating: "漢", count: 300),
        String(repeating: "مرحبا ", count: 60),
        String(repeating: "กิจการ", count: 80),
        String(repeating: "🇮🇹", count: 120),
        String(repeating: "A", count: 300),
        "a" + String(repeating: "\u{0301}", count: 400),
        String(repeating: "/:*?\"<>|\\", count: 20)
    ]

    @Test("every file name writes and reads back, in any language of the PDF",
          arguments: [DocumentLanguage.english, .german, .portuguese], hardNames)
    func fileNamesCanBeWritten(language: DocumentLanguage, name: String) throws {
        let fileName = fileNames.fileName(for: CVModel(personalInfo: PersonalInfo(name: name), documentLanguage: language.rawValue))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let content = Data("%PDF".utf8)

        try content.write(to: folder.appendingPathComponent(fileName), options: .atomic)

        #expect(fileName.hasSuffix(".pdf") && !fileName.contains("/"))
        let listed = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(listed.map(\.precomposedStringWithCanonicalMapping) == [fileName.precomposedStringWithCanonicalMapping])
        #expect(try Data(contentsOf: folder.appendingPathComponent(fileName)) == content)
    }
}

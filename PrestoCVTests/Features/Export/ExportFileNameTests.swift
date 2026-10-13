import Testing
import Foundation
@testable import PrestoCV

@Suite("ExportFileName Tests")
struct ExportFileNameTests {

    private let english = ExportFileName(titlePattern: "%@ – CV")

    // MARK: - Naming

    @Test("the file is named after the person, with the localized pattern", arguments: [
        ("%@ – CV", "Ada Lovelace – CV.pdf"),
        ("%@ – Lebenslauf", "Ada Lovelace – Lebenslauf.pdf"),
        ("CV di %@", "CV di Ada Lovelace.pdf")
    ])
    func fileNameUsesThePattern(pattern: String, expected: String) {
        let fileName = ExportFileName(titlePattern: pattern).fileName(personName: "Ada Lovelace", cvName: "Analyst")

        #expect(fileName == expected)
    }

    @Test("the title is the file name without its extension")
    func titleHasNoExtension() {
        #expect(english.title(personName: "Ada Lovelace", cvName: "Analyst") == "Ada Lovelace – CV")
    }

    @Test("accented names are kept, in composed form")
    func accentsAreComposed() {
        let decomposed = "Zoe\u{0308} Rene\u{0301}e"

        let fileName = english.fileName(personName: decomposed, cvName: "")

        #expect(fileName == "Zo\u{00EB} Ren\u{00E9}e – CV.pdf")
        #expect(fileName.unicodeScalars.contains("\u{0308}") == false)
    }

    @Test("emoji are kept")
    func emojiAreKept() {
        #expect(english.fileName(personName: "Ada 👩‍💻", cvName: "") == "Ada 👩‍💻 – CV.pdf")
    }

    // MARK: - Cleaning

    @Test("characters that file systems reject are removed", arguments: [
        ("Ada/Lovelace", "AdaLovelace"),
        ("Ada\\Lovelace", "AdaLovelace"),
        ("Ada: <Lovelace>?", "Ada Lovelace"),
        ("\"Ada\" *Lovelace* | Byron", "Ada Lovelace Byron"),
        ("../../etc/passwd", "etcpasswd"),
        (".hidden", "hidden")
    ])
    func forbiddenCharactersAreRemoved(name: String, cleaned: String) {
        #expect(english.fileName(personName: name, cvName: "") == "\(cleaned) – CV.pdf")
    }

    @Test("line breaks and tabs separate words, other control characters disappear", arguments: [
        ("Ada\nLovelace", "Ada Lovelace"),
        ("Ada\r\nLovelace", "Ada Lovelace"),
        ("Ada\t\tLovelace", "Ada Lovelace"),
        ("Ada\u{0007}Lovelace", "AdaLovelace"),
        ("Ada\u{0000}Lovelace", "AdaLovelace"),
        ("Ada\u{202E}fdp.exe", "Adafdp.exe")
    ])
    func controlCharactersAreHandled(name: String, cleaned: String) {
        #expect(english.fileName(personName: name, cvName: "") == "\(cleaned) – CV.pdf")
    }

    @Test("runs of spaces collapse and the ends are trimmed")
    func whitespaceIsCollapsed() {
        #expect(english.fileName(personName: "  Ada    Lovelace  ", cvName: "") == "Ada Lovelace – CV.pdf")
    }

    @Test("a long name is cut to the maximum length")
    func longNamesAreCut() {
        let longName = String(repeating: "A", count: 300)

        let fileName = english.fileName(personName: longName, cvName: "")

        #expect(fileName == "\(String(repeating: "A", count: ExportFileName.maxNameLength)) – CV.pdf")
    }

    @Test("the cut does not leave a space at the end of the name")
    func cutNameHasNoTrailingSpace() {
        let name = String(repeating: "A", count: ExportFileName.maxNameLength - 1) + " B"

        let fileName = english.fileName(personName: name, cvName: "")

        #expect(fileName == "\(String(repeating: "A", count: ExportFileName.maxNameLength - 1)) – CV.pdf")
    }

    @Test("a name of characters that take many bytes is cut by bytes, between characters")
    func cutKeepsCharactersWhole() {
        let emoji = "👩‍💻"
        let name = String(repeating: emoji, count: 150)

        let fileName = english.fileName(personName: name, cvName: "")

        let kept = fileName.dropLast(" – CV.pdf".count)
        #expect(String(kept) == String(repeating: emoji, count: kept.count))
        #expect(!kept.isEmpty)
        #expect(fileName.utf8.count <= ExportFileName.maxFileNameBytes)
        #expect(fileName.utf8.count > ExportFileName.maxFileNameBytes - emoji.utf8.count)
    }

    @Test("a single character longer than the room for the name is left out, and the fallback used")
    func oversizedCharacterIsDropped() {
        let zalgo = "a" + String(repeating: "\u{0301}", count: 400)

        #expect(english.fileName(personName: zalgo, cvName: "") == "CV.pdf")
        #expect(english.fileName(personName: zalgo, cvName: "Backup") == "Backup – CV.pdf")
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

    @Test("every file name writes and reads back, in any language of the catalog",
          arguments: ["%@ – CV", "%@ – Lebenslauf", "%@ – Curriculum vitae"], hardNames)
    func fileNamesCanBeWritten(pattern: String, name: String) throws {
        let fileName = ExportFileName(titlePattern: pattern).fileName(personName: name, cvName: "")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let content = Data("%PDF".utf8)

        try content.write(to: folder.appendingPathComponent(fileName), options: .atomic)

        #expect(fileName.utf8.count <= ExportFileName.maxFileNameBytes)
        #expect(fileName.utf16.count <= ExportFileName.maxFileNameBytes)
        #expect(fileName.hasSuffix(".pdf"))
        #expect(!fileName.contains("/"))
        let listed = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(listed.map(\.precomposedStringWithCanonicalMapping) == [fileName.precomposedStringWithCanonicalMapping])
        #expect(try Data(contentsOf: folder.appendingPathComponent(fileName)) == content)
    }

    @Test("the whole file name stays within the bytes, whatever the pattern around the name")
    func patternCountsTowardsTheLimit() {
        let longPattern = "Curriculum vitae of %@, prepared for the application"
        let name = String(repeating: "漢", count: 300)

        let fileName = ExportFileName(titlePattern: longPattern).fileName(personName: name, cvName: "")

        #expect(fileName.utf8.count <= ExportFileName.maxFileNameBytes)
        #expect(fileName.hasPrefix("Curriculum vitae of 漢"))
    }

    // MARK: - Fallbacks

    @Test("an empty person name falls back to the name of the CV", arguments: ["", "   ", "\n", "/:*"])
    func fallsBackToCVName(personName: String) {
        #expect(english.fileName(personName: personName, cvName: "iOS Developer") == "iOS Developer – CV.pdf")
    }

    @Test("without any usable name the file is just CV", arguments: ["", " ", "///"])
    func fallsBackToCV(name: String) {
        #expect(english.fileName(personName: name, cvName: name) == "CV.pdf")
        #expect(english.title(personName: name, cvName: name) == "CV")
    }

    // MARK: - Catalog

    @Test("every language of the catalog has a title pattern with the name in it")
    func catalogPatternsContainTheName() throws {
        let catalogURL = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("PrestoCV/Localizable.xcstrings")
        let catalog = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        )
        let strings = try #require(catalog["strings"] as? [String: Any])
        let entry = try #require(strings["export.file_name"] as? [String: Any])
        let localizations = try #require(entry["localizations"] as? [String: [String: Any]])

        #expect(Set(localizations.keys) == ["de", "en", "es", "fr", "it", "pt"])
        for (language, localization) in localizations {
            let unit = localization["stringUnit"] as? [String: Any]
            let value = unit?["value"] as? String
            #expect(value?.contains("%@") == true, "\(language) pattern should contain %@")
        }
    }
}

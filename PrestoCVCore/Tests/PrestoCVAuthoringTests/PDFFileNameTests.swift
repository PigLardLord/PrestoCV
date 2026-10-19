import Testing
import PrestoCVDomain

@Suite("The name of an exported CV")
struct PDFFileNameTests {

    private let english = PDFFileName(titlePattern: "%@ – CV")

    // MARK: - Naming

    @Test("the file is named after the person, with the pattern of the PDF's language", arguments: [
        ("%@ – CV", "Ada Lovelace – CV.pdf"),
        ("%@ – Lebenslauf", "Ada Lovelace – Lebenslauf.pdf"),
        ("%@ – Currículo", "Ada Lovelace – Currículo.pdf"),
        ("CV di %@", "CV di Ada Lovelace.pdf"),
    ])
    func fileNameUsesThePattern(pattern: String, expected: String) {
        #expect(PDFFileName(titlePattern: pattern).fileName(personName: "Ada Lovelace", cvName: "Analyst") == expected)
    }

    @Test("the title is the file name without its extension")
    func titleHasNoExtension() {
        #expect(english.title(personName: "Ada Lovelace", cvName: "Analyst") == "Ada Lovelace – CV")
    }

    @Test("accented names are kept, in composed form")
    func accentsAreComposed() {
        let fileName = english.fileName(personName: "Zoe\u{0308} Rene\u{0301}e", cvName: "")

        #expect(fileName == "Zo\u{00EB} Ren\u{00E9}e – CV.pdf")
        #expect(!fileName.unicodeScalars.contains("\u{0308}"))
    }

    @Test("emoji are kept")
    func emojiAreKept() {
        #expect(english.fileName(personName: "Ada 👩‍💻", cvName: "") == "Ada 👩‍💻 – CV.pdf")
    }

    // MARK: - Cleaning

    @Test("characters that file systems reject are removed", arguments: [
        ("Ada/Lovelace", "AdaLovelace"), ("Ada\\Lovelace", "AdaLovelace"), ("Ada: <Lovelace>?", "Ada Lovelace"),
        ("\"Ada\" *Lovelace* | Byron", "Ada Lovelace Byron"), ("../../etc/passwd", "etcpasswd"), (".hidden", "hidden"),
    ])
    func forbiddenCharactersAreRemoved(name: String, cleaned: String) {
        #expect(english.fileName(personName: name, cvName: "") == "\(cleaned) – CV.pdf")
    }

    @Test("line breaks and tabs separate words, other control characters disappear", arguments: [
        ("Ada\nLovelace", "Ada Lovelace"), ("Ada\r\nLovelace", "Ada Lovelace"), ("Ada\t\tLovelace", "Ada Lovelace"),
        ("Ada\u{0007}Lovelace", "AdaLovelace"), ("Ada\u{0000}Lovelace", "AdaLovelace"), ("Ada\u{202E}fdp.exe", "Adafdp.exe"),
    ])
    func controlCharactersAreHandled(name: String, cleaned: String) {
        #expect(english.fileName(personName: name, cvName: "") == "\(cleaned) – CV.pdf")
    }

    @Test("runs of spaces collapse and the ends are trimmed")
    func whitespaceIsCollapsed() {
        #expect(english.fileName(personName: "  Ada    Lovelace  ", cvName: "") == "Ada Lovelace – CV.pdf")
    }

    @Test("a long name is cut to the maximum length, without a space at its end")
    func longNamesAreCut() {
        let max = PDFFileName.maxNameLength
        #expect(english.fileName(personName: String(repeating: "A", count: 300), cvName: "") == "\(String(repeating: "A", count: max)) – CV.pdf")
        #expect(english.fileName(personName: String(repeating: "A", count: max - 1) + " B", cvName: "")
                == "\(String(repeating: "A", count: max - 1)) – CV.pdf")
    }

    @Test("a name of characters that take many bytes is cut by bytes, between characters")
    func cutKeepsCharactersWhole() {
        let emoji = "👩‍💻"
        let fileName = english.fileName(personName: String(repeating: emoji, count: 150), cvName: "")

        let kept = fileName.dropLast(" – CV.pdf".count)
        #expect(String(kept) == String(repeating: emoji, count: kept.count))
        #expect(!kept.isEmpty)
        #expect(fileName.utf8.count <= PDFFileName.maxFileNameBytes)
        #expect(fileName.utf8.count > PDFFileName.maxFileNameBytes - emoji.utf8.count)
    }

    @Test("a single character longer than the room for the name is left out, and the fallback used")
    func oversizedCharacterIsDropped() {
        let zalgo = "a" + String(repeating: "\u{0301}", count: 400)

        #expect(english.fileName(personName: zalgo, cvName: "") == "CV.pdf")
        #expect(english.fileName(personName: zalgo, cvName: "Backup") == "Backup – CV.pdf")
    }

    @Test("every name stays within the bytes of a file name, whatever the pattern and the script", arguments: [
        "%@ – CV", "%@ – Lebenslauf", "Curriculum vitae of %@, prepared for the application",
    ], [
        String(repeating: "👩‍💻", count: 100), String(repeating: "e\u{0301}", count: 300), String(repeating: "漢", count: 300),
        String(repeating: "مرحبا ", count: 60), String(repeating: "กิจการ", count: 80), String(repeating: "🇮🇹", count: 120),
        String(repeating: "/:*?\"<>|\\", count: 20),
    ])
    func namesFitTheLimit(pattern: String, name: String) {
        let fileName = PDFFileName(titlePattern: pattern).fileName(personName: name, cvName: "")

        #expect(fileName.utf8.count <= PDFFileName.maxFileNameBytes)
        #expect(fileName.utf16.count <= PDFFileName.maxFileNameBytes)
        #expect(fileName.hasSuffix(".pdf") && !fileName.contains("/"))
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
}

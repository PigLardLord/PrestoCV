import Foundation
import Testing

// MARK: - Document Types Tests

/// The second app is among the apps another app can open a PDF in (step 5-13d of #404), as the released app is: as a
/// viewer at the alternate rank, so that it never becomes the one that opens PDFs by default, and a PDF it is handed is
/// a copy, never the file in place (ADR 0027). The app builds for macOS too, which rejects the key that asks iOS for a
/// copy as NO, so the project sets that key to NO for the iOS SDKs and to YES for macOS. A Debug build carries a PDF of
/// the corpus for the UI tests that open it; no Release build does.
@Suite("Document Types Tests")
struct DocumentTypesTests {

    private static let infoFile = "PrestoCVNext/Info.plist"
    private static let projectFile = "PrestoCV.xcodeproj/project.xcproj"

    private static func info() throws -> [String: Any] {
        let data = try Data(contentsOf: Repository.root.appendingPathComponent(infoFile))
        let value = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(value as? [String: Any], "\(infoFile) is no dictionary")
    }

    /// The text of the project from `marker` to the next `end`, or to the end of the file; nil without the marker.
    private static func block(from marker: String, to end: String) throws -> String? {
        let project = try Repository.text(projectFile)
        guard let start = project.range(of: marker) else { return nil }
        let stop = project.range(of: end, range: start.upperBound..<project.endIndex)?.lowerBound ?? project.endIndex
        return String(project[start.lowerBound..<stop])
    }

    /// The quoted strings of `text` after `key`, up to the end of its value: one string, or a list of them.
    private static func values(of key: String, in text: String) -> [String] {
        guard let start = text.range(of: "\"\(key)\": ") else { return [] }
        let rest = text[start.upperBound...]
        let value = rest.hasPrefix("[") ? rest.prefix { $0 != "]" } : rest.prefix { $0 != "," && $0 != "\n" }
        return value.split(separator: "\"", omittingEmptySubsequences: false).enumerated()
            .filter { $0.offset % 2 == 1 }.map { String($0.element) }
    }

    @Test("The app declares PDF as a document it views, at the alternate rank, and nothing else")
    func pdfIsDeclaredAtTheAlternateRank() throws {
        let types = try #require(try Self.info()["CFBundleDocumentTypes"] as? [[String: Any]])

        #expect(types.count == 1)
        let pdf = try #require(types.first)
        #expect(pdf["CFBundleTypeRole"] as? String == "Viewer")
        #expect(pdf["LSHandlerRank"] as? String == "Alternate")
        #expect(pdf["LSItemContentTypes"] as? [String] == ["com.adobe.pdf"])
    }

    @Test("On iOS a PDF opened from another app is handed over as a copy, and the key that asks for it is set for no other SDK")
    func aPDFIsNeverOpenedInPlace() throws {
        let key = "LSSupportsOpeningDocumentsInPlace"
        let target = try #require(try Self.block(from: "\"name\": \"PrestoCVNext\"", to: "\"name\": \""))
        let settings = target.split(separator: "\n").filter { $0.contains("\"INFOPLIST_KEY_\(key)") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.contains("[sdk=macosx*]") }

        #expect(try Self.info()[key] == nil, "\(Self.infoFile) sets \(key) for macOS too, which rejects it")
        #expect(settings == [#""INFOPLIST_KEY_\#(key)[sdk=iphoneos*]": "NO","#,
                             #""INFOPLIST_KEY_\#(key)[sdk=iphonesimulator*]": "NO","#], "The target sets \(settings)")
    }

    // A setting made for one SDK only still makes the build write the key for every SDK: Swift Build writes a generated
    // Info.plist key when the setting is assigned under any condition, and a key left unset then reads as NO. macOS
    // rejects NO for an app that declares document types, so the macOS SDK sets the key itself, to YES.
    @Test("The key that asks iOS for a copy is set to YES for macOS, which rejects NO in an app with document types")
    func macOSOpensInPlace() throws {
        let key = "INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace"
        let target = try #require(try Self.block(from: "\"name\": \"PrestoCVNext\"", to: "\"name\": \""))

        #expect(Self.values(of: "\(key)[sdk=macosx*]", in: target) == ["YES"],
                "\(key) is set for an SDK but not to YES for macOS: the macOS build fails on the NO it reads")
    }

    @Test("The project builds the app with that file and does not copy it into the app as a resource")
    func theProjectUsesTheFile() throws {
        let target = try #require(try Self.block(from: "\"name\": \"PrestoCVNext\"", to: "\"name\": \""))
        let folder = try #require(try Self.block(from: "\"path\": \"PrestoCVNext\",", to: "\"kind\": \"folder\""))

        #expect(Self.values(of: "INFOPLIST_FILE", in: target) == [Self.infoFile])
        #expect(Self.values(of: "exclusions", in: folder).contains("Info.plist"))
    }

    @Test("Each PDF of the corpus the project copies into the app is left out of a Release build")
    func corpusPDFsAreLeftOutOfRelease() throws {
        let project = try Repository.text(Self.projectFile)
        let target = try #require(try Self.block(from: "\"name\": \"PrestoCVNext\"", to: "\"name\": \""))
        let copied = project.split(separator: "\n")
            .filter { $0.contains("\"PrestoCVNext/resources\"") && $0.contains("/Tests/ImportFixtures/") }
            .compactMap { line in Self.values(of: "path", in: String(line)).first }
            .map { URL(fileURLWithPath: $0).lastPathComponent }

        let excluded = Self.values(of: "EXCLUDED_SOURCE_FILE_NAMES[config=Release]", in: target)

        #expect(!copied.isEmpty, "The scan no longer finds the corpus PDF a Debug build opens: update it with the project")
        #expect(Set(copied).isSubset(of: Set(excluded)), "Copied into a Release build: \(Set(copied).subtracting(excluded))")
    }
}

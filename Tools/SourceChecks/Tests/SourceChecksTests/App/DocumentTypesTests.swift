import Foundation
import Testing

// MARK: - Document Types Tests

/// The second app is among the apps another app can open a PDF in (step 5-13d of #404), as the released app is: as a
/// viewer at the alternate rank, so that it never becomes the one that opens PDFs by default, and a PDF it is handed is
/// a copy, never the file in place (ADR 0027). A Debug build carries a PDF of the corpus for the UI tests that open it;
/// no Release build does.
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

    @Test("A PDF opened from another app is handed over as a copy, never opened in place")
    func aPDFIsNeverOpenedInPlace() throws {
        #expect(try Self.info()["LSSupportsOpeningDocumentsInPlace"] as? Bool == false)
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

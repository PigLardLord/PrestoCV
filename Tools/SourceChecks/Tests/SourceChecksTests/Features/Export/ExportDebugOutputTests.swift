import Testing
import Foundation

// MARK: - What the export feature leaves in a developer's hands

/// The export feature never writes the CV or its HTML to the console or to the pasteboard, in a Debug build either. An
/// earlier preview printed the whole HTML of the CV and copied it to the pasteboard when the preview was made (#38): the
/// text of a CV is the person's, and the pasteboard is read by every app that is open. `ReleaseHygieneTests` keeps the
/// console output out of a Release build; this keeps both out of the feature, `#if DEBUG` or not.
///
/// The checks read the code of the files, not their comments (`SwiftCode`).
@Suite("Export debug output - the feature neither prints nor copies")
struct ExportDebugOutputTests {

    // MARK: - Helpers

    private static let folder = "PrestoCV/Features/Export"

    /// A call that writes to the console
    private static let console = try! NSRegularExpression(pattern: #"(?<![\w.])(print|debugPrint|NSLog|dump)\s*\(|\bSwift\.(print|debugPrint|dump)\s*\("#)

    /// A use of the pasteboard
    private static let pasteboard = try! NSRegularExpression(pattern: #"\bUIPasteboard\b|\bNSPasteboard\b"#)

    /// The lines of `source` that write to the console or touch the pasteboard, as `line: reason`
    static func problems(in source: String) -> [String] {
        let code = SwiftCode(source)
        var problems: [String] = []
        for line in code.lines(matching: console) {
            problems.append("\(line + 1): writes to the console")
        }
        for line in code.lines(matching: pasteboard) {
            problems.append("\(line + 1): uses the pasteboard")
        }
        return problems.sorted()
    }

    private static func swiftFiles() throws -> [URL] {
        let url = Repository.root.appendingPathComponent(folder)
        let enumerator = try #require(FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil))
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    // MARK: - Tests

    @Test("the check reads the files of the export feature, so that an empty folder does not pass it")
    func checkReadsTheFeature() throws {
        let files = try Self.swiftFiles()

        #expect(files.count >= 10, "Only \(files.count) Swift files under \(Self.folder)")
        #expect(files.contains { $0.lastPathComponent == "CVExportSheetView.swift" })
        #expect(files.contains { $0.lastPathComponent == "CVExportSheetViewModel.swift" })
    }

    @Test("no file of the export feature prints or touches the pasteboard, in a Debug build either")
    func featureNeitherPrintsNorCopies() throws {
        var found: [String] = []
        for file in try Self.swiftFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            let name = String(file.path.dropFirst(Repository.root.path.count + 1))
            found += Self.problems(in: source).map { "\(name):\($0)" }
        }

        #expect(found.isEmpty, "Output meant for a developer in the export feature: \(found)")
    }

    // MARK: - The check itself

    @Test("the check finds a print and a copy to the pasteboard that sit inside #if DEBUG")
    func findsDebugOnlyOutput() {
        let source = """
        func makePreview(html: String) {
            #if DEBUG
            print(html)
            UIPasteboard.general.string = html
            #endif
        }
        """

        #expect(Self.problems(in: source) == ["3: writes to the console", "4: uses the pasteboard"])
    }

    @Test("the check finds the other ways to write to the console")
    func findsOtherConsoleOutput() {
        let source = """
        debugPrint(html)
        NSLog("%@", html)
        dump(html)
        Swift.print(html)
        """

        #expect(Self.problems(in: source).count == 4, "debugPrint, NSLog, dump and Swift.print")
    }

    @Test("the check does not mind a comment, a member named print, or a longer name")
    func ignoresWhatIsNotOutput() {
        let source = """
        // print(html) and UIPasteboard.general were here
        let blueprint = 1
        printer.print(html)
        func footprint() {}
        """

        #expect(Self.problems(in: source).isEmpty)
    }
}

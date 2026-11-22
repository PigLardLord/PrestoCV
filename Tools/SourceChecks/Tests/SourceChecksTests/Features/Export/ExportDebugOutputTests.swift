import Testing
import Foundation

// MARK: - What the export feature leaves in a developer's hands

/// The export feature never writes the CV or its HTML to the console or to the pasteboard, in a Debug build either. An
/// earlier preview printed the whole HTML of the CV and copied it to the pasteboard when the preview was made (#38): the
/// text of a CV is the person's, and the pasteboard is read by every app that is open. `ReleaseHygieneTests` keeps the
/// console output out of a Release build; this keeps both out of the feature, `#if DEBUG` or not, and out of the code the
/// feature shares with the rest of the app (the design system, the packages), apart from the previews of a view and the
/// one button that copies on a tap.
///
/// The checks read the code of the files, not their comments (`SwiftCode`).
@Suite("Export debug output - the feature neither prints nor copies")
struct ExportDebugOutputTests {

    // MARK: - Helpers

    private static let folder = "PrestoCVNext/Features/Export"

    /// Where the pasteboard is used on purpose, and why: the person asks for the copy with a tap.
    private static let copyOnTap: [String: String] = [:]

    /// The functions that write to the console or to a standard stream: Swift's, Foundation's and C's
    private static let outputFunctions = "print|debugPrint|dump|NSLog|NSLogv|puts|putchar|printf|vprintf|fputs|fputc|fprintf|vfprintf|perror"

    /// The modules that a function can be named through
    private static let modules = #"(?:(?:Swift|Foundation|Darwin|Glibc|Musl)\.)?"#

    /// The ways to write to the console: a call, also of a function with its module in front; the function handed over
    /// (`items.forEach(print)`, `let write = print`); and a standard stream, which C and `FileHandle` write to.
    private static let console = [
        #"(?<![\w.])"# + modules + "(?:\(outputFunctions))" + #"\s*\("#,
        #"[(,=\[]\s*"# + modules + "(?:\(outputFunctions))" + #"(?![\w(.:])"#,
        #"\bstandard(?:Error|Output)\b|(?<![\w.])(?:stderr|stdout)\b"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    /// A use of the pasteboard
    private static let pasteboard = try! NSRegularExpression(pattern: #"\bUIPasteboard\b|\bNSPasteboard\b"#)

    /// The lines of `source` that write to the console or touch the pasteboard, as `line: reason`
    /// - Parameter allowsPasteboard: Whether the source copies on purpose, on a tap
    static func problems(in source: String, allowsPasteboard: Bool = false) -> [String] {
        let code = SwiftCode(source)
        var problems: [String] = []
        for line in Set(console.flatMap { code.lines(matching: $0) }) {
            problems.append("\(line + 1): writes to the console")
        }
        if !allowsPasteboard {
            for line in code.lines(matching: pasteboard) {
                problems.append("\(line + 1): uses the pasteboard")
            }
        }
        return problems.sorted { lineNumber($0) < lineNumber($1) || (lineNumber($0) == lineNumber($1) && $0 < $1) }
    }

    private static func lineNumber(_ problem: String) -> Int {
        problem.split(separator: ":").first.flatMap { Int($0) } ?? 0
    }

    /// The code of a file that ships, without the previews at its end, which only Xcode runs
    private static func withoutPreviews(_ source: String) -> String {
        var lines: [Substring] = []
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            if trimmed.contains("PreviewProvider") || trimmed.hasPrefix("#Preview") { break }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    private static func swiftFiles(in folder: String = folder) throws -> [URL] {
        let url = Repository.root.appendingPathComponent(folder)
        let enumerator = try #require(FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil))
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    private static func path(of file: URL) -> String {
        String(file.path.dropFirst(Repository.root.path.count + 1))
    }

    // MARK: - Tests

    @Test("the check reads the files of the export feature, so that an empty folder does not pass it")
    func checkReadsTheFeature() throws {
        let files = try Self.swiftFiles()

        #expect(files.count >= 10, "Only \(files.count) Swift files under \(Self.folder)")
        #expect(files.contains { $0.lastPathComponent == "ExportSheetView.swift" })
        #expect(files.contains { $0.lastPathComponent == "LookPicker.swift" })
    }

    @Test("no file of the export feature prints or touches the pasteboard, in a Debug build either")
    func featureNeitherPrintsNorCopies() throws {
        var found: [String] = []
        for file in try Self.swiftFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            found += Self.problems(in: source).map { "\(Self.path(of: file)):\($0)" }
        }

        #expect(found.isEmpty, "Output meant for a developer in the export feature: \(found)")
    }

    @Test("the check reads the code that ships with the app, so that a wrong folder does not pass it")
    func checkReadsTheShippedCode() throws {
        let files = try ReleaseHygieneTests.shippedFolders.flatMap { try Self.swiftFiles(in: $0) }
        let names = Set(files.map { Self.path(of: $0) })

        #expect(files.count >= 200, "Only \(files.count) Swift files in the code that ships")
        #expect(names.contains("PrestoCVNext/DesignSystem/LabeledField.swift"), "the design system")
        #expect(names.contains("PrestoCVNext/Features/Export/ExportSheetView.swift"), "the feature")
        #expect(names.contains { $0.hasPrefix("PrestoCVApp/Sources/PrestoCVPresentation/") }, "the app package")
        #expect(names.contains { $0.hasPrefix("CVPDFExporter/Sources/CVRendering/") }, "the exporter package")
        #expect(names.contains { $0.hasPrefix("PrestoCVCore/Sources/PrestoCVDomain/") }, "the core package")
    }

    @Test("no code that ships prints or touches the pasteboard, in a Debug build either, apart from previews and a Copy button")
    func shippedCodeNeitherPrintsNorCopies() throws {
        var found: [String] = []
        for file in try ReleaseHygieneTests.shippedFolders.flatMap({ try Self.swiftFiles(in: $0) }) {
            let name = Self.path(of: file)
            let source = Self.withoutPreviews(try String(contentsOf: file, encoding: .utf8))
            found += Self.problems(in: source, allowsPasteboard: Self.copyOnTap[name] != nil).map { "\(name):\($0)" }
        }

        #expect(found.isEmpty, "Output meant for a developer, or a copy nobody asked for, in the code that ships: \(found)")
    }

    @Test("the copy on a tap is still there, so that the exception is not left behind", arguments: copyOnTap.keys.sorted())
    func copyOnTapIsStillThere(path: String) throws {
        let source = try String(contentsOf: Repository.root.appendingPathComponent(path), encoding: .utf8)

        #expect(Self.pasteboard.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) != nil,
                "\(path) no longer uses the pasteboard: remove it from the exceptions")
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

    @Test("the check finds output written with a module in front, as a function handed over, and through C and the standard streams",
          arguments: [
              "Foundation.NSLog(\"%@\", html)",
              "Darwin.puts(html)",
              "Swift.debugPrint(html)",
              "items.forEach(print)",
              "items.map(debugPrint)",
              "pages.forEach(Swift.print)",
              "let write = print",
              "puts(html)",
              "printf(\"%s\", html)",
              "fputs(html, stderr)",
              "fputs(html, stdout)",
              "fprintf(stderr, \"%s\", html)",
              "NSLogv(\"%@\", arguments)",
              "perror(html)",
              "FileHandle.standardError.write(data)",
              "FileHandle.standardOutput.write(data)",
              "try FileHandle.standardError.write(contentsOf: data)",
          ])
    func findsOutputInOtherForms(source: String) {
        #expect(Self.problems(in: source) == ["1: writes to the console"], "\(source)")
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

    @Test("the check does not mind a word that is not a call: a name in a string, a label, a longer name, a member")
    func ignoresWordsThatAreNotCalls() {
        let source = """
        let media = "@media print { body { margin: 0 } }"
        throw PDFExportError.renderingFailed("There is nothing to print")
        guard ["print", "screen", "all"].contains(name) else { return }
        rows.forEach(printRow)
        reprint(html)
        let report = Report(print: true, dump: false)
        let standardErrorText = text
        // fputs(html, stderr)
        """

        #expect(Self.problems(in: source).isEmpty, "\(Self.problems(in: source))")
    }
}

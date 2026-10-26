import Foundation
import Testing

// MARK: - Logging Guide Tests

/// The guide to the diagnostic log (`docs/logging.md`, ADR 0030) says what a tester's log can hold. It stays true only if it
/// lists the events the code writes, and names the subsystem the app writes them under.
@Suite("The logging guide")
struct LoggingGuideTests {

    private static let root = Repository.root
    private static let guide = "docs/logging.md"

    /// The sources that may log through the interface: the packages and the app.
    static let sourceFolders = [
        "DiagnosticLogging/Sources", "PrestoCVCore/Sources", "CVPDFExporter/Sources", "CVGeneratorAI/Sources", "PrestoCV",
    ]

    /// An event as the code names it, in a shorthand (`logger.info(.draft, "draft.started", …)`) or in an entry
    /// (`event: "import.finished"`).
    private static var eventInCode: Regex<(Substring, Substring)> {
        /(?:\.(?:debug|info|notice|error|fault)\(\s*\.[A-Za-z]+\s*,\s*|event:\s*)"([a-z]+\.[A-Za-z]+)"/
    }

    /// An event as the guide lists it: the first cell of a row of its tables.
    private static var eventInGuide: Regex<(Substring, Substring)> { /^\|\s*`([a-z]+\.[A-Za-z]+)`\s*\|/ }

    private static func text(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// The events the code writes, by file, from code lines only: a comment may show an example.
    private static func eventsInCode() -> [String: Set<String>] {
        var events: [String: Set<String>] = [:]
        for folder in sourceFolders {
            let url = root.appendingPathComponent(folder)
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in enumerator where file.pathExtension == "swift" {
                guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
                for line in source.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                    for match in line.matches(of: eventInCode) {
                        events[String(file.path.dropFirst(root.path.count + 1)), default: []].insert(String(match.output.1))
                    }
                }
            }
        }
        return events
    }

    @Test("The guide lists every event the code writes, and no other")
    func guideListsTheEvents() throws {
        let inCode = Self.eventsInCode()
        let written = Set(inCode.values.joined())
        let listed = Set(try Self.text(Self.guide).split(separator: "\n").compactMap { line in
            line.firstMatch(of: Self.eventInGuide).map { String($0.output.1) }
        })

        #expect(!written.isEmpty, "No event found in \(Self.sourceFolders): the pattern no longer matches the code")
        for event in written.subtracting(listed).sorted() {
            let files = inCode.filter { $0.value.contains(event) }.keys.sorted()
            Issue.record("\(event), written in \(files.joined(separator: ", ")), is not in \(Self.guide)")
        }
        for event in listed.subtracting(written).sorted() {
            Issue.record("\(event) is in \(Self.guide), and no code writes it")
        }
    }

    @Test("The guide names the subsystem the app writes its log under")
    func guideNamesTheSubsystem() throws {
        let app = try Self.text("PrestoCV/PrestoCVApp.swift")
        let subsystem = try #require(app.firstMatch(of: /OSLogDiagnosticLogger\(subsystem:\s*"([^"]+)"\)/)?.output.1)

        #expect(try Self.text(Self.guide).contains("subsystem:\(subsystem)"))
    }
}

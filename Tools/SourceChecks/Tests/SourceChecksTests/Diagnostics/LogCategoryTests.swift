import Foundation
import Testing

// MARK: - Log Category Tests

/// A category is the name of the flow a line belongs to (ADR 0030). The modules of one flow share it: a second declaration of the
/// same name in another module would let the two drift apart, and a line of the flow would land under a name no one searches.
@Suite("The log categories")
struct LogCategoryTests {

    private static let root = Repository.root

    /// A category as the code declares it: `LogCategory("import")`.
    private static var categoryInCode: Regex<(Substring, Substring)> { /LogCategory\("([a-z]+)"\)/ }

    /// The files that declare each category, from code lines only: a comment may show an example.
    private static func declarations() -> [String: [String]] {
        var files: [String: [String]] = [:]
        for folder in LoggingGuideTests.sourceFolders {
            guard let enumerator = FileManager.default.enumerator(at: root.appendingPathComponent(folder), includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in enumerator where file.pathExtension == "swift" {
                guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let path = String(file.path.dropFirst(root.path.count + 1))
                for line in source.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                    for match in line.matches(of: categoryInCode) { files[String(match.output.1), default: []].append(path) }
                }
            }
        }
        return files
    }

    @Test("Each category is declared once, in the module that owns the flow, and the others import it")
    func eachCategoryIsDeclaredOnce() {
        let declared = Self.declarations()

        #expect(!declared.isEmpty, "No category found in \(LoggingGuideTests.sourceFolders): the pattern no longer matches the code")
        for (name, files) in declared.sorted(by: { $0.key < $1.key }) where files.count > 1 {
            Issue.record("The category \"\(name)\" is declared \(files.count) times: \(files.sorted().joined(separator: ", "))")
        }
    }
}

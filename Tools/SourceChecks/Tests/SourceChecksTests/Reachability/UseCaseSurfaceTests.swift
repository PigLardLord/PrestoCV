import Foundation
import Testing

// MARK: - Use Case Surface Tests

/// R14: nothing ships that only a test calls. A function that no production code calls is one a test keeps alive, and a name such
/// as `read` is called everywhere, so a search by name cannot tell it. The use cases that had such a function list the ones they
/// offer: a new function is added here, in the pull request that adds its caller.
@Suite("The surface of the use cases")
struct UseCaseSurfaceTests {

    private static let root = Repository.root

    /// A function of a type, at the first level of its file: not private, so a caller outside the type may use it.
    private static var functionOfType: Regex<(Substring, Substring)> {
        /^ {4}(?:(?:public|internal|static|final|nonisolated|mutating|@discardableResult)\s+)*func\s+(\w+)/
    }

    /// The functions of the file from the declaration `type` on: a file may hold a port above the type.
    private static func functions(in path: String, from type: String) throws -> Set<String> {
        let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        let declaration = try #require(source.range(of: type), "\(path) does not declare \(type)")
        return Set(source[declaration.lowerBound...].split(separator: "\n").compactMap { $0.firstMatch(of: functionOfType).map { String($0.output.1) } })
    }

    @Test("ImportCV offers the import of a text and of a PDF, and no function that a test alone calls")
    func importCV() throws {
        #expect(try Self.functions(in: "PrestoCVCore/Sources/PrestoCVImporting/ImportCV.swift", from: "public struct ImportCV") == ["importText", "importPDF"])
    }

    @Test("CVDataSanitizer offers the sanitising of a draft and the language check the use case logs, and no function that a test alone calls")
    func cvDataSanitizer() throws {
        let functions = try Self.functions(in: "CVGeneratorAI/Sources/CVGeneratorAI/Validation/CVDataSanitizer.swift", from: "struct CVDataSanitizer")

        #expect(functions == ["sanitize", "languageCheck", "require"])
    }
}

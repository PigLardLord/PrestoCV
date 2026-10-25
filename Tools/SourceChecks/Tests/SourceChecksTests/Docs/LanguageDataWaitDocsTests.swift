import Foundation
import Testing

// MARK: - Language Data Wait Docs Tests

/// What the docs say about the wait for the language data of an English or German draft (issue #270) is what the code does: it
/// waits at most `LanguageDataPreparation.bound`, and nothing in the docs tells the person to try again later. The notes that Apple
/// reads during review and the README of the package are shipped to people who cannot ask the code.
@Suite("Language Data Wait Docs Tests")
struct LanguageDataWaitDocsTests {

    private static let root = Repository.root

    /// A doc, and the start of the bullet in it that describes the wait.
    struct Description: CustomTestStringConvertible {
        let path: String
        let startOfBullet: String
        var testDescription: String { path }
    }

    private static let descriptions = [
        Description(path: "docs/release/store-listing.md", startOfBullet: "- For an English or German description, the draft also needs"),
        Description(path: "CVGeneratorAI/README.md", startOfBullet: "- **Language data.**"),
        Description(path: "docs/architecture/adr/0023-ground-the-ai-draft-in-the-description.md", startOfBullet: "- **Drafts wait for the language data.**"),
    ]

    private static let boundPath = "PrestoCV/Features/AIGeneration/ViewModels/LanguageDataPreparation.swift"

    /// The bound of the wait, in seconds, as the code gives it.
    private static func boundInSeconds() throws -> Int {
        let source = try String(contentsOf: root.appendingPathComponent(boundPath), encoding: .utf8)
        let pattern = try NSRegularExpression(pattern: #"static let bound: Duration = \.seconds\((\d+)\)"#)
        let range = NSRange(source.startIndex..., in: source)
        let match = try #require(pattern.firstMatch(in: source, range: range), "\(boundPath) no longer gives the bound as `.seconds(n)`")
        let digits = try #require(Range(match.range(at: 1), in: source))
        return try #require(Int(source[digits]))
    }

    /// The bullet that starts with `start`: its line and the lines that continue it, up to a blank line or the next bullet, with
    /// one space between words.
    private static func bullet(startingWith start: String, in path: String) throws -> String {
        let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        let lines = text.components(separatedBy: "\n")
        let first = try #require(lines.firstIndex { $0.hasPrefix(start) }, "\(path) has no bullet that starts with \"\(start)\"")
        var bullet = [lines[first]]
        for line in lines[(first + 1)...] {
            if line.isEmpty || line.hasPrefix("- ") || line.hasPrefix("#") || line.hasPrefix("```") { break }
            bullet.append(line)
        }
        // Lines wrapped in the source read as one: a phrase can break at a line end
        return bullet.joined(separator: " ").split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @Test("A doc that describes the wait gives the bound of the code", arguments: descriptions)
    func docGivesTheBound(of description: Description) throws {
        let bound = try Self.boundInSeconds()
        let bullet = try Self.bullet(startingWith: description.startOfBullet, in: description.path)
        #expect(bullet.contains("\(bound) seconds"), "\(description.path) should say that the wait lasts at most \(bound) seconds: \(bullet)")
    }

    @Test("A doc that describes the wait does not send the person to try again later", arguments: descriptions)
    func docDoesNotPromiseAnotherTry(of description: Description) throws {
        let bullet = try Self.bullet(startingWith: description.startOfBullet, in: description.path).lowercased()
        for removed in ["try again", "next try", "being prepared"] {
            #expect(!bullet.contains(removed), "\(description.path) still describes a screen that does not wait (\"\(removed)\"): \(bullet)")
        }
    }
}

import Foundation
import Testing

/// The string catalog of the new app, `PrestoCVNext/Resources/Localizable.xcstrings`, read from the source tree.
@Suite("The string catalog of the new app")
struct NextCatalogTests {
    private static let languages = ["de", "en", "es", "fr", "it", "pt"]

    private static func catalog() throws -> [String: [String: Any]] {
        let url = Repository.root.appendingPathComponent("PrestoCVNext/Resources/Localizable.xcstrings")
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try #require(object["strings"] as? [String: [String: Any]])
    }

    private static func text(of key: String, in language: String, _ strings: [String: [String: Any]]) -> (state: String?, value: String)? {
        let localizations = strings[key]?["localizations"] as? [String: Any]
        guard let unit = (localizations?[language] as? [String: Any])?["stringUnit"] as? [String: Any],
              let value = unit["value"] as? String else { return nil }
        return (unit["state"] as? String, value)
    }

    private static func placeholders(in text: String) -> [String] {
        text.split(separator: "%", omittingEmptySubsequences: false).dropFirst().map { String($0.prefix(2)) }
    }

    @Test("Every key has a translated, non-empty text in each of the six languages, with the placeholders of the English one")
    func everyKeyIsComplete() throws {
        let strings = try Self.catalog()
        #expect(!strings.isEmpty)
        var defects: [String] = []
        for key in strings.keys.sorted() {
            let english = Self.text(of: key, in: "en", strings)?.value ?? ""
            for language in Self.languages {
                guard let found = Self.text(of: key, in: language, strings), !found.value.isEmpty else {
                    defects.append("\(key) (\(language)): no text")
                    continue
                }
                if found.state != "translated" { defects.append("\(key) (\(language)): state \(found.state ?? "none")") }
                if Self.placeholders(in: found.value) != Self.placeholders(in: english) {
                    defects.append("\(key) (\(language)): placeholders differ from English")
                }
                if language != "en", found.value == english { defects.append("\(key) (\(language)): copies English") }
            }
        }
        #expect(defects.isEmpty, "\(defects)")
    }

    @Test("Every key is looked up by the code of the new app, and every key it looks up is in the catalog")
    func keysAndCodeAgree() throws {
        let keys = try Self.catalog().keys.map { String($0.split(separator: " ").first ?? "") }
        let sources = try ["App", "DesignSystem", "Features", "Platform"].flatMap { folder in
            try Self.swiftFiles(in: Repository.root.appendingPathComponent("PrestoCVNext/\(folder)"))
        }
        let code = try sources.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        let unused = keys.filter { !code.contains("\"\($0)") }
        #expect(unused.isEmpty, "Keys no code of the new app looks up: \(unused)")
        // A key is a dotted word such as "failed.title"; a literal of that shape handed to a view must be in the catalog
        let looked = try NSRegularExpression(pattern: #"(?:title|message|code|retryTitle|LoadingView\(|Text\()\s*:?\s*"([a-z]+(?:\.[a-z]+)+)"#)
        let known = Set(keys)
        let missing = looked.matches(in: code, range: NSRange(code.startIndex..., in: code))
            .compactMap { Range($0.range(at: 1), in: code).map { String(code[$0]) } }
            .filter { !known.contains($0) }
        #expect(missing.isEmpty, "Keys missing from the catalog: \(missing)")
    }

    private static func swiftFiles(in folder: URL) throws -> [URL] {
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }
}

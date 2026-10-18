import Foundation

/// The app's own texts in one of its languages, read from the string catalog in the source tree, so that a UI test can
/// find a button by what it says in any language. A key that has no text in the language has the source language's.
struct AppStrings {
    private let texts: [String: String]

    init(language: String) throws {
        let catalog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("PrestoCV/Localizable.xcstrings")
        let file = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: catalog))
        texts = file.strings.compactMapValues { entry in
            let units = entry.localizations ?? [:]
            return (units[language] ?? units[file.sourceLanguage])?.stringUnit?.value
        }
    }

    subscript(key: String) -> String {
        texts[key] ?? key
    }

    /// The text of `key` with its placeholders filled in
    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: self[key], arguments: arguments)
    }

    private struct Catalog: Decodable {
        let sourceLanguage: String
        let strings: [String: Entry]
    }

    private struct Entry: Decodable {
        let localizations: [String: Localization]?
    }

    private struct Localization: Decodable {
        let stringUnit: StringUnit?
    }

    private struct StringUnit: Decodable {
        let value: String
    }
}

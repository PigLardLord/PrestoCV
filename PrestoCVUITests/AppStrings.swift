import Foundation

/// The app's own texts in the language of the test, so that a UI test can find a button by what it says in any
/// language. They are handed over, not read from the source tree: `Tools/Release/store-screenshots.sh` takes them from
/// the string catalog and passes them in `STORE_SCREENSHOT_STRINGS`, a JSON object from key to text, in Base64.
struct AppStrings {
    static let environmentKey = "STORE_SCREENSHOT_STRINGS"

    private let texts: [String: String]

    init(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        guard let encoded = environment[Self.environmentKey], let json = Data(base64Encoded: encoded) else {
            throw Missing()
        }
        texts = try JSONDecoder().decode([String: String].self, from: json)
    }

    subscript(key: String) -> String {
        texts[key] ?? key
    }

    /// The text of `key` with its placeholders filled in
    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: self[key], arguments: arguments)
    }

    struct Missing: Error, CustomStringConvertible {
        var description: String {
            "The app's texts were not handed over in \(AppStrings.environmentKey): run Tools/Release/store-screenshots.sh"
        }
    }
}

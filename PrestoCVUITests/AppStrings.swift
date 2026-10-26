import Foundation

/// The app's own texts in the language of the test, so that a UI test can find a button by what it says in any
/// language. They are handed over, not read from the source tree: `Tools/Release/store-screenshots.sh` takes them from
/// the string catalog and passes them in `STORE_SCREENSHOT_STRINGS`, a JSON object from key to text, in Base64.
///
/// A key that was not handed over is an error that names it, never the key handed back as a text: searched for as a
/// label it finds nothing, and in a check that a label does not mention a text it passes for the wrong reason.
struct AppStrings {
    static let environmentKey = "STORE_SCREENSHOT_STRINGS"

    private let texts: [String: String]

    init(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        guard let encoded = environment[Self.environmentKey], let json = Data(base64Encoded: encoded) else {
            throw Failure.notHandedOver
        }
        texts = try JSONDecoder().decode([String: String].self, from: json)
    }

    func text(_ key: String) throws -> String {
        guard let text = texts[key] else { throw Failure.noText(key) }
        return text
    }

    /// The text of `key` with its placeholders filled in
    func format(_ key: String, with arguments: [CVarArg]) throws -> String {
        String(format: try text(key), arguments: arguments)
    }

    enum Failure: Error, CustomStringConvertible {
        case notHandedOver
        case noText(String)

        var description: String {
            switch self {
            case .notHandedOver:
                "The app's texts were not handed over in \(AppStrings.environmentKey): run Tools/Release/store-screenshots.sh"
            case .noText(let key):
                "The texts handed over hold none for the key \"\(key)\": check the key, and run Tools/Release/store-screenshots.sh"
            }
        }
    }
}

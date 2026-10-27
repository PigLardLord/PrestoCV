import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// What tells whether a word is a word of a language, or a name the dictionary does not hold: in the app, the device's spelling
/// dictionary (`DeviceWordList`). The text the model writes around the facts keeps no name (ADR 0031), and a word that neither the
/// closed vocabulary nor the dictionary knows is taken for one. A language is a BCP 47 primary language code: "en", "de".
public protocol WordList: Sendable {
    /// Whether the dictionary of `language` holds `word`, as written: nil when the device has no dictionary of `language`, and the
    /// text is then checked without one.
    func knows(_ word: String, inLanguage language: String) -> Bool?
}

/// The device's spelling dictionary: `UITextChecker` on iOS, `NSSpellChecker` on macOS. Both are main-actor classes, so a word is
/// looked up on the main thread.
public struct DeviceWordList: WordList {
    public init() {}

    public func knows(_ word: String, inLanguage language: String) -> Bool? {
        Self.onMainThread { Self.lookUp(word, inLanguage: language) }
    }

    @MainActor
    private static func lookUp(_ word: String, inLanguage language: String) -> Bool? {
        #if canImport(UIKit)
        guard let dictionary = dictionary(of: language, among: UITextChecker.availableLanguages) else { return nil }
        let range = NSRange(location: 0, length: (word as NSString).length)
        let misspelled = UITextChecker().rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: dictionary)
        return misspelled.location == NSNotFound
        #elseif canImport(AppKit)
        let checker = NSSpellChecker.shared
        guard let dictionary = dictionary(of: language, among: checker.availableLanguages) else { return nil }
        let misspelled = checker.checkSpelling(of: word, startingAt: 0, language: dictionary, wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
        return misspelled.location == NSNotFound
        #else
        return nil
        #endif
    }

    /// The device's dictionary of `language`: the one named by the code alone, or else the first of a region ("en_US").
    private static func dictionary(of language: String, among available: [String]) -> String? {
        available.first { $0 == language } ?? available.first { $0.hasPrefix(language + "_") || $0.hasPrefix(language + "-") }
    }

    private static func onMainThread<T: Sendable>(_ work: @MainActor () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { work() }
        }
        return DispatchQueue.main.sync { MainActor.assumeIsolated { work() } }
    }
}

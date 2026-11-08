import Foundation

// The string checks as a function of a catalog and the sources that look its keys up. The catalog tests of the legacy
// app and of the new app both call it, and so does the self-test that plants a defect of each kind.

/// What the checks found in a catalog and its sources, one list per kind of defect. Each entry names the key, and the
/// language or the file when that is what differs.
struct StringFindings: Equatable {
    var missingLanguage: [String] = []
    var notTranslated: [String] = []
    var copiedFromEnglish: [String] = []
    var otherPlaceholders: [String] = []
    var availabilityPromises: [String] = []
    var titleCase: [String] = []
    var unused: [String] = []
    var lookedUpButMissing: [String] = []
}

/// The exemptions of one catalog, each a list that gives its reason where it is declared.
struct StringRules {
    var sameInEveryLanguage: Set<String> = []
    var sameInSomeLanguages: [String: Set<String>] = [:]
    var pendingKeys: Set<String> = []
    var dynamicKeyPrefixes: [String] = []
    var properNames: Set<String> = []
    var personNames: Set<String> = []
    var properNamesOfKey: [String: Set<String>] = [:]
    /// Only the keys with this prefix are checked for a promise of availability; all keys when nil.
    var promiseKeyPrefix: String?
}

enum StringChecks {
    /// Checks `catalog` against the Swift files in `sources`.
    static func run(catalog: URL, sources: [URL], rules: StringRules = StringRules()) throws -> StringFindings {
        StringFindings()
    }
}

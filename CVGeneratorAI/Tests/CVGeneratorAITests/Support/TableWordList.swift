import Foundation
@testable import CVGeneratorAI

/// A dictionary that a test gives in place of the device's: it knows every word of every language but the invented names of the
/// tests' descriptions ("Acme", "Milani"), compared in lower case. The device's dictionaries differ from one Mac or iPhone to the
/// next, so a test that needs a verdict of its own does not read them.
struct TableWordList: WordList {
    /// The names it does not know, in lower case.
    let names: Set<String>

    init(names: Set<String> = TableWordList.inventedNames) {
        self.names = names
    }

    func knows(_ word: String, inLanguage language: String) -> Bool? {
        !names.contains(word.lowercased())
    }

    /// The employers, schools, places and people the tests invent.
    static let inventedNames: Set<String> = [
        "acme", "beta", "globex", "initech", "umbrella", "milani", "rossi", "maria", "bianchi", "verdi", "anna", "jane", "smith",
        "john", "doe", "raffaele", "bologna", "bolonia", "bologne", "bolonha", "turia", "mondego", "kassel", "siemens", "lincoln",
        "ferrara", "luce", "torino", "milano", "berlin", "madrid", "lisboa", "paris", "rossini", "schmidt", "dupont", "garcia",
        "santos", "müller", "mueller",
    ]
}

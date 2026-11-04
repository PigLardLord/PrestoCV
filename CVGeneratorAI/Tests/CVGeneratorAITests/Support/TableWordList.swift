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

    /// The employers, schools, places and people the tests invent. The check that reads a gerund reads a word that ends as one only
    /// when no verb of another form makes it (#362): a test that needs that has `knowingNoVerb(of:nor:)`.
    static let inventedNames: Set<String> = people

    /// A dictionary that knows none of the infinitives that make the `gerunds` ("controllandare" for "controllando"; none such is in
    /// a dictionary), and none of `others`, and no name of `inventedNames`: the check then reads each gerund as one (#362).
    static func knowingNoVerb(of gerunds: [String], nor others: Set<String> = []) -> TableWordList {
        let verbs: [String] = gerunds.flatMap { gerund in ["are", "ere", "ire", "ar", "er", "ir"].map { String(gerund.dropLast()) + $0 } }
        return TableWordList(names: inventedNames.union(verbs).union(others))
    }

    private static let people: Set<String> = [
        "acme", "beta", "globex", "initech", "umbrella", "milani", "rossi", "maria", "bianchi", "verdi", "anna", "jane", "smith",
        "john", "doe", "raffaele", "bologna", "bolonia", "bologne", "bolonha", "turia", "mondego", "kassel", "siemens", "lincoln",
        "ferrara", "luce", "torino", "milano", "berlin", "madrid", "lisboa", "paris", "rossini", "schmidt", "dupont", "garcia",
        "santos", "müller", "mueller",
    ]
}

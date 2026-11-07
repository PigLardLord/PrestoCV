/// A German duty the person said in a subordinate clause, each verb last ("wo ich die Kolonne einteile und die Pflege der
/// Parkanlagen plane"), written as the main clause a CV says it with: "Ich teile die Kolonne ein und plane die Pflege der
/// Parkanlagen." (#359).
enum GermanMainClause {
    /// The main clause of `clauses`, the words of each clause after "ich" in the order the person said them, joined by
    /// `conjunctions`, and the main clause of each clause alone; nil when a clause ends in no verb, written lower case.
    ///
    /// A perfect or a modal the clauses share keeps its verb once, first: "Jungpflanzen umgetopft und die Beete gepflegt habe" is
    /// "Ich habe Jungpflanzen umgetopft und die Beete gepflegt." Otherwise each clause puts its verb first, and a separable verb
    /// leaves its particle at the end of its clause (`SeparableVerbs.split`).
    static func written(_ clauses: [[String]], joinedBy conjunctions: [String]) -> (text: String, parts: [String])? {
        guard !clauses.isEmpty, conjunctions.count == clauses.count - 1,
              clauses.allSatisfy({ $0.last?.first?.isLowercase == true }) else { return nil }
        if clauses.count > 1, let shared = clauses.last?.last, isSharedVerb(shared),
           clauses.dropLast().allSatisfy({ $0.last.map(isParticipleOrInfinitive) == true }) {
            var bodies = clauses
            bodies[bodies.count - 1].removeLast()
            guard bodies.allSatisfy({ !$0.isEmpty }) else { return nil }
            return (sentence([shared] + joined(bodies, conjunctions)), bodies.map { sentence([shared] + $0) })
        }
        let main = clauses.map(mainOrder)
        return (sentence(joined(main, conjunctions)), main.map(sentence))
    }

    /// The words of a clause with its verb first, and the particle of a separable verb last.
    private static func mainOrder(_ words: [String]) -> [String] {
        guard let verb = words.last else { return words }
        let rest = Array(words.dropLast())
        if let split = SeparableVerbs.split(verb) { return [split.verb] + rest + [split.particle] }
        return [verb] + rest
    }

    private static func joined(_ clauses: [[String]], _ conjunctions: [String]) -> [String] {
        clauses.enumerated().flatMap { index, words in index == 0 ? words : [conjunctions[index - 1]] + words }
    }

    private static func sentence(_ words: [String]) -> String {
        (["Ich"] + words).joined(separator: " ") + "."
    }

    /// An auxiliary, a form of "sein" or a modal: a verb that the participles or the infinitives of the clauses before it share.
    private static func isSharedVerb(_ word: String) -> Bool {
        let lowered = word.lowercased()
        return Vocabulary.isAuxiliary(lowered, in: .german) || Vocabulary.isBeForm(lowered, in: .german) || modals.contains(lowered)
    }

    /// An infinitive ends with "n" ("pflegen", "sammeln"), and so does a strong participle ("getan", "gegossen"); a weak participle
    /// ends with "t", with or without "ge" ("gepflegt", "recycelt", "vorbereitet"). The verb of "ich" ends with neither, but for a
    /// strong past of `ownPasts` ("schnitt", "hielt", "begann"): a present or a weak past ends with "e" ("plane", "leitete"), and
    /// any other strong past with neither ("fuhr", "nahm").
    private static func isParticipleOrInfinitive(_ word: String) -> Bool {
        let lowered = word.lowercased()
        guard !isSharedVerb(lowered), !ownPasts.contains(where: lowered.hasSuffix) else { return false }
        return lowered.hasSuffix("n") || lowered.hasSuffix("t")
    }

    /// The strong pasts of "ich" that end with "t" or "n", a closed class; a prefix keeps them ("erhielt", "vertrat", "gewann").
    private static let ownPasts = [
        "schnitt", "ritt", "stritt", "litt", "glitt", "schritt", "trat", "bat", "bot", "briet", "riet", "hielt", "galt", "schalt",
        "tat", "focht", "flocht", "sott", "barst", "schien", "begann", "gewann", "spann", "rann", "sann",
    ]

    private static let modals: Set<String> = [
        "kann", "konnte", "muss", "musste", "darf", "durfte", "soll", "sollte", "will", "wollte", "werde",
    ]
}

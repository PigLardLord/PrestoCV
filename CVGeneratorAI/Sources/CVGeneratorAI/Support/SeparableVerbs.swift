import Foundation

/// The German separable verbs a request wrote apart at the end of a subordinate clause, joined: "dass ich die Leitungen sicher
/// stelle" becomes "dass ich die Leitungen sicherstelle" (#354, round 4). In a main clause the particle ends the clause on its own
/// ("Ich stelle die Funktion sicher") and stays. Every word the rule reads is German, so a text of another language comes back as
/// it was.
enum SeparableVerbs {
    static func joined(in text: String) -> String {
        var result = ""
        var clause = ""
        for character in text {
            guard ",;:.!?\n".contains(character) else {
                clause.append(character)
                continue
            }
            result += joinedAtItsEnd(clause) + String(character)
            clause = ""
        }
        return result + joinedAtItsEnd(clause)
    }

    /// `clause` with its last two words joined when a subordinating word opens it into a subordinate clause and they are a particle
    /// and a finite verb, both written lower case, with only spaces between them. A word with a capital is a noun, and no particle
    /// ("jedes Teil achte"; #354, round 8).
    private static func joinedAtItsEnd(_ clause: String) -> String {
        let words = clause.split { !$0.isLetter }
        guard words.count >= 3, let verb = words.last else { return clause }
        let particle = words[words.count - 2]
        guard !subordinators.isDisjoint(with: words.map { $0.lowercased() }), isFiniteVerb(verb),
              particle.first?.isLowercase == true, joins(String(particle), verb.lowercased()),
              clause[particle.endIndex..<verb.startIndex].allSatisfy({ $0 == " " }) else { return clause }
        return String(clause[..<particle.endIndex]) + String(clause[verb.startIndex...])
    }

    /// A finite verb as a subordinate clause ends with it: lower case, unlike a noun, and with the ending of a person.
    private static func isFiniteVerb(_ word: Substring) -> Bool {
        guard word.count >= 4, word.first?.isLowercase == true else { return false }
        return ["e", "t", "en", "st"].contains { word.hasSuffix($0) }
    }

    /// Whether `particle` joins `verb`: a preposition or an adverb that only a separable verb puts right before its verb, or an
    /// adjective before one of the verbs it makes a separable verb with ("sicher stellen", not "sicher laufen").
    private static func joins(_ particle: String, _ verb: String) -> Bool {
        if particles.contains(particle) { return true }
        return adjectives.contains(particle) && adjectiveVerbs.contains { verb.hasPrefix($0) }
    }

    private static let subordinators: Set<String> = [
        "dass", "weil", "wenn", "indem", "ob", "damit", "als", "wobei", "sodass", "nachdem", "bevor", "während", "obwohl",
    ]

    private static let particles: Set<String> = [
        "an", "auf", "aus", "ein", "mit", "vor", "nach", "ab", "hin", "her", "dar", "zurück", "fort", "zusammen", "vorbei", "los",
        "teil", "statt", "instand",
    ]

    private static let adjectives: Set<String> = ["sicher", "fest", "bereit"]

    private static let adjectiveVerbs = ["stell", "leg", "setz", "halt", "hält", "nehm", "nimm"]
}

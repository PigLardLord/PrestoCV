/// Common given names in English, German and Italian: the evidence that a line opening with one is a person, whatever a
/// later word says ("Rebecca Cook"). A name that is also a city or a job ("Paris", "Florence") is not among them. The list
/// only spares a check; a name it lacks keeps the line judged by the other word lists, as before.
enum GivenNames {

    /// Whether the first word of a line is a known given name.
    static func opens(_ text: String) -> Bool {
        guard let first = text.words.first else { return false }
        return known.contains(first.folded)
    }

    private static let known: Set<String> = Set([
        "anna", "maria", "john", "james", "robert", "michael", "william", "david", "richard", "joseph", "thomas", "charles",
        "daniel", "matthew", "mark", "paul", "steven", "andrew", "kevin", "brian", "george", "edward", "peter", "jack", "henry",
        "mary", "patricia", "jennifer", "linda", "elizabeth", "barbara", "susan", "jessica", "sarah", "karen", "nancy", "lisa",
        "emma", "olivia", "sophie", "laura", "emily", "rebecca", "rachel", "hannah", "julia", "jane", "alice", "helen", "claire",
        "sam", "ben", "tom", "tim", "alex", "chris", "simon", "oliver", "harry", "luke", "adam", "ryan", "nathan", "joe",
        "hans", "stefan", "andreas", "wolfgang", "klaus", "jürgen", "jens", "markus", "matthias",
        "christian", "frank", "uwe", "dieter", "lukas", "jonas", "felix", "maximilian", "tobias", "sebastian", "florian",
        "petra", "monika", "sabine", "ursula", "claudia", "birgit", "heike", "andrea", "katharina", "sophia", "lena", "lea",
        "marco", "luca", "giuseppe", "giovanni", "francesco", "alessandro", "matteo", "lorenzo", "davide", "simone",
        "paolo", "stefano", "roberto", "antonio", "mario", "luigi", "giorgio", "fabio", "carlo", "sergio", "valerio",
        "giulia", "chiara", "francesca", "sara", "valentina", "elena", "silvia", "martina", "federica", "alessia", "paola",
        "giovanna", "angela", "roberta", "serena", "elisa", "ilaria", "monica", "cristina", "daniela",
    ].map(\.folded))
}

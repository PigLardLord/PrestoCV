import Testing
@testable import CVGeneratorAI

/// The German separable verbs a request wrote apart at the end of a subordinate clause, joined (#354). The sentences are
/// invented.
@Suite("German separable verbs joined at the end of a subordinate clause")
struct SeparableVerbsTests {
    @Test("A particle and its verb written apart at the end of a subordinate clause are joined; elsewhere they stay", arguments: [
        ("Ich achte darauf, dass ich die Funktion der Schleusentore sicher stelle.", "Ich achte darauf, dass ich die Funktion der Schleusentore sicherstelle."),
        ("Ich öle die Scharniere, bevor die Kähne ein fahren.", "Ich öle die Scharniere, bevor die Kähne einfahren."),
        ("Ich prüfe die Pumpen, indem ich die Ventile fest lege und die Leitungen an schließe.", "Ich prüfe die Pumpen, indem ich die Ventile fest lege und die Leitungen anschließe."),
        ("Ich stelle die Funktion der Schleusentore sicher.", "Ich stelle die Funktion der Schleusentore sicher."),
        ("Ich sorge dafür, dass die Pumpen sicher laufen.", "Ich sorge dafür, dass die Pumpen sicher laufen."),
        ("Ich arbeite als Teil des Teams mit Kollegen.", "Ich arbeite als Teil des Teams mit Kollegen."),
        ("Ich halte die Ersatzteile bereit, damit wir bereit sind.", "Ich halte die Ersatzteile bereit, damit wir bereit sind."),
        // A noun before a verb is no particle, though a particle is spelt as it is ("Teil"; #354).
        ("Ich prüfe die Schleuse, indem ich auf jedes Teil achte.", "Ich prüfe die Schleuse, indem ich auf jedes Teil achte."),
        ("Ich arbeite gern, weil ich an jeder Übung teil nehme.", "Ich arbeite gern, weil ich an jeder Übung teilnehme."),
        ("I check the gates before the barges come in.", "I check the gates before the barges come in."),
    ])
    func joined(text: String, expected: String) {
        #expect(SeparableVerbs.joined(in: text) == expected)
    }

    /// A verb of a subordinate clause split into the verb and the particle a main clause ends with (#359): the longest particle, and
    /// none for a verb that only begins like one.
    @Test("A separable verb splits at its whole particle; a verb that only begins like one stays whole", arguments: [
        ("einteile", "teile ein"), ("sicherstelle", "stelle sicher"), ("herunterlade", "lade herunter"),
        ("einarbeite", "arbeite ein"), ("ausarbeitete", "arbeitete aus"), ("anordne", "ordne an"), ("teilnehme", "nehme teil"),
        ("herrichte", "richte her"), ("hervorhebe", "hebe hervor"), ("vorausplane", "plane voraus"),
        ("analysiere", nil), ("analysierte", nil), ("abonnierte", nil), ("antworte", nil), ("hinterlege", nil), ("hindere", nil),
        ("herrsche", nil), ("angelte", nil), ("ankere", nil), ("einigte", nil), ("durchführe", nil), ("plane", nil), ("leitete", nil),
    ] as [(String, String?)])
    func split(verb: String, expected: String?) {
        #expect(SeparableVerbs.split(verb).map { "\($0.verb) \($0.particle)" } == expected)
    }
}

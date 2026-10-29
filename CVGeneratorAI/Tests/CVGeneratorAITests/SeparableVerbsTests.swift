import Testing
@testable import CVGeneratorAI

/// The German separable verbs a request wrote apart at the end of a subordinate clause, joined (#354, round 4). The sentences are
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
        ("I check the gates before the barges come in.", "I check the gates before the barges come in."),
    ])
    func joined(text: String, expected: String) {
        #expect(SeparableVerbs.joined(in: text) == expected)
    }
}

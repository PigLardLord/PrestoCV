import Testing
@testable import CVGeneratorAI

/// A summary sentence on a job's work that says one of its duties again in other words (#354, round 15).
struct NearCopyTests {
    @Test("A sentence that holds 60% or more of a duty's content words, past the title, nearly copies it; one on what the work involves does not",
          arguments: [
              ("Ich installiere elektrische Anlagen in Neubauten mit Sorgfalt und Präzision.", ["Ich installiere Anlagen in Neubauten."], "Elektriker", true),
              ("Als Elektriker plane ich die Elektroinstallation von Wohnhäusern und Gewerbebauten.", ["Ich installiere Anlagen in Neubauten."], "Elektriker", false),
              ("I train junior technicians in every rehearsal and show.", ["I train the junior technicians.", "I plan the rehearsals."], "head of sound", true),
              ("As a head of sound, I make sure every show sounds clear and balanced.", ["I train the junior technicians."], "head of sound", false),
              // A duty of one content word is no task to copy.
              ("Ich arbeite sorgfältig mit Kabeln.", ["Ich verkabele."], "Elektriker", false),
          ])
    func nearCopy(sentence: String, duties: [String], title: String, copies: Bool) {
        #expect(CVDataSanitizer.nearlyCopies(sentence, duties: duties, title: title) == copies)
    }
}

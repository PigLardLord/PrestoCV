import Testing
@testable import CVGeneratorAI

/// A summary sentence on a job's work that says one of its duties again (#354).
struct NearCopyTests {
    @Test("A sentence that shares more content words with a duty than it adds, and adds less than two past the title, copies it; one that joins two duties, says how, or names a kept tool or quality the duty does not, adds to it (#354)",
          arguments: [
              ("Ich installiere elektrische Anlagen in Neubauten.", ["Ich installiere Anlagen in Neubauten."], "Elektriker", [], true),
              ("Ich installiere elektrische Anlagen in Neubauten mit Sorgfalt und Präzision.", ["Ich installiere Anlagen in Neubauten."], "Elektriker", [], false),
              ("Als Elektriker plane ich die Elektroinstallation von Wohnhäusern und Gewerbebauten.", ["Ich installiere Anlagen in Neubauten."], "Elektriker", [], false),
              ("I train junior technicians in every rehearsal and show.", ["I train the junior technicians.", "I plan the rehearsals."], "head of sound", [], false),
              ("Ich arbeite sorgfältig mit Kabeln.", ["Ich verkabele."], "Elektriker", [], false),
              ("Preparo i piatti principali e le verdure.", ["Preparo i piatti principali e taglio le verdure."], "cuoco", ["padella"], true),
              ("Preparo i piatti principali e taglio le verdure fresche.", ["Preparo i piatti principali e taglio le verdure."], "cuoco", [], true),
              ("Preparo i piatti principali e taglio le verdure con cura e pazienza.", ["Preparo i piatti principali e taglio le verdure."], "cuoco", [], false),
              ("Preparo i piatti principali e servo i clienti in sala.", ["Preparo i piatti principali.", "Servo i clienti in sala."], "cuoco", [], false),
              ("Preparo i piatti principali con la padella.", ["Preparo i piatti principali e taglio le verdure."], "cuoco", ["padella"], false),
              ("Preparo i piatti principali con precisione.", ["Preparo i piatti principali e taglio le verdure."], "cuoco", ["precisione"], false),
              // A tool the duty names too adds nothing to it.
              ("Preparo i piatti principali con la padella.", ["Preparo i piatti principali con la padella e taglio le verdure."], "cuoco", ["padella"], true),
          ] as [(String, [String], String, [String], Bool)])
    func copiesADuty(sentence: String, duties: [String], title: String, skills: [String], copies: Bool) {
        #expect(CVDataSanitizer.copiesADuty(sentence, duties: duties, title: title, skills: skills) == copies)
    }
}

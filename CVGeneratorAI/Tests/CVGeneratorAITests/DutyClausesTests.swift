import Testing
@testable import CVGeneratorAI

/// The duties a job's text says, by clause (#354, round 15); the evaluation's reader counts them the same way.
@Suite(.plainDraft)
struct DutyClausesTests {
    @Test("A sentence is one duty, and one more after a semicolon and after a comma or an \"and\" that a verb follows",
          arguments: [
              ("I plan the sound design for each production and train the junior technicians. I mix on digital consoles and edit the sound effects for the shows.", "en", 4),
              ("where I install systems in new buildings", "en", 1),
              ("I set up the PA systems and mixing the support acts", "en", 2),
              ("I ensure all equipment is properly maintained and ready for use.", "en", 1),
              ("I rigged the lights and loaded the trucks.", "en", 2),
              ("Coordino tre tecnici e gestisco i fermi impianto. Leggo gli schemi elettrici e pneumatici e uso i PLC per trovare i guasti.", "it", 4),
              ("Ich sorge dafür, dass die Stromversorgung stabil bleibt.", "de", 1),
              ("Ich installiere Anlagen in Neubauten und Altbauten.", "de", 1),
              ("Je prépare les cours; je corrige les devoirs.", "fr", 2),
              ("Gestiono las facturas, los pagos y las cuentas.", "es", 1),
          ])
    func clauses(text: String, language: String, count: Int) {
        #expect(DutyClauses.count(in: text, language: Vocabulary.Language(rawValue: language)) == count)
    }

    @Test("The typical duties a job gets come from the person's duties by clause: four said in two sentences need none, one needs two, two need one",
          arguments: [
              ("I plan the sound design for each production and train the junior technicians. I mix on digital consoles and edit the sound effects for the shows.", 0),
              ("where I install systems in new buildings", 2),
              ("I set up the PA systems and mixing the support acts", 1),
          ])
    func addingByClause(text: String, adding: Int) {
        #expect(DraftBrief.Role.adding(said: DutyClauses.count(in: text, language: .english)) == adding)
    }
}

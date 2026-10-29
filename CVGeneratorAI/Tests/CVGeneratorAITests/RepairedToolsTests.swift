import Testing
@testable import CVGeneratorAI

/// The check of the tools a request for more tools writes (#354, round 15).
struct RepairedToolsTests {
    private static func checker(_ language: String) -> CVDataSanitizer {
        CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
    }

    @Test("A repaired tool that is a kind with a purpose and its object alone goes; a named one, one with a word of its trade and a device stay",
          arguments: [
              ("it", ["sistema di tracciamento dati", "Sistema di Interscambio", "software di contabilità"], ["Sistema di Interscambio", "software di contabilità"]),
              ("fr", ["système de suivi des progrès", "logiciel de gestion de classe"], ["logiciel de gestion de classe"]),
              ("es", ["máquina de escaneo de registros", "sistema de gestión de documentos", "escáner"], ["escáner"]),
              ("en", ["document management system", "PA system", "venue management software"], ["PA system", "venue management software"]),
              ("it", ["archivio digitale", "archivio di gestione documenti"], ["archivio digitale"]),
          ])
    func generalKindGoes(language: String, tools: [String], kept: [String]) {
        #expect(Self.checker(language).repairedTools(tools, against: "Lavoro a Lecce dal 2019.") == kept)
    }

    @Test("A repaired general kind the description writes stays")
    func statedGeneralKindStays() {
        let description = "Uso ogni giorno il sistema di tracciamento dati del magazzino."

        #expect(Self.checker("it").repairedTools(["sistema di tracciamento dati"], against: description) == ["sistema di tracciamento dati"])
    }
}

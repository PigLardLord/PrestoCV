import Foundation
import Testing

// MARK: - Language Variety Tests

/// The new app speaks the varieties of Spanish and Portuguese that the 1.0 app speaks: Latin-American Spanish and
/// Brazilian Portuguese (`docs/release/store-listing.md`; migration step 5-15b, #408). A person who used 1.0 would read
/// a text of the other variety as another app's, and a catalog that mixes the two speaks no variety at all.
///
/// Each marker is a word or phrase of the other variety (the Spanish of Spain, the Portuguese of Portugal) that correct
/// Latin-American or Brazilian text of the app does not use. It is matched as a whole word, in any case, so "tu" does
/// not match "tutorial" and "a carregar" does not match "para carregar".
@Suite("Language Variety Tests")
struct LanguageVarietyTests {

    private static let catalogFile = CatalogUnderCheck.next.catalog

    /// The markers of the other variety, by language of the catalog.
    static let markersOfTheOtherVariety: [String: [String]] = [
        "es": [
            // The vosotros forms of Spain: Latin America says "ustedes" ("pueden", "tienen", "su").
            "vosotros", "vosotras", "podéis", "tenéis", "vuestro", "vuestra", "vuestros", "vuestras",
            // Spain's words for a computer and a mobile phone: Latin America says "computadora" and "celular".
            "ordenador", "ordenadores", "móvil", "móviles",
            // Spain's verb for adding: Latin America and the 1.0 app say "Agregar" ("Agrega").
            "añadir", "añade",
            // Spain's touch and hold, "Mantén pulsado": Latin America says "Mantén presionado".
            "pulsado", "pulsada",
            // Spain's compound past for a failure that has just happened: Latin America and the 1.0 app say "no se pudo"
            // ("no pudo leer").
            "ha podido", "han podido",
        ],
        "pt": [
            // Portugal's words for a file, a screen, a user, a record and a mobile phone: Brazil says "arquivo", "tela",
            // "usuário", "registro" and "celular".
            "ficheiro", "ficheiros", "ecrã", "ecrãs", "utilizador", "utilizadores", "registo", "registos", "telemóvel",
            "telemóveis",
            // Portugal's progressive, a + infinitive: Brazil says "carregando", with the gerund.
            "a carregar",
            // Portugal's verb for saving: Brazil and the 1.0 app save with "salvar" ("Salvo"). Brazil guards or puts away
            // with "guardar", which no text of the app says.
            "guardar", "guardado", "guardada", "guardados", "guardadas",
            // Portugal's verb for deleting: Brazil and the 1.0 app delete with "excluir" ("Excluir", "excluído").
            "eliminar", "eliminado", "eliminada", "eliminados", "eliminadas",
            // Portugal's Rename: Brazil and the 1.0 app say "Renomear".
            "mudar o nome",
            // Portugal's intermediate level: Brazil and the 1.0 app say "Intermediário".
            "intermédio",
            // Portugal's spelling of a section: Brazil and the 1.0 app write "seção".
            "secção", "secções",
            // The tu forms of Portugal: Brazil and the 1.0 app address the person as "você" ("seu", "sua").
            "tu", "teu", "tua", "teus", "tuas",
        ],
    ]

    /// The markers of the other variety in a text, in the order of the list.
    static func markers(in text: String, language: String) -> [String] {
        (markersOfTheOtherVariety[language] ?? []).filter { marker in
            text.range(
                of: "\\b\(NSRegularExpression.escapedPattern(for: marker))\\b",
                options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    @Test("The new app's Spanish is Latin-American and its Portuguese Brazilian, as the 1.0 app's", arguments: ["es", "pt"])
    func textsAreOfTheAppsVariety(_ language: String) throws {
        let catalog = try LocalizationCatalog(contentsOf: Repository.root.appendingPathComponent(Self.catalogFile))
        var found: [String] = []
        for key in catalog.keys {
            for text in catalog.texts(of: key, in: language) ?? [] {
                let markers = Self.markers(in: text, language: language)
                if !markers.isEmpty { found.append("\(key): \(markers) in \"\(text)\"") }
            }
        }

        #expect(!catalog.keys.isEmpty, "\(Self.catalogFile) has no keys")
        #expect(found.isEmpty, "\(found.count) texts of the other variety: \(found)")
    }

    @Test("A marker is found as a whole word in any case, and correct text of the app's variety has none", arguments: [
        ("Não foi possível ler o ficheiro.", "pt", ["ficheiro"]),
        ("Mudar o nome do CV", "pt", ["mudar o nome"]),
        ("A carregar os teus CV…", "pt", ["a carregar", "teus"]),
        ("Añadir idioma", "es", ["añadir"]),
        ("No se han podido leer tus CV. Mantén pulsada una entrada.", "es", ["pulsada", "han podido"]),
        ("Carregando seus currículos…", "pt", []),
        ("Para carregar o arquivo, toque em Arquivos na tela.", "pt", []),
        ("Excluir “%@”? O currículo salvo será excluído.", "pt", []),
        ("Um tutorial de registro do usuário", "pt", []),
        ("Agregar idioma", "es", []),
        ("No se pudo abrir el CV. Guárdalo en el celular.", "es", []),
        ("Guardar como copia", "es", []),
    ])
    func markersAreWholeWords(text: String, language: String, markers: [String]) {
        #expect(Self.markers(in: text, language: language) == markers)
    }
}

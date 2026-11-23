import Foundation
import Testing

// MARK: - Language Variety Tests

/// The new app speaks the varieties of Spanish and Portuguese that the 1.0 app speaks: Latin-American Spanish and
/// Brazilian Portuguese (`docs/release/store-listing.md`; migration step 5-15b, #408). A person who used 1.0 would read
/// a text of the other variety as another app's, and a catalog that mixes the two speaks no variety at all.
///
/// Each marker is a word that the app's texts in their variety have no use for in any meaning: a word only the other
/// variety uses (the Spanish of Spain, the Portuguese of Portugal), or a tu form of Portuguese, which only addresses the
/// person, whom the app addresses as "você". It is matched as a whole word, in any case, so "tu" does not match
/// "tutorial". A word that the variety uses in another meaning is no marker, even where the 1.0 app chose another word
/// for the app's meaning: Brazil keeps things with "guardar" and removes them with "eliminar", while the app saves with
/// "salvar" and deletes with "excluir"; Latin America also says "añadir" and "versión móvil". Those choices are in the
/// texts, and a person reads them; this check would reject a correct text for them.
@Suite("Language Variety Tests")
struct LanguageVarietyTests {

    private static let catalogFile = CatalogUnderCheck.next.catalog

    /// The markers of the other variety, by language of the catalog.
    static let markersOfTheOtherVariety: [String: [String]] = [
        "es": [
            // The vosotros forms of Spain: Latin America says "ustedes" ("pueden", "tienen", "su").
            "vosotros", "vosotras", "podéis", "tenéis", "vuestro", "vuestra", "vuestros", "vuestras",
            // Spain's word for a computer: Latin America says "computadora".
            "ordenador", "ordenadores",
        ],
        "pt": [
            // Portugal's words for a file, a screen, a user, a record and a mobile phone: Brazil says "arquivo", "tela",
            // "usuário", "registro" and "celular".
            "ficheiro", "ficheiros", "ecrã", "ecrãs", "utilizador", "utilizadores", "registo", "registos", "telemóvel",
            "telemóveis",
            // Portugal's spelling of a section: Brazil writes "seção".
            "secção", "secções",
            // The tu forms, Portugal's way to address the person: the app, as 1.0, says "você" ("seu", "sua").
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
        ("Não foi possível ler o Ficheiro.", "pt", ["ficheiro"]),
        ("Toca no ecrã para abrir os teus registos.", "pt", ["ecrã", "registos", "teus"]),
        ("Podéis abrirlo desde vuestro ordenador.", "es", ["podéis", "vuestro", "ordenador"]),
        ("Carregando seus currículos…", "pt", []),
        ("Para carregar o arquivo, toque em Arquivos na tela.", "pt", []),
        ("Excluir “%@”? O currículo salvo será excluído.", "pt", []),
        ("Um tutorial de registro do usuário", "pt", []),
        ("Para guardar o celular, escolha uma gaveta.", "pt", []),
        ("Eliminar as linhas duplicadas do currículo", "pt", []),
        ("Por intermédio da escola, você fez o curso.", "pt", []),
        ("Você pode mudar o nome do arquivo.", "pt", []),
        ("O app começou a carregar o arquivo.", "pt", []),
        ("Agregar idioma", "es", []),
        ("No se pudo abrir el CV. Guárdalo en el celular.", "es", []),
        ("Puedes añadir otro CV.", "es", []),
        ("Abre la versión móvil del sitio.", "es", []),
        ("El botón pulsado se ve más oscuro.", "es", []),
        ("Ella ha podido volver al trabajo.", "es", []),
        ("Guardar como copia", "es", []),
    ])
    func markersAreWholeWords(text: String, language: String, markers: [String]) {
        #expect(Self.markers(in: text, language: language) == markers)
    }
}

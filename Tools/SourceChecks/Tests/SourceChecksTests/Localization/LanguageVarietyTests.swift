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
            // The verbs' tu forms, which address the person as "tu" as the pronouns do, in a text with no pronoun:
            // in the present ("podes"), the present subjunctive ("não envies"), the future subjunctive and the
            // personal infinitive ("se precisares", "antes de o enviares") and the past ("o que fizeste"). The app
            // says "você pode", "não envie", "se precisar", "antes de enviá-lo" and "o que você fez". A tu form that
            // is also another word is no marker: the imperatives "confirma" and "troca" are also "ele confirma" and
            // "ele troca", "precisas" is also "datas precisas", "escolhas" also "as escolhas" and "deste" also
            // "deste currículo". "estás" is matched with its accent, so "estas datas" is no match.
            "podes", "tens", "queres", "sabes", "estás", "vais", "deves", "consegues", "preferes", "gostas", "escolhes",
            "dizes", "fazes", "ficas", "dás", "vês", "és", "envias", "adicionas", "abres", "usas", "escreves",
            "possas", "tenhas", "queiras", "sejas", "faças", "precises", "envies", "esqueças", "digas",
            "precisares", "enviares", "escolheres", "quiseres", "puderes", "tiveres", "fizeres", "fores", "estiveres",
            "usares", "preferires", "adicionares", "guardares", "criares",
            "foste", "fizeste", "escolheste", "enviaste", "guardaste",
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
        ("Confirma cada campo antes de o enviares. Podes copiá-lo, se quiseres.", "pt",
         ["podes", "enviares", "quiseres"]),
        ("Se tens dúvidas, adiciona o que precisares com o nível que escolheres.", "pt",
         ["tens", "precisares", "escolheres"]),
        ("Não te esqueças do que fizeste nem envies o CV se não estás pronto.", "pt",
         ["estás", "envies", "esqueças", "fizeste"]),
        ("Queres saber se consegues? Sabes o que preferes, vais ver que deves tentar.", "pt",
         ["queres", "sabes", "vais", "deves", "consegues", "preferes"]),
        ("Gostas do que escolhes? Dizes o que fazes, ficas com o que dás e vês que és capaz.", "pt",
         ["gostas", "escolhes", "dizes", "fazes", "ficas", "dás", "vês", "és"]),
        ("Abres o documento, usas o modelo, escreves o resumo, adicionas a foto e envias o CV.", "pt",
         ["envias", "adicionas", "abres", "usas", "escreves"]),
        ("Embora não possas nem tenhas tempo, não queiras desistir nem sejas tímido.", "pt",
         ["possas", "tenhas", "queiras", "sejas"]),
        ("Talvez precises de ajuda: faças o que faças, não digas que não.", "pt", ["faças", "precises", "digas"]),
        ("Quando puderes e tiveres tempo, faz o CV; quando o fizeres e fores à entrevista, sorri.", "pt",
         ["puderes", "tiveres", "fizeres", "fores"]),
        ("Se estiveres calmo e usares o modelo que preferires, corre bem.", "pt",
         ["estiveres", "usares", "preferires"]),
        ("Antes de adicionares a foto, guardares o CV e criares outro, vê o que já foste.", "pt",
         ["adicionares", "guardares", "criares", "foste"]),
        ("Revê o que escolheste, o que enviaste e o que guardaste.", "pt", ["escolheste", "enviaste", "guardaste"]),
        ("Podéis abrirlo desde vuestro ordenador.", "es", ["podéis", "vuestro", "ordenador"]),
        ("Confira cada campo antes de enviá-lo. Você pode copiá-lo, se quiser.", "pt", []),
        ("Se tiver dúvidas, adicione o que precisar com o nível que escolher.", "pt", []),
        ("O app confirma cada campo e troca o cargo pelo empregador.", "pt", []),
        ("Datas precisas e boas escolhas: estas linhas são deste currículo.", "pt", []),
        ("Ele vê o que você dá e escolhe o que é seu.", "pt", []),
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

import Foundation
import Testing

/// A fact a description states about the person, which a faithful draft keeps (#202).
struct ExpectedFact: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    enum Kind: String, Codable, CaseIterable, Sendable {
        case name, title, employer, school, language, skill
    }

    let kind: Kind
    /// The words that show the fact is kept, the full form first: a draft keeps it when one field of its kind holds one of them.
    let forms: [String]

    var description: String { "\(kind.rawValue) \"\(forms[0])\"" }

    static func name(_ forms: String...) -> ExpectedFact { ExpectedFact(kind: .name, forms: forms) }
    static func title(_ forms: String...) -> ExpectedFact { ExpectedFact(kind: .title, forms: forms) }
    static func employer(_ forms: String...) -> ExpectedFact { ExpectedFact(kind: .employer, forms: forms) }
    static func school(_ forms: String...) -> ExpectedFact { ExpectedFact(kind: .school, forms: forms) }
    static func language(_ forms: String...) -> ExpectedFact { ExpectedFact(kind: .language, forms: forms) }
    static func skill(_ forms: String...) -> ExpectedFact { ExpectedFact(kind: .skill, forms: forms) }
}

/// A description the drafting evaluation gives the model, with what a faithful draft of it keeps and must not hold.
struct DraftingInput: Sendable, CustomTestStringConvertible {
    enum Kind: String, Codable, Sendable {
        /// The app's own example description (`ai.generation.example_text`).
        case example
        /// An ordinary description: two jobs, a school, an email, a phone, languages, hobbies.
        case plain
        /// A description with sentences that look like facts about the person and are not.
        case traps
        /// A title and a few words, as people often write (#354): the draft writes around the title alone.
        case sparse
        /// No role, study or field at all: the draft writes nothing around the facts (ADR 0031).
        case noRole
    }

    let id: String
    let kind: Kind
    /// BCP 47 code of the language the description is written in.
    let language: String
    let description: String
    let facts: [ExpectedFact]
    /// Words of the description that no draft may hold anywhere: another person's fact, a wish or a plan, a denial, a figure of
    /// the team (ADR 0023 rules (b) to (f), ADR 0028).
    let traps: [String]

    var testDescription: String { id }
}

extension DraftingInput {
    /// The person's role or field, in the description's language, as a reader of the draft's pertinence item sees it; nil when the
    /// description names none.
    var field: String? { DraftingInputs.fields[id]?.field }

    /// Words of other trades that no summary, job description or skill of a draft of this input may hold (#354): a hit is a hard
    /// finding. Written by hand before the first run, from `DraftingInputs.tools` less the tools of the person's own trade.
    var offField: [String] {
        guard let own = DraftingInputs.fields[id]?.own else { return [] }
        return DraftingInputs.tools.filter { !own.contains($0) }
    }

    /// Whether the description states `phrase`: its words, in any case, one right after the other and each of them whole. The trap
    /// "20" is not in "2024" or "20.5 beds", "Tom" is not in "Tomorrow", and an address is not in a longer one.
    func states(_ phrase: String) -> Bool {
        let wanted = Self.words(phrase)
        let stated = Self.words(description)
        guard !wanted.isEmpty, wanted.count <= stated.count else { return false }
        return (0...(stated.count - wanted.count)).contains { Array(stated[$0..<($0 + wanted.count)]) == wanted }
    }

    /// The words of `text` in lowercase: runs of letters and digits, where one of `.,@/:+_-` between two of them keeps them in one
    /// word, so that a number, an address or a compound is a single word. Where in doubt the words stay together: a phrase is then
    /// not found, which a test shows, instead of found in the middle of something else.
    static func words(_ text: String) -> [String] {
        let characters = Array(text.lowercased())
        var words: [String] = []
        var current = ""
        for (index, character) in characters.enumerated() {
            if character.isLetter || character.isNumber {
                current.append(character)
                continue
            }
            let next = characters.indices.contains(index + 1) ? characters[index + 1] : nil
            let joins = ".,@/:+_-".contains(character) && !current.isEmpty && (next?.isLetter == true || next?.isNumber == true)
            if joins {
                current.append(character)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }
}

/// The 30 inputs of the drafting evaluation: the 6 example descriptions of the app, read from its string catalog so that they
/// cannot drift, and 4 written descriptions per language (plain, with traps, sparse, with no role). Every person, address and number
/// in them is invented.
enum DraftingInputs {
    static let languages = ["en", "it", "de", "es", "fr", "pt"]

    static func all() throws -> [DraftingInput] {
        try examples() + written + short
    }

    // MARK: - Fields

    /// Tools of one trade each, which a draft of another trade has no reason to write.
    static let tools = ["Kubernetes", "Java", "Photoshop", "InDesign", "AutoCAD", "HACCP", "KNX", "SAP"]

    /// The field of each input with a role, and the tools of `tools` its trade may use.
    static let fields: [String: (field: String, own: Set<String>)] = [
        "example-en": ("primary school teaching", []), "example-it": ("insegnamento nella scuola primaria", []),
        "example-de": ("Unterricht an der Grundschule", []), "example-es": ("enseñanza primaria", []),
        "example-fr": ("enseignement primaire", []), "example-pt": ("ensino fundamental", []),
        "en-plain": ("warehouse logistics", ["SAP"]), "en-traps": ("nursing", []),
        "it-plain": ("cucina", ["HACCP"]), "it-traps": ("amministrazione", ["SAP"]),
        "de-plain": ("Elektroinstallation", ["KNX", "AutoCAD", "SAP"]), "de-traps": ("Physiotherapie", []),
        "es-plain": ("diseño gráfico", ["Photoshop", "InDesign", "AutoCAD"]), "es-traps": ("contabilidad", ["SAP"]),
        "fr-plain": ("boulangerie", ["HACCP"]), "fr-traps": ("informatique", ["Kubernetes", "Java", "SAP", "KNX"]),
        "pt-plain": ("enfermagem", []), "pt-traps": ("programação", ["Kubernetes", "Java", "SAP"]),
        "en-sparse": ("plumbing", []), "it-sparse": ("sviluppo iOS", ["Kubernetes", "Java", "Photoshop", "SAP"]),
        "de-sparse": ("Bäckerei", ["HACCP"]), "es-sparse": ("hostelería", ["HACCP"]),
        "fr-sparse": ("comptabilité", ["SAP"]), "pt-sparse": ("transporte de cargas", []),
    ]

    // MARK: - The app's examples

    static func examples() throws -> [DraftingInput] {
        try languages.map { language in
            DraftingInput(
                id: "example-\(language)", kind: .example, language: language, description: try exampleText(in: language),
                facts: exampleFacts[language] ?? [], traps: []
            )
        }
    }

    /// The example description of the app in `language`, as its string catalog holds it.
    static func exampleText(in language: String) throws -> String {
        let catalogURL = SourceTree.root.appendingPathComponent("PrestoCV/Localizable.xcstrings")
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        let strings = catalog?["strings"] as? [String: [String: Any]]
        let localizations = strings?["ai.generation.example_text"]?["localizations"] as? [String: [String: Any]]
        guard let value = (localizations?[language]?["stringUnit"] as? [String: Any])?["value"] as? String else {
            throw CatalogError.missingExample(language)
        }
        return value
    }

    enum CatalogError: Error {
        case missingExample(String)
    }

    private static let exampleFacts: [String: [ExpectedFact]] = [
        "en": [
            .name("Maria Rossi"), .title("primary school teacher", "teacher"), .employer("Don Milani"), .employer("nursery"),
            .school("University of Bologna"), .language("Italian"), .language("English"),
        ],
        "it": [
            .name("Maria Rossi"), .title("insegnante di scuola primaria", "insegnante"), .employer("Don Milani"),
            .employer("asilo nido"), .school("Università di Bologna"), .language("italiano"), .language("inglese"),
        ],
        "de": [
            .name("Maria Rossi"), .title("Grundschullehrerin"), .employer("Don Milani"), .employer("Kinderkrippe"),
            .school("Universität Bologna"), .language("Italienisch"), .language("Englisch"),
        ],
        "es": [
            .name("Maria Rossi"), .title("maestra de primaria", "maestra"), .employer("Don Milani"), .employer("guardería"),
            .school("Universidad de Bolonia"), .language("italiano"), .language("inglés"),
        ],
        "fr": [
            .name("Maria Rossi"), .title("institutrice"), .employer("Don Milani"), .employer("crèche"),
            .school("université de Bologne"), .language("italien"), .language("anglais"),
        ],
        "pt": [
            .name("Maria Rossi"), .title("professora do ensino fundamental", "professora"), .employer("Don Milani"),
            .employer("creche"), .school("Universidade de Bolonha"), .language("italiano"), .language("inglês"),
        ],
    ]

    // MARK: - Written descriptions

    static let written: [DraftingInput] = [
        DraftingInput(
            id: "en-plain", kind: .plain, language: "en",
            description: """
            My name is Daniel Hart and I am a warehouse supervisor. Since 2019 I have worked at Northfield Logistics in Leeds, \
            where I plan the night shifts. From 2014 to 2019 I was a forklift driver at Kestrel Foods. I studied logistics at \
            Leeds City College and finished in 2013. I can use SAP and Excel. You can write to daniel.hart@example.com or call \
            +39 333 123 4501. I speak English and Polish. In my free time I play football and I bake bread.
            """,
            facts: [
                .name("Daniel Hart"), .title("warehouse supervisor", "supervisor"), .employer("Northfield Logistics"),
                .employer("Kestrel Foods"), .school("Leeds City College"), .language("English"), .language("Polish"),
                .skill("SAP"), .skill("Excel"),
            ],
            traps: []
        ),
        DraftingInput(
            id: "en-traps", kind: .traps, language: "en",
            description: """
            I'm Priya Nolan, a registered nurse in Bristol. Since 2018 I have worked on the children's ward of St Brigid's \
            Hospital. Before that, from 2015 to 2018, I worked at Greenway Care Home. I trained as a nurse at the University of \
            the West Country and graduated in 2015. I speak English and Hindi. My sister speaks French, and my manager's email is \
            grace.lowe@example.com. My colleague Tom works at Riverside Clinic. I would like to work as a midwife, and next year \
            I will study Spanish. I have never used Epic. Our ward team of 20 nurses cut waiting times by 30%. My email is \
            priya.nolan@example.com.
            """,
            facts: [
                .name("Priya Nolan"), .title("registered nurse", "nurse"), .employer("St Brigid's Hospital", "St Brigid"),
                .employer("Greenway Care Home", "Greenway"), .school("University of the West Country"), .language("English"),
                .language("Hindi"),
            ],
            traps: ["French", "grace.lowe@example.com", "Tom", "Riverside Clinic", "midwife", "Spanish", "Epic", "20", "30"]
        ),
        DraftingInput(
            id: "it-plain", kind: .plain, language: "it",
            description: """
            Mi chiamo Luca Ferrandi e sono cuoco. Dal 2020 lavoro al ristorante Il Gabbiano di Rimini, dove preparo i primi \
            piatti. Dal 2016 al 2020 sono stato aiuto cuoco all'Hotel Belvedere di Riccione. Ho studiato all'istituto alberghiero \
            Valmarecchia e mi sono diplomato nel 2016. Conosco le norme HACCP. Potete scrivermi a luca.ferrandi@example.com o \
            chiamarmi al +39 333 123 4502. Parlo italiano e inglese. Nel tempo libero vado in bicicletta e suono la chitarra.
            """,
            facts: [
                .name("Luca Ferrandi"), .title("cuoco"), .employer("Il Gabbiano", "Gabbiano"), .employer("Hotel Belvedere"),
                .school("istituto alberghiero Valmarecchia", "Valmarecchia"), .language("italiano"), .language("inglese"),
                .skill("HACCP"),
            ],
            traps: []
        ),
        DraftingInput(
            id: "it-traps", kind: .traps, language: "it",
            description: """
            Mi chiamo Chiara Benedetti e sono impiegata amministrativa a Verona. Dal 2017 lavoro alla Ferramenta Scaligera, dove \
            gestisco le fatture dei fornitori. Prima, dal 2013 al 2017, ho lavorato allo Studio Contabile Merlini. Mi sono \
            diplomata nel 2013 all'istituto tecnico Lungadige. Parlo italiano e inglese. Mia sorella parla tedesco e l'email del \
            mio responsabile è paolo.greco@example.com. Il mio collega Marco lavora alla Cantina Le Tre Querce. Mi piacerebbe \
            diventare consulente fiscale e l'anno prossimo studierò spagnolo. Non ho mai usato SAP. Il nostro ufficio di 8 \
            persone ha ridotto i ritardi del 25%. La mia email è chiara.benedetti@example.com.
            """,
            facts: [
                .name("Chiara Benedetti"), .title("impiegata amministrativa", "impiegata"), .employer("Ferramenta Scaligera"),
                .employer("Studio Contabile Merlini", "Merlini"), .school("istituto tecnico Lungadige", "Lungadige"),
                .language("italiano"), .language("inglese"),
            ],
            traps: [
                "tedesco", "paolo.greco@example.com", "Marco", "Cantina Le Tre Querce", "consulente fiscale", "spagnolo", "SAP",
                "8", "25",
            ]
        ),
        DraftingInput(
            id: "de-plain", kind: .plain, language: "de",
            description: """
            Ich heiße Jonas Albrecht und bin Elektriker. Seit 2018 arbeite ich bei Elektro Brandner in Augsburg, wo ich Anlagen \
            in Neubauten installiere. Von 2014 bis 2018 war ich Monteur bei Haustechnik Kellner. Ich habe die Berufsschule \
            Lechfeld besucht und 2014 meine Ausbildung abgeschlossen. Ich kenne mich mit KNX aus. Sie erreichen mich unter \
            jonas.albrecht@example.com oder +39 333 123 4503. Ich spreche Deutsch und Englisch. In meiner Freizeit gehe ich \
            klettern und spiele Schach.
            """,
            facts: [
                .name("Jonas Albrecht"), .title("Elektriker"), .employer("Elektro Brandner", "Brandner"),
                .employer("Haustechnik Kellner", "Kellner"), .school("Berufsschule Lechfeld", "Lechfeld"), .language("Deutsch"),
                .language("Englisch"), .skill("KNX"),
            ],
            traps: []
        ),
        DraftingInput(
            id: "de-traps", kind: .traps, language: "de",
            description: """
            Ich bin Lena Hoffmeister, Physiotherapeutin in Kassel. Seit 2019 arbeite ich in der Praxis Sonnenhof. Davor war ich \
            von 2016 bis 2019 in der Reha-Klinik Waldblick tätig. Ich habe 2016 meine Ausbildung an der Fachschule für \
            Physiotherapie Kassel abgeschlossen. Ich spreche Deutsch und Englisch. Meine Schwester spricht Französisch, und die \
            E-Mail meiner Chefin ist anja.krause@example.com. Mein Kollege Felix arbeitet in der Praxis Am Stadtpark. Ich möchte \
            gern als Osteopathin arbeiten, und nächstes Jahr lerne ich Italienisch. Mit Ultraschall habe ich nie gearbeitet. \
            Unser Team aus 12 Therapeuten behandelt jeden Monat 500 Patienten. Meine E-Mail ist lena.hoffmeister@example.com.
            """,
            facts: [
                .name("Lena Hoffmeister"), .title("Physiotherapeutin"), .employer("Praxis Sonnenhof", "Sonnenhof"),
                .employer("Reha-Klinik Waldblick", "Waldblick"), .school("Fachschule für Physiotherapie", "Fachschule"),
                .language("Deutsch"), .language("Englisch"),
            ],
            traps: [
                "Französisch", "anja.krause@example.com", "Felix", "Praxis Am Stadtpark", "Osteopathin", "Italienisch",
                "Ultraschall", "12", "500",
            ]
        ),
        DraftingInput(
            id: "es-plain", kind: .plain, language: "es",
            description: """
            Me llamo Carmen Ibarra y soy diseñadora gráfica. Desde 2021 trabajo en el estudio Lumbre Creativa de Valencia, donde \
            diseño carteles y catálogos. De 2017 a 2021 fui maquetadora en la editorial Mar de Letras. Estudié en la Escuela de \
            Arte Turia y terminé en 2017. Uso Illustrator e InDesign. Podéis escribirme a carmen.ibarra@example.com o llamarme al \
            +39 333 123 4504. Hablo español y catalán. En mi tiempo libre hago fotografía y voy a nadar.
            """,
            facts: [
                .name("Carmen Ibarra"), .title("diseñadora gráfica", "diseñadora"), .employer("Lumbre Creativa"),
                .employer("Mar de Letras"), .school("Escuela de Arte Turia", "Turia"), .language("español"), .language("catalán"),
                .skill("Illustrator"), .skill("InDesign"),
            ],
            traps: []
        ),
        DraftingInput(
            id: "es-traps", kind: .traps, language: "es",
            description: """
            Soy Diego Salcedo, contable en Zaragoza. Desde 2018 trabajo en Transportes Ebro Norte, donde llevo la contabilidad de \
            la empresa. Antes, de 2014 a 2018, trabajé en la gestoría Aranda y Molina. Estudié en la Universidad del Moncayo y me \
            gradué en 2014. Hablo español e inglés. Mi hermana habla alemán y el correo de mi jefe es rafael.ortiz@example.com. \
            Mi compañero Javier trabaja en Seguros Pilar. Me gustaría trabajar como auditor y el año que viene estudiaré francés. \
            Nunca he usado SAP. Nuestro departamento de 15 personas atiende a 300 clientes. Mi correo es \
            diego.salcedo@example.com.
            """,
            facts: [
                .name("Diego Salcedo"), .title("contable"), .employer("Transportes Ebro Norte", "Ebro Norte"),
                .employer("Aranda y Molina"), .school("Universidad del Moncayo", "Moncayo"), .language("español"),
                .language("inglés"),
            ],
            traps: ["alemán", "rafael.ortiz@example.com", "Javier", "Seguros Pilar", "auditor", "francés", "SAP", "15", "300"]
        ),
        DraftingInput(
            id: "fr-plain", kind: .plain, language: "fr",
            description: """
            Je m'appelle Camille Durand et je suis boulangère. Depuis 2019, je travaille à la Boulangerie des Tilleuls à Nantes, \
            où je prépare le pain et les viennoiseries. De 2015 à 2019, j'ai été vendeuse à la Pâtisserie Bellevue. J'ai obtenu \
            mon CAP au lycée professionnel Les Mauves en 2015. Je connais les règles HACCP. Vous pouvez m'écrire à \
            camille.durand@example.com ou m'appeler au +39 333 123 4505. Je parle français et anglais. Pendant mon temps libre, \
            je fais du vélo et j'aime jardiner.
            """,
            facts: [
                .name("Camille Durand"), .title("boulangère"), .employer("Boulangerie des Tilleuls", "Tilleuls"),
                .employer("Pâtisserie Bellevue", "Bellevue"), .school("lycée professionnel Les Mauves", "Les Mauves"),
                .language("français"), .language("anglais"), .skill("HACCP"),
            ],
            traps: []
        ),
        DraftingInput(
            id: "fr-traps", kind: .traps, language: "fr",
            description: """
            Je suis Hugo Lefèvre, technicien informatique à Lyon. Depuis 2020, je travaille chez Rhône Services Numériques, où \
            j'installe les postes des clients. Avant, de 2016 à 2020, j'ai travaillé chez Copilux. J'ai obtenu mon diplôme à \
            l'IUT de la Croix-Rousse en 2016. Je parle français et anglais. Ma sœur parle italien et l'adresse de ma responsable \
            est nadia.roux@example.com. Mon collègue Antoine travaille chez Datalyon. J'aimerais devenir administrateur réseau, \
            et l'année prochaine j'apprendrai l'allemand. Je n'ai jamais utilisé Linux. Notre équipe de 10 techniciens gère 1500 \
            ordinateurs. Mon adresse est hugo.lefevre@example.com.
            """,
            facts: [
                .name("Hugo Lefèvre"), .title("technicien informatique", "technicien"),
                .employer("Rhône Services Numériques", "Services Numériques"), .employer("Copilux"),
                .school("IUT de la Croix-Rousse", "Croix-Rousse"), .language("français"), .language("anglais"),
            ],
            traps: [
                "italien", "nadia.roux@example.com", "Antoine", "Datalyon", "administrateur réseau", "allemand", "Linux", "10",
                "1500",
            ]
        ),
        DraftingInput(
            id: "pt-plain", kind: .plain, language: "pt",
            description: """
            Chamo-me Beatriz Moura e sou enfermeira. Desde 2018 trabalho no Hospital da Ribeira, em Coimbra, onde cuido de \
            doentes da cirurgia. De 2014 a 2018 trabalhei no Centro de Saúde de Vale Verde. Estudei na Escola Superior de Saúde \
            do Mondego e terminei o curso em 2014. Tenho formação em suporte básico de vida. Pode escrever-me para \
            beatriz.moura@example.com ou ligar para +39 333 123 4506. Falo português e inglês. Nos tempos livres gosto de ler e \
            de correr.
            """,
            facts: [
                .name("Beatriz Moura"), .title("enfermeira"), .employer("Hospital da Ribeira", "Ribeira"),
                .employer("Centro de Saúde de Vale Verde", "Vale Verde"), .school("Escola Superior de Saúde do Mondego", "Mondego"),
                .language("português"), .language("inglês"), .skill("suporte básico de vida"),
            ],
            traps: []
        ),
        DraftingInput(
            id: "pt-traps", kind: .traps, language: "pt",
            description: """
            Sou Tiago Ferreira, programador em Porto Alegre. Desde 2019 trabalho na Sulware Sistemas, onde desenvolvo \
            aplicativos para lojas. Antes, de 2015 a 2019, trabalhei na agência Pixel Gaúcho. Estudei na Universidade do Guaíba \
            e me formei em 2015. Falo português e espanhol. Minha irmã fala japonês e o e-mail do meu chefe é \
            marcos.lima@example.com. Meu colega Rafael trabalha na Nuvem Azul Tecnologia. Eu gostaria de trabalhar como arquiteto \
            de software e no ano que vem vou estudar alemão. Nunca usei Kotlin. Nossa equipe de 9 pessoas aumentou as vendas em \
            40%. Meu e-mail é tiago.ferreira@example.com.
            """,
            facts: [
                .name("Tiago Ferreira"), .title("programador"), .employer("Sulware Sistemas", "Sulware"),
                .employer("Pixel Gaúcho"), .school("Universidade do Guaíba", "Guaíba"), .language("português"),
                .language("espanhol"),
            ],
            traps: [
                "japonês", "marcos.lima@example.com", "Rafael", "Nuvem Azul Tecnologia", "arquiteto de software", "alemão",
                "Kotlin", "9", "40",
            ]
        ),
    ]

    // MARK: - Sparse, and with no role

    /// Per language a description of a title and a few words, and one that names no role, study or field (#354).
    static let short: [DraftingInput] = [
        DraftingInput(
            id: "en-sparse", kind: .sparse, language: "en",
            description: "I am a plumber and I fix pipes, taps and boilers in people's homes.",
            facts: [.title("plumber")], traps: []
        ),
        DraftingInput(
            id: "en-norole", kind: .noRole, language: "en",
            description: "I like long walks with my dog, reading crime novels and cooking for my friends at the weekend.",
            facts: [], traps: []
        ),
        DraftingInput(
            id: "it-sparse", kind: .sparse, language: "it",
            description: "Sono uno sviluppatore iOS e scrivo applicazioni per iPhone e iPad.",
            facts: [.title("sviluppatore iOS", "sviluppatore")], traps: []
        ),
        DraftingInput(
            id: "it-norole", kind: .noRole, language: "it",
            description: "Mi piace camminare in montagna con il mio cane, leggere romanzi gialli e cucinare per gli amici.",
            facts: [], traps: []
        ),
        DraftingInput(
            id: "de-sparse", kind: .sparse, language: "de",
            description: "Ich bin Bäckerin und backe jeden Morgen Brot, Brötchen und Kuchen für unsere Kunden.",
            facts: [.title("Bäckerin")], traps: []
        ),
        DraftingInput(
            id: "de-norole", kind: .noRole, language: "de",
            description: "Ich gehe gern mit meinem Hund spazieren, lese Krimis und koche am Wochenende für meine Freunde.",
            facts: [], traps: []
        ),
        DraftingInput(
            id: "es-sparse", kind: .sparse, language: "es",
            description: "Soy camarero y atiendo a los clientes en la terraza y en la barra del bar.",
            facts: [.title("camarero")], traps: []
        ),
        DraftingInput(
            id: "es-norole", kind: .noRole, language: "es",
            description: "Me gusta pasear con mi perro, leer novelas policíacas y cocinar para mis amigos los fines de semana.",
            facts: [], traps: []
        ),
        DraftingInput(
            id: "fr-sparse", kind: .sparse, language: "fr",
            description: "Je suis comptable et je tiens les comptes de petites entreprises de mon quartier.",
            facts: [.title("comptable")], traps: []
        ),
        DraftingInput(
            id: "fr-norole", kind: .noRole, language: "fr",
            description: "J'aime me promener avec mon chien, lire des romans policiers et cuisiner pour mes amis le week-end.",
            facts: [], traps: []
        ),
        DraftingInput(
            id: "pt-sparse", kind: .sparse, language: "pt",
            description: "Sou motorista de caminhão e faço entregas de mercadorias pelo interior do estado.",
            facts: [.title("motorista de caminhão", "motorista")], traps: []
        ),
        DraftingInput(
            id: "pt-norole", kind: .noRole, language: "pt",
            description: "Gosto de passear com o meu cão, ler romances policiais e cozinhar para os amigos ao fim de semana.",
            facts: [], traps: []
        ),
    ]
}

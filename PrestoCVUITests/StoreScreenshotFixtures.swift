import Foundation

/// The fictional person of the App Store screenshots in one language of the app: the CVs the list shows, the
/// description typed on the AI screen, and the CV that holds only the facts of that description. The people, the
/// employers and the schools are made up; the e-mail addresses are at example.com, and nobody has a phone number.
struct StoreScreenshotFixture {
    let language: String
    let locale: String
    let name: String
    let email: String
    /// The name of the complete CV in the list
    let completeName: String
    /// The CV the export screens show, complete and on one page
    let complete: CV
    /// The CVs of the list after the complete one: the same CV adapted to other jobs, each a name and a title
    let adaptations: [(name: String, title: String)]
    /// What the person types on the AI screen
    let description: String
    /// The name of the CV with only the facts of the description: short, so that the editor's bar shows it whole
    let draftName: String
    /// The CV with only the facts of the description: everything it does not mention is blank
    let draft: CV

    struct CV {
        var title: String
        var location: String
        var email = ""
        var profile = ""
        var experience: [Entry]
        var education: [Entry]
        var skills: [(name: String, level: Int)] = []
        var languages: [(name: String, level: String)]
        var interests: [String]
    }

    /// A job or a school: what, where, when and how it went
    struct Entry {
        var title: String
        var place: String
        var location = ""
        var period: String
        var description = ""
    }

    static let all: [StoreScreenshotFixture] = [english, german, italian, spanish, french, portuguese]

    static func fixture(for language: String) -> StoreScreenshotFixture? {
        all.first { $0.language == language }
    }
}

// MARK: - English

extension StoreScreenshotFixture {
    static let english = StoreScreenshotFixture(
        language: "en",
        locale: "en_US",
        name: "Emily Parker",
        email: "emily.parker@example.com",
        completeName: "Project Manager – Ridgeline Freight",
        complete: CV(
            title: "Project Manager",
            location: "Denver, CO",
            email: "emily.parker@example.com",
            profile: "Project manager with eight years of experience in logistics and construction. I plan projects end to end, "
                + "keep teams and suppliers on one schedule, and deliver on time and on budget.",
            experience: [
                Entry(
                    title: "Project Manager", place: "Ridgeline Freight", location: "Denver, CO", period: "2019 – Present",
                    description: "Lead warehouse automation projects across three distribution centers.\n"
                        + "• Manage a team of 6 coordinators and analysts\n"
                        + "• Launched a new sorting line two weeks ahead of schedule\n"
                        + "• Cut picking errors by 30% with a barcode scanning process"
                ),
                Entry(
                    title: "Project Coordinator", place: "Hartwell Builders", location: "Boulder, CO", period: "2015 – 2019",
                    description: "Coordinated schedules, budgets and subcontractors for commercial buildings.\n"
                        + "• Kept 12 projects within budget\n"
                        + "• Introduced a shared planning board for site teams"
                ),
            ],
            education: [
                Entry(title: "B.S. in Business Administration", place: "Larkspur State University", period: "2011 – 2015"),
            ],
            skills: [
                ("Project planning", 5), ("Stakeholder management", 5), ("Budgeting", 4),
                ("Risk management", 4), ("Agile methods", 4), ("Process improvement", 4),
            ],
            languages: [("English", "Native"), ("Spanish", "B1")],
            interests: ["Hiking", "Photography", "Community volunteering"]
        ),
        adaptations: [
            ("Operations Manager", "Operations Manager"),
            ("Program Manager – Healthcare", "Program Manager"),
            ("Construction Project Manager", "Construction Project Manager"),
        ],
        description: "I'm Emily Parker, a project manager from Denver. Since 2019 I have led warehouse automation projects "
            + "at Ridgeline Freight, where I manage a team of 6. Before that, from 2015 to 2019, I was a project coordinator "
            + "at Hartwell Builders. I graduated in Business Administration in 2015. I speak English (native) and Spanish (B1). "
            + "In my free time I like hiking and photography.",
        draftName: "My CV",
        draft: CV(
            title: "Project Manager",
            location: "Denver",
            experience: [
                Entry(title: "Project Manager", place: "Ridgeline Freight", period: "2019 – Present",
                      description: "Led warehouse automation projects and managed a team of 6."),
                Entry(title: "Project Coordinator", place: "Hartwell Builders", period: "2015 – 2019"),
            ],
            education: [Entry(title: "Business Administration", place: "", period: "2015")],
            languages: [("English", "Native"), ("Spanish", "B1")],
            interests: ["Hiking", "Photography"]
        )
    )
}

// MARK: - German

extension StoreScreenshotFixture {
    static let german = StoreScreenshotFixture(
        language: "de",
        locale: "de_DE",
        name: "Lena Hoffmann",
        email: "lena.hoffmann@example.com",
        completeName: "Intensivpflege – Klinikum Elbufer",
        complete: CV(
            title: "Pflegefachfrau",
            location: "Hamburg",
            email: "lena.hoffmann@example.com",
            profile: "Pflegefachfrau mit zehn Jahren Berufserfahrung in der Inneren Medizin und der Intensivpflege. Ich arbeite "
                + "ruhig und sorgfältig, auch wenn es auf der Station hektisch wird, und leite neue Kolleginnen und Kollegen gern an.",
            experience: [
                Entry(
                    title: "Pflegefachfrau, Intensivstation", place: "Klinikum Elbufer", location: "Hamburg", period: "2018 – Heute",
                    description: "Pflege beatmeter und frisch operierter Patientinnen und Patienten.\n"
                        + "• Praxisanleiterin für 5 Auszubildende\n"
                        + "• Neue Checkliste für die Schichtübergabe eingeführt\n"
                        + "• Mitglied im Hygieneteam der Station"
                ),
                Entry(
                    title: "Pflegefachfrau, Innere Medizin", place: "Klinik am Kalkberg", location: "Lüneburg", period: "2014 – 2018",
                    description: "Pflege auf einer internistischen Station mit 32 Betten.\n"
                        + "• Verantwortlich für Wundmanagement und Pflegedokumentation"
                ),
            ],
            education: [
                Entry(title: "Ausbildung zur Gesundheits- und Krankenpflegerin", place: "Berufsfachschule für Pflege Lüneburg",
                      period: "2011 – 2014"),
            ],
            skills: [
                ("Intensivpflege", 5), ("Praxisanleitung", 5), ("Beatmungspflege", 4),
                ("Wundmanagement", 4), ("Pflegedokumentation", 4), ("Notfallmanagement", 4),
            ],
            languages: [("Deutsch", "Native"), ("Englisch", "B2")],
            interests: ["Rudern", "Kochen", "Radfahren"]
        ),
        adaptations: [
            ("Stationsleitung Innere Medizin", "Stationsleitung"),
            ("Praxisanleitung", "Praxisanleiterin"),
            ("Bewerbung Rehaklinik", "Pflegefachfrau"),
        ],
        description: "Ich bin Lena Hoffmann, Pflegefachfrau aus Hamburg. Seit 2018 arbeite ich auf der Intensivstation im "
            + "Klinikum Elbufer, wo ich 5 Auszubildende anleite. Davor war ich von 2014 bis 2018 auf einer Station für Innere "
            + "Medizin in Lüneburg. Ich spreche Deutsch (Muttersprache) und Englisch (B2).",
        draftName: "Mein Lebenslauf",
        draft: CV(
            title: "Pflegefachfrau",
            location: "Hamburg",
            experience: [
                Entry(title: "Pflegefachfrau, Intensivstation", place: "Klinikum Elbufer", period: "2018 – Heute",
                      description: "Anleitung von 5 Auszubildenden."),
                Entry(title: "Pflegefachfrau, Innere Medizin", place: "", location: "Lüneburg", period: "2014 – 2018"),
            ],
            education: [],
            languages: [("Deutsch", "Native"), ("Englisch", "B2")],
            interests: []
        )
    )
}

// MARK: - Italian

extension StoreScreenshotFixture {
    static let italian = StoreScreenshotFixture(
        language: "it",
        locale: "it_IT",
        name: "Giulia Conti",
        email: "giulia.conti@example.com",
        completeName: "Farmacista – Farmacia Aurora Nuova",
        complete: CV(
            title: "Farmacista",
            location: "Torino",
            email: "giulia.conti@example.com",
            profile: "Farmacista con nove anni di esperienza in farmacia. Consiglio i pazienti con chiarezza, seguo ordini e "
                + "magazzino e coordino un piccolo gruppo di lavoro.",
            experience: [
                Entry(
                    title: "Farmacista responsabile", place: "Farmacia Aurora Nuova", location: "Torino", period: "2019 – Presente",
                    description: "Gestione di ordini, magazzino e turni per un gruppo di 4 collaboratori.\n"
                        + "• Avvio della prenotazione di esami e della misurazione della pressione\n"
                        + "• Tutor di 3 tirocinanti\n"
                        + "• Farmaci scaduti in magazzino ridotti del 20%"
                ),
                Entry(
                    title: "Farmacista", place: "Parafarmacia Il Melograno", location: "Moncalieri", period: "2016 – 2019",
                    description: "Consulenza su farmaci da banco, dermocosmesi e integratori."
                ),
            ],
            education: [
                Entry(title: "Laurea magistrale in Farmacia", place: "Università del Monviso", period: "2011 – 2016"),
            ],
            skills: [
                ("Consulenza al paziente", 5), ("Gestione del magazzino", 4), ("Farmacovigilanza", 4),
                ("Dermocosmesi", 4), ("Coordinamento del personale", 4), ("Preparazioni galeniche", 3),
            ],
            languages: [("Italiano", "Native"), ("Inglese", "B2"), ("Francese", "A2")],
            interests: ["Montagna", "Fotografia", "Cucina"]
        ),
        adaptations: [
            ("Direttrice di farmacia", "Direttrice di farmacia"),
            ("Informatrice scientifica", "Informatrice scientifica del farmaco"),
            ("Farmacista ospedaliera", "Farmacista ospedaliera"),
        ],
        description: "Sono Giulia Conti, farmacista a Torino. Dal 2019 lavoro alla Farmacia Aurora Nuova, dove coordino 4 "
            + "collaboratori. Prima, dal 2016 al 2019, sono stata farmacista in una parafarmacia a Moncalieri. Mi sono laureata "
            + "in Farmacia nel 2016. Parlo italiano (madrelingua) e inglese (B2). Nel tempo libero mi piacciono la montagna e la "
            + "fotografia.",
        draftName: "Il mio CV",
        draft: CV(
            title: "Farmacista",
            location: "Torino",
            experience: [
                Entry(title: "Farmacista", place: "Farmacia Aurora Nuova", period: "2019 – Presente",
                      description: "Coordinamento di 4 collaboratori."),
                Entry(title: "Farmacista", place: "", location: "Moncalieri", period: "2016 – 2019"),
            ],
            education: [Entry(title: "Laurea in Farmacia", place: "", period: "2016")],
            languages: [("Italiano", "Native"), ("Inglese", "B2")],
            interests: ["Montagna", "Fotografia"]
        )
    )
}

// MARK: - Spanish

extension StoreScreenshotFixture {
    static let spanish = StoreScreenshotFixture(
        language: "es",
        locale: "es_ES",
        name: "Lucía Martínez",
        email: "lucia.martinez@example.com",
        completeName: "Diseño gráfico – Estudio Alfarero",
        complete: CV(
            title: "Diseñadora gráfica",
            location: "Guadalajara",
            email: "lucia.martinez@example.com",
            profile: "Diseñadora gráfica con siete años de experiencia en identidad de marca y diseño editorial. Convierto ideas "
                + "complejas en piezas claras y cuido cada detalle, del primer boceto a la imprenta.",
            experience: [
                Entry(
                    title: "Diseñadora gráfica sénior", place: "Estudio Alfarero", location: "Guadalajara", period: "2020 – Actualidad",
                    description: "Identidad visual y piezas editoriales para clientes del sector cultural.\n"
                        + "• Coordino a 2 diseñadores júnior\n"
                        + "• Nueva imagen para un festival con 40.000 visitantes\n"
                        + "• Plantillas que redujeron a la mitad el tiempo de maquetación"
                ),
                Entry(
                    title: "Diseñadora gráfica", place: "Imprenta Los Arcos", location: "Guadalajara", period: "2017 – 2020",
                    description: "Maquetación de catálogos y carteles, y preparación de archivos para imprenta."
                ),
            ],
            education: [
                Entry(title: "Grado en Diseño", place: "Escuela de Arte y Diseño Puerta Nueva", period: "2013 – 2017"),
            ],
            skills: [
                ("Identidad de marca", 5), ("Diseño editorial", 5), ("Maquetación", 5),
                ("Tipografía", 4), ("Ilustración", 4), ("Preimpresión", 4),
            ],
            languages: [("Español", "Native"), ("Inglés", "C1"), ("Francés", "A2")],
            interests: ["Cerámica", "Cine", "Senderismo"]
        ),
        adaptations: [
            ("Directora de arte", "Directora de arte"),
            ("Diseño editorial", "Diseñadora editorial"),
            ("Identidad de marca", "Diseñadora de marca"),
        ],
        description: "Soy Lucía Martínez, diseñadora gráfica en Guadalajara. Desde 2020 trabajo en el Estudio Alfarero, donde "
            + "coordino a 2 diseñadores júnior. Antes, de 2017 a 2020, fui diseñadora en una imprenta. Estudié Diseño y me "
            + "gradué en 2017. Hablo español (nativo) e inglés (C1). En mi tiempo libre me gustan la cerámica y el cine.",
        draftName: "Mi CV",
        draft: CV(
            title: "Diseñadora gráfica",
            location: "Guadalajara",
            experience: [
                Entry(title: "Diseñadora gráfica", place: "Estudio Alfarero", period: "2020 – Actualidad",
                      description: "Coordinación de 2 diseñadores júnior."),
                Entry(title: "Diseñadora", place: "", period: "2017 – 2020"),
            ],
            education: [Entry(title: "Diseño", place: "", period: "2017")],
            languages: [("Español", "Native"), ("Inglés", "C1")],
            interests: ["Cerámica", "Cine"]
        )
    )
}

// MARK: - French

extension StoreScreenshotFixture {
    static let french = StoreScreenshotFixture(
        language: "fr",
        locale: "fr_FR",
        name: "Camille Laurent",
        email: "camille.laurent@example.com",
        completeName: "Développeuse web – Atelier Numérique",
        complete: CV(
            title: "Développeuse web",
            location: "Nantes",
            email: "camille.laurent@example.com",
            profile: "Développeuse web avec six ans d'expérience sur des applications métier. J'aime écrire un code clair et "
                + "testé, et travailler au plus près des personnes qui utilisent mes outils.",
            experience: [
                Entry(
                    title: "Développeuse web full stack", place: "Atelier Numérique de l'Erdre", location: "Nantes",
                    period: "2021 – Aujourd'hui",
                    description: "Applications de gestion pour des collectivités locales.\n"
                        + "• Accompagnement de 2 développeurs juniors\n"
                        + "• Mise en place des tests automatisés sur 4 projets\n"
                        + "• Audit et mise en conformité de l'accessibilité"
                ),
                Entry(
                    title: "Développeuse web", place: "Agence Bocage Digital", location: "Angers", period: "2018 – 2021",
                    description: "Sites et applications web pour des PME de la région."
                ),
            ],
            education: [
                Entry(title: "Master Informatique", place: "Université du Val d'Erdre", period: "2016 – 2018"),
            ],
            skills: [
                ("Développement front-end", 5), ("Tests automatisés", 5), ("API REST", 4),
                ("Bases de données SQL", 4), ("Accessibilité numérique", 4), ("Méthodes agiles", 4),
            ],
            languages: [("Français", "Native"), ("Anglais", "C1"), ("Espagnol", "B1")],
            interests: ["Escalade", "Musique", "Jeux de société"]
        ),
        adaptations: [
            ("Lead développeuse front-end", "Lead développeuse front-end"),
            ("Développeuse mobile", "Développeuse mobile"),
            ("Consultante technique", "Consultante technique"),
        ],
        description: "Je suis Camille Laurent, développeuse web à Nantes. Depuis 2021, je développe des applications de gestion "
            + "à l'Atelier Numérique de l'Erdre, où j'accompagne 2 développeurs juniors. Avant, de 2018 à 2021, j'étais "
            + "développeuse dans une agence web à Angers. J'ai obtenu un master en informatique en 2018. Je parle français "
            + "(langue maternelle) et anglais (C1).",
        draftName: "Mon CV",
        draft: CV(
            title: "Développeuse web",
            location: "Nantes",
            experience: [
                Entry(title: "Développeuse web", place: "Atelier Numérique de l'Erdre", period: "2021 – Aujourd'hui",
                      description: "Développement d'applications de gestion, accompagnement de 2 développeurs juniors."),
                Entry(title: "Développeuse", place: "", location: "Angers", period: "2018 – 2021"),
            ],
            education: [Entry(title: "Master en informatique", place: "", period: "2018")],
            languages: [("Français", "Native"), ("Anglais", "C1")],
            interests: []
        )
    )
}

// MARK: - Portuguese

extension StoreScreenshotFixture {
    static let portuguese = StoreScreenshotFixture(
        language: "pt",
        locale: "pt_BR",
        name: "Ana Ferreira",
        email: "ana.ferreira@example.com",
        completeName: "Engenheira de obras – Vale Verde",
        complete: CV(
            title: "Engenheira civil",
            location: "Curitiba",
            email: "ana.ferreira@example.com",
            profile: "Engenheira civil com oito anos de experiência em obras residenciais e comerciais. Planejo e acompanho "
                + "obras do início ao fim, com foco em prazo, orçamento e segurança.",
            experience: [
                Entry(
                    title: "Engenheira de obras", place: "Construtora Vale Verde", location: "Curitiba", period: "2019 – Atual",
                    description: "Gestão de obras residenciais de até 12 pavimentos.\n"
                        + "• Coordeno equipes de até 40 pessoas\n"
                        + "• Redução de 15% no desperdício de materiais\n"
                        + "• Nenhum acidente com afastamento em 3 anos"
                ),
                Entry(
                    title: "Engenheira civil júnior", place: "Araucária Projetos", location: "Curitiba", period: "2016 – 2019",
                    description: "Orçamentos, cronogramas e acompanhamento de obras comerciais."
                ),
            ],
            education: [
                Entry(title: "Engenharia Civil", place: "Escola de Engenharia Serra do Mar", period: "2011 – 2016"),
            ],
            skills: [
                ("Gestão de obras", 5), ("Planejamento", 5), ("Leitura de projetos", 5),
                ("Orçamento", 4), ("Segurança do trabalho", 4), ("Liderança de equipes", 4),
            ],
            languages: [("Português", "Native"), ("Inglês", "B2"), ("Espanhol", "B1")],
            interests: ["Ciclismo", "Fotografia", "Voluntariado"]
        ),
        adaptations: [
            ("Gerente de projetos", "Gerente de projetos"),
            ("Engenheira de planejamento", "Engenheira de planejamento"),
            ("Coordenadora de obras", "Coordenadora de obras"),
        ],
        description: "Sou Ana Ferreira, engenheira civil em Curitiba. Desde 2019 trabalho como engenheira de obras na "
            + "Construtora Vale Verde, onde coordeno equipes de até 40 pessoas. Antes, de 2016 a 2019, fui engenheira júnior "
            + "em um escritório de projetos. Me formei em Engenharia Civil em 2016. Falo português (nativo) e inglês (B2). "
            + "No meu tempo livre, gosto de ciclismo e fotografia.",
        draftName: "Meu currículo",
        draft: CV(
            title: "Engenheira civil",
            location: "Curitiba",
            experience: [
                Entry(title: "Engenheira de obras", place: "Construtora Vale Verde", period: "2019 – Atual",
                      description: "Coordenação de equipes de até 40 pessoas."),
                Entry(title: "Engenheira júnior", place: "", period: "2016 – 2019"),
            ],
            education: [Entry(title: "Engenharia Civil", place: "", period: "2016")],
            languages: [("Português", "Native"), ("Inglês", "B2")],
            interests: ["Ciclismo", "Fotografia"]
        )
    )
}

import Testing
@testable import PrestoCVImporting

/// Whether a text given to the AI draft is already a CV, which the import then reads as written (ADR 0034). The rule
/// reads only the imported CV, a value: the texts are imported with the standard limits, and the boundaries are built
/// as values. Every text is invented.
@Suite("Telling a text that is already a CV")
struct CVRecognitionTests {

    struct Example: Sendable, CustomTestStringConvertible {
        let name: String
        let text: String
        let isACV: Bool
        var testDescription: String { name }
    }

    private func imported(_ text: String) throws -> ImportedCV {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text).cv
    }

    private func counts(_ cv: ImportedCV) -> String {
        "\(CVRecognition.sections(of: cv)) sections, \(CVRecognition.datedEntries(of: cv)) dated entries"
    }

    // MARK: Texts

    @Test("A CV is recognised and a free description is not, whatever its language", arguments: Self.examples)
    func readsTheText(example: Example) throws {
        let cv = try imported(example.text)
        let recognised = CVRecognition.isAlreadyACV(cv)
        #expect(recognised == example.isACV, "\(example.name): \(counts(cv))")
    }

    @Test("The headings of a CV are recognised in each language, in Markdown and in bold with a colon", arguments: Self.headingVariants)
    func readsTheHeadings(example: Example) throws {
        let cv = try imported(example.text)
        let recognised = CVRecognition.isAlreadyACV(cv)
        #expect(recognised, "\(example.name): \(counts(cv))")
    }

    @Test("A CV with headings and no date at all is not recognised: it goes to the AI draft, as before")
    func headedCVWithoutDates() throws {
        let cv = try imported("""
            Experience
            Line Cook, The Copper Pot, Leeds
            Prepared mise en place for the evening service

            Skills
            Knife skills, Food safety, Stock control

            Languages
            English – Native
            """)
        let sections = CVRecognition.sections(of: cv)
        let recognised = CVRecognition.isAlreadyACV(cv)
        #expect(sections >= CVRecognition.minimumSections, "the CV has its sections: \(counts(cv))")
        #expect(!recognised, "a CV without dates is a known miss: \(counts(cv))")
    }

    @Test("An empty text, blanks only or the longest text the import takes is no CV, and is read in time that grows with it")
    func emptyAndLongTexts() {
        let reading = ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard)
        func recognised(_ text: String) -> Bool {
            guard let result = try? reading.importText(text) else { return false }
            return CVRecognition.isAlreadyACV(result.cv)
        }
        #expect(!recognised(""))
        #expect(!recognised(" \n\t \r\n "))

        let sentence = "I have worked in a shop in York since 2019 and I speak French. "
        let sentences = ImportLimits.standard.maximumCharacters / sentence.unicodeScalars.count
        #expect(!recognised(String(repeating: sentence, count: sentences + 1)), "a text over the limit is refused, so no CV")
        expectLinear("free sentences", whole: sentences, cost: { size in
            let text = String(repeating: sentence, count: size)
            var found = true
            let seconds = cpuSeconds { found = recognised(text) }
            #expect(!found, "\(size) free sentences are no CV")
            return seconds
        })
    }

    // MARK: The thresholds

    struct Boundary: Sendable, CustomTestStringConvertible {
        let name: String
        let cv: ImportedCV
        let isACV: Bool
        var testDescription: String { name }
    }

    @Test("A CV needs two sections and one dated entry: one of the two is not enough", arguments: Self.boundaries)
    func needsBothConditions(row: Boundary) {
        #expect(CVRecognition.minimumSections == 2)
        #expect(CVRecognition.minimumDatedEntries == 1)
        let recognised = CVRecognition.isAlreadyACV(row.cv)
        #expect(recognised == row.isACV, "\(row.name): \(counts(row.cv))")
    }
}

// MARK: - Invented texts

extension CVRecognitionTests {

    static let examples: [Example] = [
        Example(name: "cv-en", text: """
            Marcus Hale
            Line Cook
            marcus.hale@example.com | +44 7700 900123
            Leeds, UK

            Summary
            Reliable cook with eight years in busy kitchens.

            Experience
            Line Cook, The Copper Pot, Leeds
            03/2019 – Present
            • Prepared mise en place for 120 covers a night
            • Trained two new commis chefs

            Commis Chef, Harbour Inn, Hull
            2016 – 2019
            • Made sauces and soups
            • Kept the cold room stocked

            Education
            Level 2 Diploma in Professional Cookery, Leeds College, 2016

            Skills
            Knife skills, Food safety, Stock control

            Languages
            English – Native
            Polish – B2
            """, isACV: true),
        Example(name: "cv-it", text: """
            Giulia Ferri
            Educatrice d'infanzia
            giulia.ferri@example.com
            Bologna

            Esperienza lavorativa
            Educatrice, Asilo Il Girasole, Bologna
            da marzo 2019 a oggi
            - Cura quotidiana dei bambini da 1 a 3 anni
            - Colloqui con le famiglie

            Tirocinante, Scuola Rodari, Modena
            2018
            - Affiancamento della maestra di sezione

            Istruzione
            Laurea in Scienze dell'educazione, Università di Bologna, 2018

            Competenze
            Gestione del gruppo, Giochi motori, Primo soccorso

            Lingue
            Italiano: madrelingua
            Inglese: B1
            """, isACV: true),
        Example(name: "cv-de", text: """
            Jonas Weber
            Elektriker
            jonas.weber@example.com
            Erfurt

            Berufserfahrung
            Elektriker, Elektro Brandt GmbH, Erfurt
            03/2019 – heute
            • Installation von Zählerschränken
            • Prüfung von Anlagen nach VDE

            Elektrikerhelfer, Haustechnik Roth, Gotha
            2016 – 2019
            • Kabelverlegung auf Baustellen

            Ausbildung
            Ausbildung zum Elektroniker, Berufsschule Erfurt, 2016

            Kenntnisse
            Schaltplanlesen, Messtechnik, Führerschein B

            Sprachen
            Deutsch – Muttersprache
            Englisch – B1
            """, isACV: true),
        Example(name: "cv-en-light, the shortest that passes", text: """
            Experience
            Sales Assistant, Corner Books, York
            2021 – 2024
            Stocked shelves and served customers

            Languages
            English – Native
            French – B1
            """, isACV: true),
        Example(name: "free-en", text: """
            I am a line cook with eight years of experience. I have worked at a restaurant in Leeds since 2019 and before \
            that I was a commis chef at an inn in Hull. I speak English and a bit of Polish. I want a CV to apply for a sous \
            chef job.
            """, isACV: false),
        Example(name: "free-it", text: """
            Mi chiamo Giulia e faccio l'educatrice in un asilo nido a Bologna dal 2019. Prima ho fatto un tirocinio in una \
            scuola a Modena nel 2018. Parlo italiano e un po' di inglese. Mi piace leggere e andare in bicicletta.
            """, isACV: false),
        Example(name: "free-de", text: """
            Ich bin Elektriker und arbeite seit 2019 bei einer Firma in Erfurt. Davor war ich drei Jahre Helfer bei einem \
            Betrieb in Gotha. Ich spreche Deutsch und etwas Englisch. Meine Hobbys sind Radfahren und Kochen.
            """, isACV: false),
        Example(name: "free-it with a heading word inside a sentence", text: """
            Esperienza: ho lavorato cinque anni come cameriere in una pizzeria di Torino, dal 2019 al 2024. Cerco un lavoro \
            in un hotel.
            """, isACV: false),
        Example(name: "free-en with a skills list and a request", text: """
            Skills:
            - Excel
            - Word
            - customer service
            I worked in a shop for 3 years. Please write a CV for a sales assistant.
            """, isACV: false),
    ]

    static let headingVariants: [Example] = [
        Example(name: "es", text: """
            Experiencia laboral
            Camarera, Café Central, Sevilla
            2020 – 2023
            Atención a los clientes en la terraza

            Idiomas
            Español – Nativo
            Inglés – B1
            """, isACV: true),
        Example(name: "fr", text: """
            Expérience professionnelle
            Vendeur, Librairie du Port, Nantes
            2019 – 2022
            Conseil aux clients et mise en rayon

            Langues
            Français – Langue maternelle
            Anglais – B2
            """, isACV: true),
        Example(name: "pt", text: """
            Experiência profissional
            Rececionista, Hotel Atlântico, Porto
            2018 – 2021
            Atendimento aos hóspedes

            Línguas
            Português – Nativo
            Inglês – B2
            """, isACV: true),
        Example(name: "de", text: """
            Beruflicher Werdegang
            Verkäuferin, Bäckerei Sonne, Jena
            2017 – 2020
            Beratung der Kundschaft

            Sprachkenntnisse
            Deutsch – Muttersprache
            Englisch – B1
            """, isACV: true),
        Example(name: "it", text: """
            Esperienze professionali
            Cameriere, Trattoria Da Nino, Parma
            2015 – 2019
            Servizio ai tavoli

            Lingue
            Italiano: madrelingua
            Inglese: A2
            """, isACV: true),
        Example(name: "en, work history and education", text: """
            Work history
            Warehouse Operative, North Freight, Bradford
            2020 – 2023
            Picked and packed orders

            Education
            BTEC Level 2 in Logistics, Bradford College, 2019
            """, isACV: true),
        Example(name: "en, capitals with a colon", text: """
            EXPERIENCE:
            Warehouse Operative, North Freight, Bradford
            2020 – 2023
            Picked and packed orders

            SKILLS:
            Forklift, Stock counts, Packing
            """, isACV: true),
        Example(name: "Markdown headings", text: """
            ## Experience
            **Barista**, Bean There, Bristol
            2021 – 2024
            - Made coffee for the morning rush

            ## Skills
            - Latte art
            - Cash handling
            """, isACV: true),
        Example(name: "bold headings with a colon", text: """
            **Experience:**
            Barista, Bean There, Bristol
            2021 – 2024
            - Made coffee for the morning rush

            **Languages:**
            English – Native
            Spanish – A2
            """, isACV: true),
        Example(name: "es, education and skills", text: """
            Formación académica
            Grado en Turismo, Universidad de Málaga, 2016 – 2020

            Habilidades
            Atención al cliente, Reservas, Inglés
            """, isACV: true),
        Example(name: "fr, Markdown with an interest list", text: """
            # Expérience
            Serveur, Le Petit Zinc, Lyon
            2018 – 2022
            - Service en salle

            # Centres d'intérêt
            - Randonnée
            - Cuisine
            """, isACV: true),
    ]
}

// MARK: - Boundaries, as values

extension CVRecognitionTests {

    private static func quoted(_ text: String) -> Sourced<String> { Sourced(value: text, spans: []) }

    private static let period = Sourced(value: ImportedPeriod(start: YearMonth(year: 2019, month: 3), end: .current), spans: [])

    private static func cv(_ fill: (inout ImportedCV) -> Void) -> ImportedCV {
        var cv = ImportedCV()
        fill(&cv)
        return cv
    }

    static let boundaries: [Boundary] = [
        Boundary(name: "nothing", cv: ImportedCV(), isACV: false),
        Boundary(name: "1 section, 1 dated entry", cv: cv {
            $0.experience = [ImportedExperience(role: quoted("Cook"), period: period)]
        }, isACV: false),
        Boundary(name: "2 sections, 0 dated entries", cv: cv {
            $0.experience = [ImportedExperience(role: quoted("Cook"))]
            $0.skills = [quoted("Knife skills")]
        }, isACV: false),
        Boundary(name: "2 sections, 1 dated entry", cv: cv {
            $0.experience = [ImportedExperience(role: quoted("Cook"), period: period)]
            $0.skills = [quoted("Knife skills")]
        }, isACV: true),
        Boundary(name: "a dated study and a summary under a heading", cv: cv {
            $0.person.summary = quoted("Reliable cook.")
            $0.education = [ImportedEducation(degree: quoted("Diploma"), period: period)]
        }, isACV: true),
        Boundary(name: "a summary without a heading is no section", cv: cv {
            $0.person.summary = Sourced(value: "Reliable cook.", spans: [], check: .summaryWithoutHeading)
            $0.experience = [ImportedExperience(role: quoted("Cook"), period: period)]
        }, isACV: false),
        Boundary(name: "the name, the title and the contacts are no section", cv: cv {
            $0.person.name = quoted("Marcus Hale")
            $0.person.title = quoted("Line Cook")
            $0.person.location = quoted("Leeds")
            $0.experience = [ImportedExperience(role: quoted("Cook"), period: period)]
        }, isACV: false),
        Boundary(name: "languages, certifications and interests are sections", cv: cv {
            $0.languages = [ImportedLanguage(name: quoted("English"))]
            $0.certifications = [ImportedCertification(name: quoted("Food hygiene"), issuer: nil, year: nil)]
            $0.interests = [quoted("Cycling")]
            $0.education = [ImportedEducation(degree: quoted("Diploma"), period: period)]
        }, isACV: true),
    ]
}

import Testing
@testable import PrestoCVImporting

@Suite("Reading the entries of experience and education")
struct EntryReaderTests {

    private func read(_ text: String, kind: EntryReader.Kind = .experience) -> Findings {
        let (document, sections) = pasted(text)
        var findings = Findings(document: document)
        for section in sections where section.kind == .experience || section.kind == .education {
            do {
                try EntryReader.read(section, kind: kind, into: &findings)
            } catch {
                Issue.record("The entries were not read: \(error)")
            }
        }
        return findings
    }

    private func ym(_ year: Int, _ month: Int? = nil) -> YearMonth { YearMonth(year: year, month: month) }

    @Test("A chat answer: a heading of role and employer, the dates in italics, bullets")
    func chatAnswer() throws {
        let found = read("""
        ## Esperienza professionale
        ### Infermiera — Ospedale Esempio, Torino
        *Marzo 2019 – oggi*
        - Assistenza ai pazienti in terapia intensiva
        - Formazione di 6 nuovi colleghi
        ### Infermiera — Clinica Esempio, Milano
        *Settembre 2016 – Febbraio 2019*
        - Reparto di cardiologia
        """)
        try #require(found.cv.experience.count == 2)
        let first = found.cv.experience[0]
        #expect(first.role?.value == "Infermiera")
        #expect(first.employer?.value == "Ospedale Esempio")
        #expect(first.location?.value == "Torino")
        #expect(first.period?.value == ImportedPeriod(start: ym(2019, 3), end: .current))
        #expect(first.details.map(\.value) == ["Assistenza ai pazienti in terapia intensiva", "Formazione di 6 nuovi colleghi"])
        #expect(first.check == nil)
        #expect(found.cv.experience[1].employer?.value == "Clinica Esempio")
        #expect(found.cv.experience[1].details.map(\.value) == ["Reparto di cardiologia"])
    }

    @Test("One line per entry: role, employer, place and dates between bars")
    func oneLineEntries() throws {
        let found = read("""
        ## Work Experience
        **Senior iOS Developer** | Acme Ltd | London | Jan 2020 – Present
        - Led the move to SwiftUI
        **iOS Developer** | Example Labs | Manchester | Jun 2016 – Dec 2019
        - Built the offline mode
        """)
        try #require(found.cv.experience.count == 2)
        #expect(found.cv.experience.map { $0.role?.value } == ["Senior iOS Developer", "iOS Developer"])
        #expect(found.cv.experience.map { $0.employer?.value } == ["Acme Ltd", "Example Labs"])
        #expect(found.cv.experience.map { $0.location?.value } == ["London", "Manchester"])
        #expect(found.cv.experience[1].period?.value == ImportedPeriod(start: ym(2016, 6), end: .date(ym(2019, 12))))
    }

    @Test("The tabular Lebenslauf: the dates in the left column, role, employer and bullets on the right")
    func lebenslauf() throws {
        let found = read("""
        Berufserfahrung
        03/2019 – heute\tProjektleiterin Elektrotechnik
        \tBeispiel GmbH, Leipzig
        \t• Planung von Elektroinstallationen
        09/2015 – 02/2019\tElektrikerin
        \tMuster Elektro AG, Dresden
        """)
        try #require(found.cv.experience.count == 2)
        let first = found.cv.experience[0]
        #expect(first.role?.value == "Projektleiterin Elektrotechnik")
        #expect(first.employer?.value == "Beispiel GmbH")
        #expect(first.location?.value == "Leipzig")
        #expect(first.period?.value == ImportedPeriod(start: ym(2019, 3), end: .current))
        #expect(first.details.map(\.value) == ["Planung von Elektroinstallationen"])
        #expect(found.cv.experience[1].employer?.value == "Muster Elektro AG")
    }

    @Test("LinkedIn's order: the company, the role, the dates with a computed duration, the place; roles grouped under a company")
    func linkedIn() throws {
        let found = read("""
        Experience
        Acme S.p.A.
        Senior iOS Developer
        March 2019 - Present (5 years 8 months)
        Milan, Lombardy, Italy
        Built the banking app used by two million customers every month.
        Beispiel GmbH
        2 years 3 months
        Team Lead
        January 2017 - February 2019 (2 years 2 months)
        Developer
        March 2016 - December 2016 (10 months)
        """)
        try #require(found.cv.experience.count == 3)
        #expect(found.cv.experience.map { $0.employer?.value } == ["Acme S.p.A.", "Beispiel GmbH", "Beispiel GmbH"])
        #expect(found.cv.experience.map { $0.role?.value } == ["Senior iOS Developer", "Team Lead", "Developer"])
        #expect(found.cv.experience[0].location?.value == "Milan, Lombardy, Italy")
        #expect(found.cv.experience[0].details.count == 1)
        #expect(found.leftOut.filter { $0.reason == .computedDuration }.map(\.text) == [
            "2 years 3 months", "(5 years 8 months)", "(2 years 2 months)", "(10 months)",
        ])
    }

    @Test("A company's group of roles ends where the next company starts")
    func linkedInGroupEnds() throws {
        let found = read("""
        Experience
        Beispiel GmbH
        3 years
        Team Lead
        2019 - Present (2 years)
        Developer
        2018 - 2019 (1 year)
        Acme Ltd
        Intern
        2017 - 2018 (1 year)
        """)
        #expect(found.cv.experience.map { $0.employer?.value } == ["Beispiel GmbH", "Beispiel GmbH", "Acme Ltd"])
        #expect(found.cv.experience.map { $0.role?.value } == ["Team Lead", "Developer", "Intern"])
    }

    @Test("Word text: role and employer on their lines, the dates after them")
    func wordText() throws {
        let found = read("""
        Esperienza professionale
        Infermiera
        Ospedale Esempio, Torino
        Marzo 2019 – oggi
        Assistenza ai pazienti in terapia intensiva e coordinamento dei turni del reparto.

        Infermiera
        Clinica Esempio, Milano
        Settembre 2016 – Febbraio 2019
        """)
        try #require(found.cv.experience.count == 2)
        #expect(found.cv.experience.map { $0.role?.value } == ["Infermiera", "Infermiera"])
        #expect(found.cv.experience.map { $0.employer?.value } == ["Ospedale Esempio", "Clinica Esempio"])
        #expect(found.cv.experience[0].details.count == 1)
    }

    @Test("Education in one line each, the dates first")
    func educationLines() throws {
        let found = read("""
        Istruzione
        2016 – 2019: Laurea in Infermieristica, Università degli Studi di Torino
        2011 – 2016: Diploma di liceo scientifico, Liceo Esempio, Torino
        """, kind: .education)
        try #require(found.cv.education.count == 2)
        #expect(found.cv.education[0].degree?.value == "Laurea in Infermieristica")
        #expect(found.cv.education[0].school?.value == "Università degli Studi di Torino")
        #expect(found.cv.education[1].school?.value == "Liceo Esempio")
        #expect(found.cv.education[1].location?.value == "Torino")
    }

    @Test("The rows of the formato europeo, by their labels")
    func formatoEuropeo() throws {
        let found = read("""
        ESPERIENZA LAVORATIVA
        Date (da – a)\tMarzo 2019 – ATTUALE
        Nome e indirizzo del datore di lavoro\tOspedale Esempio, Via Roma 1, Torino
        Tipo di azienda o settore\tSanità
        Tipo di impiego\tInfermiera
        Principali mansioni e responsabilità\tAssistenza ai pazienti in terapia intensiva
        Date (da – a)\tSettembre 2016 – Febbraio 2019
        Nome e indirizzo del datore di lavoro\tClinica Esempio, Milano
        Tipo di impiego\tInfermiera
        """)
        try #require(found.cv.experience.count == 2)
        let first = found.cv.experience[0]
        #expect(first.role?.value == "Infermiera")
        #expect(first.employer?.value == "Ospedale Esempio")
        #expect(first.location?.value == "Via Roma 1, Torino")
        #expect(first.period?.value == ImportedPeriod(start: ym(2019, 3), end: .current))
        #expect(first.details.map(\.value) == ["Sanità", "Assistenza ai pazienti in terapia intensiva"])
        #expect(found.cv.experience[1].location?.value == "Milano")
    }

    @Test("A connector tells the role from the employer, in each language")
    func connectors() throws {
        let found = read("""
        Experience
        Pflegefachkraft bei Klinikum Beispiel
        2018 – 2020
        Camarera en Restaurante Ejemplo
        2016 – 2018
        """)
        #expect(found.cv.experience.map { $0.role?.value } == ["Pflegefachkraft", "Camarera"])
        #expect(found.cv.experience.map { $0.employer?.value } == ["Klinikum Beispiel", "Restaurante Ejemplo"])
    }

    @Test("Parts no word marks follow the section's own order, and the entry is flagged")
    func orderFallback() throws {
        let found = read("""
        Experience
        Customer Service Manager | Acme Ltd | 2019 – 2021
        Night Shift | Corner Market Example | 2016 – 2018
        """)
        try #require(found.cv.experience.count == 2)
        #expect(found.cv.experience[0].check == nil)
        #expect(found.cv.experience[1].role?.value == "Night Shift")
        #expect(found.cv.experience[1].employer?.value == "Corner Market Example")
        #expect(found.cv.experience[1].check == .roleOrEmployerByOrder)
    }

    @Test("German compound roles are roles, so an entry with a marked employer is not flagged")
    func germanCompoundRoles() throws {
        let found = read("""
        Berufserfahrung
        Altenpfleger | Pflegeheim Sonnenhof Beispiel | Lübeck | 2014 – 2018
        Rettungssanitäterin | Rettungsdienst Beispiel e.V. | Kiel | 2010 – 2011
        Pflegehelfer | Pflegedienst Beispiel | Kiel | 2012 – 2014
        """)
        #expect(found.cv.experience.map { $0.role?.value } == ["Altenpfleger", "Rettungssanitäterin", "Pflegehelfer"])
        #expect(found.cv.experience.allSatisfy { $0.check == nil })
    }

    // MARK: Each date alone on the line above its entry (#295)

    private func summary(_ found: Findings) -> [String] {
        found.cv.experience.map { entry in
            [entry.role?.value, entry.employer?.value, entry.location?.value, entry.period.map { "\($0.value.start.year)" }]
                .map { $0 ?? "-" }.joined(separator: "|")
        }
    }

    @Test("Dates alone above their entries: the first line is a date, so every date opens its entry, with or without bullets")
    func datesAloneAboveEntries() throws {
        let plain = read("""
        Experience
        2020 – 2021
        Trainee at Northgate Hospital, Leeds
        Helped on the ward
        2019 – 2020
        Cleaner at Verdi Ltd, Leeds
        Cleaned offices
        2018 – 2019
        Shop assistant at Blue Shop, Rome
        Served customers
        """)
        let bulleted = read("""
        Experience
        2020 – 2021
        Trainee at Northgate Hospital, Leeds
        • Helped on the ward
        2019 – 2020
        Cleaner at Verdi Ltd, Leeds
        • Cleaned offices
        2018 – 2019
        Shop assistant at Blue Shop, Rome
        • Served customers
        """)
        for found in [plain, bulleted] {
            #expect(summary(found) == [
                "Trainee|Northgate Hospital|Leeds|2020", "Cleaner|Verdi Ltd|Leeds|2019", "Shop assistant|Blue Shop|Rome|2018",
            ])
            #expect(found.cv.experience.map { $0.details.map(\.value) } == [["Helped on the ward"], ["Cleaned offices"], ["Served customers"]])
            #expect(found.cv.experience.allSatisfy { $0.check == nil })
        }
    }

    @Test("Dates alone above their entries, in Italian and in German")
    func datesAloneAboveEntriesInOtherLanguages() throws {
        let italian = read("""
        Esperienza professionale
        2020 – 2021
        Tirocinante presso Ospedale Esempio, Torino
        Assistenza in reparto
        2019 – 2020
        Addetta alle pulizie presso Verdi Srl, Torino
        Pulizia degli uffici
        2018 – 2019
        Commessa presso Negozio Blu, Roma
        Servizio ai clienti
        """)
        #expect(summary(italian) == [
            "Tirocinante|Ospedale Esempio|Torino|2020", "Addetta alle pulizie|Verdi Srl|Torino|2019", "Commessa|Negozio Blu|Roma|2018",
        ])
        let german = read("""
        Berufserfahrung
        2020 – 2021
        Praktikantin bei Klinikum Beispiel, Leipzig
        Mithilfe auf der Station
        2019 – 2020
        Reinigungskraft bei Verdi GmbH, Leipzig
        Reinigung der Büros
        2018 – 2019
        Verkäuferin bei Blaues Geschäft, Dresden
        Beratung der Kunden
        """)
        #expect(summary(german) == [
            "Praktikantin|Klinikum Beispiel|Leipzig|2020", "Reinigungskraft|Verdi GmbH|Leipzig|2019", "Verkäuferin|Blaues Geschäft|Dresden|2018",
        ])
    }

    @Test("Education with each date alone above its entry")
    func educationDatesAloneAbove() throws {
        let found = read("""
        Education
        2016 – 2019
        BSc Nursing, University of Leeds
        Final year project on wound care
        2012 – 2016
        Diploma, Northgate School, Leeds
        Maths and science
        2010 – 2012
        Certificate, Verdi College, Leeds
        Evening classes
        """, kind: .education)
        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Nursing", "Diploma", "Certificate"])
        #expect(found.cv.education.map { $0.school?.value } == ["University of Leeds", "Northgate School", "Verdi College"])
        #expect(found.cv.education.map { $0.period?.value.start.year } == [2016, 2012, 2010])
        #expect(found.cv.education.map { $0.details.map(\.value) } == [["Final year project on wound care"], ["Maths and science"], ["Evening classes"]])
    }

    @Test("Two entries with their dates alone above: one more entry cannot tip the reading")
    func twoEntriesDatesAbove() throws {
        let found = read("""
        Experience
        2020 – 2021
        Trainee at Northgate Hospital, Leeds
        Helped on the ward
        2019 – 2020
        Cleaner at Verdi Ltd, Leeds
        Cleaned offices
        """)
        #expect(summary(found) == ["Trainee|Northgate Hospital|Leeds|2020", "Cleaner|Verdi Ltd|Leeds|2019"])
    }

    @Test("A date opening each line, with the entry after it on the same line and a short line below")
    func datesOpeningLinesWithShortDescriptions() throws {
        let education = read("""
        Educación
        09/2015 - 05/2019, Enfermería, Universidad de Ejemplo, Sevilla
        Primera clase con honores
        09/2011 - 05/2015, Bachillerato, Instituto Prueba, Sevilla
        Nota media de sobresaliente
        """, kind: .education)
        #expect(education.cv.education.map { $0.degree?.value } == ["Enfermería", "Bachillerato"])
        #expect(education.cv.education.map { $0.school?.value } == ["Universidad de Ejemplo", "Instituto Prueba"])
        #expect(education.cv.education.map { $0.details.map(\.value) } == [["Primera clase con honores"], ["Nota media de sobresaliente"]])
        let experience = read("""
        Berufserfahrung
        08/2022 – 07/2025 Pflegehelferin
        Klinikum Beispiel, Leipzig
        Abschluss: Praxisnote 2,1
        09/2018 – 06/2022 Verkäuferin
        Blaues Geschäft, Dresden
        Beratung der Kunden
        """)
        #expect(summary(experience) == ["Pflegehelferin|Klinikum Beispiel|Leipzig|2022", "Verkäuferin|Blaues Geschäft|Dresden|2018"])
    }

    @Test("A date at the end of the first line is its entry's own, so the head lines above later dates stay theirs")
    func dateEndingTheFirstLine() throws {
        let found = read("""
        Esperienze lavorative
        Cassiera presso Mercato Esempio, Padova
        dal 2018 ad oggi
        - Cassa e rifornimento scaffali

        Commessa presso Negozio Prova, Treviso
        2014 - 2018
        """)
        #expect(summary(found) == ["Cassiera|Mercato Esempio|Padova|2018", "Commessa|Negozio Prova|Treviso|2014"])
        #expect(found.cv.experience.map { $0.details.map(\.value) } == [["Cassa e rifornimento scaffali"], []])
    }

    @Test("A range that opens the section and holds every other is no entry: it stays visible, the later dates keep the head lines above them")
    func leadingRangeBelongsToNoEntry() throws {
        // The range is isolated by a gap or not, the entries have bullets or not
        let samples = [
            """
            Experience
            2010 – 2025

            Developer at Acme Ltd
            2020 – 2025

            Cleaner at Verdi Ltd
            2010 – 2020
            """,
            """
            Experience
            2010 – 2025
            Developer at Acme Ltd
            2020 – 2025
            Cleaner at Verdi Ltd
            2010 – 2020
            """,
            """
            Experience
            2010 – 2025

            Developer at Acme Ltd
            2020 – 2025
            • Built the tools

            Cleaner at Verdi Ltd
            2010 – 2020
            • Cleaned the offices
            """,
            """
            Experience
            2010 – 2025
            Developer at Acme Ltd
            2020 – 2025
            • Built the tools
            Cleaner at Verdi Ltd
            2010 – 2020
            • Cleaned the offices
            """,
        ]
        for text in samples {
            let found = read(text)
            #expect(summary(found) == ["Developer|Acme Ltd|-|2020", "Cleaner|Verdi Ltd|-|2010"])
            #expect(found.unplaced.map(\.text) == ["2010 – 2025"])
            #expect(found.cv.experience.allSatisfy { $0.check == nil })
        }
    }

    // MARK: Which lines belong to which date, read over the whole section (#295)

    /// The lines of each entry after its role and employer: a place or details.
    private func ownLines(_ found: Findings) -> [[String]] {
        found.cv.experience.map { [$0.location?.value].compactMap { $0 } + $0.details.map(\.value) }
    }

    @Test("Dates alone above their entries, with a blank line after any line: no gap tips the reading")
    func datesAboveWithAGapAnywhere() throws {
        let lines = [
            "Experience",
            "2020 – 2021", "Trainee at Northgate Hospital, Leeds", "Helped on the ward",
            "2019 – 2020", "Cleaner at Verdi Ltd, Leeds", "Cleaned offices",
            "2018 – 2019", "Shop assistant at Blue Shop, Rome", "Served customers",
        ]
        for gap in 1..<lines.count {
            var spaced = lines
            spaced.insert("", at: gap)
            let found = read(spaced.joined(separator: "\n"))
            #expect(summary(found) == [
                "Trainee|Northgate Hospital|Leeds|2020", "Cleaner|Verdi Ltd|Leeds|2019", "Shop assistant|Blue Shop|Rome|2018",
            ], "a gap before line \(gap)")
            #expect(found.cv.experience.map { $0.details.map(\.value) } == [["Helped on the ward"], ["Cleaned offices"], ["Served customers"]],
                    "a gap before line \(gap)")
            #expect(found.cv.experience.allSatisfy { $0.check == nil }, "a gap before line \(gap)")
        }
    }

    @Test("Dates after their heads, each with a short line under it that is its own")
    func datesAfterWithShortLines() throws {
        let found = read("""
        Experience
        Developer at Acme Ltd
        2020 – 2025
        Built the tools
        Cleaner at Verdi Ltd
        2015 – 2020
        Cleaned the offices
        Shop assistant at Blue Shop
        2010 – 2015
        Served customers
        """)
        #expect(found.cv.experience.map { "\($0.role?.value ?? "-")|\($0.employer?.value ?? "-")|\($0.period?.value.start.year ?? 0)" } == [
            "Developer|Acme Ltd|2020", "Cleaner|Verdi Ltd|2015", "Shop assistant|Blue Shop|2010",
        ])
        #expect(ownLines(found) == [["Built the tools"], ["Cleaned the offices"], ["Served customers"]])
    }

    @Test("One line for each entry with its date at the end, and a short line under it that is its own")
    func oneLineEntriesWithShortLines() throws {
        let found = read("""
        Experience
        Developer at Acme Ltd, 2020 – 2025
        Built the tools
        Cleaner at Verdi Ltd, 2015 – 2020
        Cleaned the offices
        Shop assistant at Blue Shop, 2010 – 2015
        Served customers
        """)
        #expect(found.cv.experience.map { "\($0.role?.value ?? "-")|\($0.employer?.value ?? "-")|\($0.period?.value.start.year ?? 0)" } == [
            "Developer|Acme Ltd|2020", "Cleaner|Verdi Ltd|2015", "Shop assistant|Blue Shop|2010",
        ])
        #expect(ownLines(found) == [["Built the tools"], ["Cleaned the offices"], ["Served customers"]])
    }

    @Test("A line before the first date that names no part is no entry's head when the dates come first")
    func strayLineBeforeTheFirstDate() throws {
        let found = read("""
        Experience
        Selected positions
        2020 – 2021
        Trainee at Northgate Hospital, Leeds
        Helped on the ward
        2019 – 2020
        Cleaner at Verdi Ltd, Leeds
        Cleaned offices
        2018 – 2019
        Shop assistant at Blue Shop, Rome
        Served customers
        """)
        #expect(summary(found) == [
            "Trainee|Northgate Hospital|Leeds|2020", "Cleaner|Verdi Ltd|Leeds|2019", "Shop assistant|Blue Shop|Rome|2018",
        ])
        #expect(found.unplaced.map(\.text) == ["Selected positions"])
    }

    @Test("When both readings fit equally, the common layout is kept and the entries they part differently are flagged")
    func equalReadingsAreFlagged() throws {
        // Opening with a date: dates first is kept
        let datesFirst = read("""
        Experience
        2018 – 2019
        Developer at Acme Ltd
        2020 – 2025
        Cleaner at Verdi Ltd
        2010 – 2020
        """)
        #expect(datesFirst.cv.experience.map { $0.role?.value } == ["Developer", "Cleaner", nil])
        #expect(datesFirst.cv.experience.map(\.check) == [.entryBoundsUnsure, .entryBoundsUnsure, .entryBoundsUnsure])
        // A line above the only date: dates after is kept, and the line is not lost
        let datesAfter = read("""
        Education
        Hotel Reception
        2015 - 2017
        Riverside College, Leeds
        """, kind: .education)
        try #require(datesAfter.cv.education.count == 1)
        #expect(datesAfter.cv.education[0].degree?.value == "Hotel Reception")
        #expect(datesAfter.cv.education[0].school?.value == "Riverside College")
        #expect(datesAfter.cv.education[0].check == .entryBoundsUnsure)
    }

    @Test("A role above its date and the employer under it, and a part named again among the details, keep their entries")
    func partsOnBothSidesOfTheDate() throws {
        let split = read("""
        Experience
        Developer
        2020 – 2025
        Acme Ltd
        Cleaner
        2015 – 2020
        Verdi Ltd
        """)
        #expect(found(split) == ["Developer|Acme Ltd|2020", "Cleaner|Verdi Ltd|2015"])
        let named = read("""
        Education
        Payroll Practice Award
        Example Payroll Institute
        2022
        Bachelor of Arts in tourism
        Riverside University, June 2014
        Modules: event management and accounting
        """, kind: .education)
        #expect(named.cv.education.map { $0.degree?.value } == ["Payroll Practice Award", "Bachelor of Arts in tourism"])
        #expect(named.cv.education.map { $0.school?.value } == ["Example Payroll Institute", "Riverside University"])
    }

    private func found(_ found: Findings) -> [String] {
        found.cv.experience.map { "\($0.role?.value ?? "-")|\($0.employer?.value ?? "-")|\($0.period?.value.start.year ?? 0)" }
    }

    @Test("Lines that name a role and a company again under an entry's head stay its own, with the dates first or after",
          arguments: [true, false], [1, 2])
    func partsNamedAgainUnderTheHead(datesFirst: Bool, linesEach: Int) throws {
        let entries = [
            ("Developer at Acme Ltd", "2020 – 2024", ["Trained an engineer at Client Ltd", "Supported a designer at Partner Ltd"]),
            ("Analyst at Example Ltd", "2015 – 2019", ["Trained an engineer at Customer Ltd", "Supported a designer at Vendor Ltd"]),
            ("Cleaner at Verdi Ltd", "2010 – 2015", ["Trained a cleaner at Rossi Ltd", "Supported a manager at Bianchi Ltd"]),
        ]
        let lines = entries.flatMap { head, dates, others in
            (datesFirst ? [dates, head] : [head, dates]) + others.prefix(linesEach)
        }
        let found = read((["Experience"] + lines).joined(separator: "\n"))
        let layout = "\(datesFirst ? "dates first" : "dates after"), \(linesEach) lines each"
        #expect(self.found(found) == ["Developer|Acme Ltd|2020", "Analyst|Example Ltd|2015", "Cleaner|Verdi Ltd|2010"], "\(layout)")
        let named = entries.map { Array($0.2.prefix(linesEach).compactMap { $0.components(separatedBy: " at ").last }) }
        let companies = found.cv.experience.map { entry in
            let details = entry.details.map(\.value).joined(separator: " ")
            return named.joined().filter { details.contains($0) }
        }
        #expect(companies == named, "\(layout)")
        #expect(found.cv.experience.allSatisfy { $0.check == nil }, "\(layout)")
    }

    @Test("A table's row of column names heads no entry, before or after the dates", arguments: [
        """
        Schulischer Werdegang
        Zeitraum | Schule | Abschluss
        2016 – 2019 | Beispiel-Gymnasium, Leipzig | Abitur
        2010 – 2016 | Beispiel-Realschule, Leipzig | Mittlerer Schulabschluss
        """,
        """
        Schulischer Werdegang
        Abschluss | Schule | Zeitraum
        Abitur | Beispiel-Gymnasium, Leipzig | 2016 – 2019
        Mittlerer Schulabschluss | Beispiel-Realschule, Leipzig | 2010 – 2016
        """,
    ])
    func columnNamesHeadNoEntry(_ text: String) throws {
        let found = read(text, kind: .education)
        #expect(found.cv.education.map { $0.degree?.value } == ["Abitur", "Mittlerer Schulabschluss"])
        #expect(found.cv.education.map { $0.school?.value } == ["Beispiel-Gymnasium", "Beispiel-Realschule"])
        #expect(found.unplaced.count == 1)
    }

    @Test("A period after a role on its line, with LinkedIn's duration after it, anchors its entry")
    func periodBeforeADuration() throws {
        let found = read("""
        Experience
        Team Lead January 2017 - February 2019 (2 years 2 months)
        Northgate Works, Leeds
        Developer March 2015 - December 2016 (1 year 10 months)
        Riverside Yard, Leeds
        """)
        #expect(found.cv.experience.map { $0.role?.value } == ["Team Lead", "Developer"])
        #expect(found.cv.experience.map { $0.period?.value } == [
            ImportedPeriod(start: ym(2017, 1), end: .date(ym(2019, 2))), ImportedPeriod(start: ym(2015, 3), end: .date(ym(2016, 12))),
        ])
    }

    @Test("An end before the start, and a range with no end, are flagged")
    func unreadablePeriods() throws {
        let found = read("""
        Experience
        Developer | Acme Ltd | 2019 –
        """)
        #expect(found.cv.experience.first?.period?.check == .periodOpenEnd)
    }

    // MARK: A city and a state or a country in the line of the employer (#301, #302)

    @Test("An employer with its city and state: the city and the state are the place, the employer is no part of it", arguments: [
        ("Harbor Law Firm, Medford, Ohio", "Harbor Law Firm", "Medford, Ohio"),
        ("Larkin Hardware, Akron, OH", "Larkin Hardware", "Akron, OH"),
        ("Larkin Hardware, Akron, Ohio", "Larkin Hardware", "Akron, Ohio"),
        ("Harbor Dental Studio, Austin, Texas", "Harbor Dental Studio", "Austin, Texas"),
        ("Larkin Hardware, Calgary, Alberta", "Larkin Hardware", "Calgary, Alberta"),
        ("Northgate Hospital, Leeds, West Yorkshire, United Kingdom", "Northgate Hospital", "Leeds, West Yorkshire, United Kingdom"),
        ("Northgate Hospital, Reading, Berkshire, England", "Northgate Hospital", "Reading, Berkshire, England"),
        ("Northgate Hospital, Lyon, Auvergne-Rhône-Alpes, France", "Northgate Hospital", "Lyon, Auvergne-Rhône-Alpes, France"),
    ])
    func employerWithCityAndState(line: String, employer: String, place: String) throws {
        let found = read("""
        Experience
        \(line)
        Executive assistant, March 2015–Present
        Northgate Mill, Seattle, WA
        Administrative assistant, June 2011–March 2015
        """)
        #expect(found.cv.experience.map { $0.employer?.value } == [employer, "Northgate Mill"], "\(line)")
        #expect(found.cv.experience.map { $0.location?.value } == [place, "Seattle, WA"], "\(line)")
        #expect(found.cv.experience.map { $0.location?.check } == [nil, nil], "\(line)")
        #expect(found.cv.experience.map { $0.role?.value } == ["Executive assistant", "Administrative assistant"], "\(line)")
    }

    @Test("A city with its state or country, alone on its line, is one place, however many parts it has", arguments: [
        "Springfield, Illinois, United States", "Leeds, United Kingdom", "Akron, OH", "Austin, Texas",
        "Leeds, West Yorkshire, United Kingdom", "Reading, Berkshire, England", "Lyon, Auvergne-Rhône-Alpes, France",
    ])
    func cityWithRegion(place: String) throws {
        let found = read("""
        Experience
        Executive assistant, March 2015–Present
        Northgate Hospital
        \(place)
        """)
        #expect(found.cv.experience.first?.employer?.value == "Northgate Hospital", "\(place)")
        #expect(found.cv.experience.first?.location?.value == place, "\(place)")
        #expect(found.cv.experience.first?.location?.check == nil, "\(place)")
    }

    @Test("A place that only the place lists would cut from its employer is kept whole and flagged; no part of it becomes the employer", arguments: [
        ("Curitiba, Paraná, Brasil", nil, "Curitiba, Paraná, Brasil"),
        ("Acme Ltda, Curitiba, Paraná, Brasil", "Acme Ltda", "Curitiba, Paraná, Brasil"),
        ("Northgate Hospital, Medford, Brasil", "Northgate Hospital", "Medford, Brasil"),
        // The price: an employer that no list knows, before a city no list knows and its country, is read with the place
        ("Larkin Hardware, Medford, Brasil", nil, "Larkin Hardware, Medford, Brasil"),
    ] as [(String, String?, String)])
    func placeKeptWhole(line: String, employer: String?, place: String) throws {
        let found = read("""
        Experience
        Analista
        \(line)
        2019 - 2021
        """)
        try #require(found.cv.experience.count == 1, "\(line)")
        let entry = found.cv.experience[0]
        #expect(entry.role?.value == "Analista", "\(line)")
        #expect(entry.employer?.value == employer, "\(line)")
        #expect(entry.location?.value == place, "\(line)")
        // A cut that a word of an organisation makes is no guess
        #expect(entry.location?.check == (line.hasPrefix("Northgate") ? nil : .locationByPosition), "\(line)")
    }

    @Test("A place kept whole is in the review list, with the place as its text, in experience and in education")
    func placeKeptWholeIsReviewed() throws {
        let result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText("""
        Anna Weber
        person@example.com

        Experience
        Analista
        Curitiba, Paraná, Brasil
        2019 - 2021

        Education
        Bachelor of Arts
        Curitiba, Paraná, Brasil
        2015 - 2019
        """)
        #expect(result.cv.experience.first?.employer == nil)
        #expect(result.cv.education.first?.school == nil)
        #expect(result.reviewList.contains(ReviewItem(field: .experience(0), reason: .locationByPosition, text: "Curitiba, Paraná, Brasil")))
        #expect(result.reviewList.contains(ReviewItem(field: .education(0), reason: .locationByPosition, text: "Curitiba, Paraná, Brasil")))
    }

    // MARK: What the work was about, after the dates

    /// A job named by its head line, then its dates followed by what the work was about. `{sep}` stands for the mark
    /// between the dates and that description.
    struct DescribedJob: Sendable, CustomTestStringConvertible {
        let name: String
        let text: String
        let role: String
        let employer: String
        let place: String
        let description: String
        let ownBullets: [String]
        let firstBullets: [String]
        var testDescription: String { name }
    }

    static let describedJobs = [
        DescribedJob(name: "for", text: """
            EXPERIENCE
            Senior iOS Engineer — Kestrel Cloud, Hamburg
            March 2020 – Present
            - Led the move of the capture flow to SwiftUI.
            Mobile Developer — Northwind Labs, Lucca, Italy
            May 2014 – June 2017{sep}Field service app for retail teams
            - Built the offline order screens.
            """, role: "Mobile Developer", employer: "Northwind Labs", place: "Lucca, Italy",
            description: "Field service app for retail teams", ownBullets: ["Built the offline order screens."],
            firstBullets: ["Led the move of the capture flow to SwiftUI."]),
        DescribedJob(name: "at", text: """
            EXPERIENCE
            Senior iOS Engineer — Kestrel Cloud, Hamburg
            March 2020 – Present
            - Led the move of the capture flow to SwiftUI.
            Mobile Developer — Northwind Labs, Lucca, Italy
            May 2014 – June 2017{sep}Field service app at a retail chain
            - Built the offline order screens.
            """, role: "Mobile Developer", employer: "Northwind Labs", place: "Lucca, Italy",
            description: "Field service app at a retail chain", ownBullets: ["Built the offline order screens."],
            firstBullets: ["Led the move of the capture flow to SwiftUI."]),
        DescribedJob(name: "lowercase", text: """
            EXPERIENCE
            Senior iOS Engineer — Kestrel Cloud, Hamburg
            March 2020 – Present
            - Led the move of the capture flow to SwiftUI.
            Mobile Developer — Northwind Labs, Lucca, Italy
            May 2014 – June 2017{sep}field service app for retail teams
            - Built the offline order screens.
            """, role: "Mobile Developer", employer: "Northwind Labs", place: "Lucca, Italy",
            description: "field service app for retail teams", ownBullets: ["Built the offline order screens."],
            firstBullets: ["Led the move of the capture flow to SwiftUI."]),
        DescribedJob(name: "German", text: """
            BERUFSERFAHRUNG
            Senior iOS-Entwickler — Kestrel Cloud, Hamburg
            März 2020 – heute
            - Aufnahme nach SwiftUI umgestellt.
            Mobile-Entwickler — Northwind Labs, Lucca, Italien
            Mai 2014 – Juni 2017{sep}Außendienst-App für Handelsteams
            - Offline-Bestellungen gebaut.
            """, role: "Mobile-Entwickler", employer: "Northwind Labs", place: "Lucca, Italien",
            description: "Außendienst-App für Handelsteams", ownBullets: ["Offline-Bestellungen gebaut."],
            firstBullets: ["Aufnahme nach SwiftUI umgestellt."]),
        DescribedJob(name: "Italian", text: """
            ESPERIENZA
            Senior iOS Engineer — Kestrel Cloud, Amburgo
            Marzo 2020 – oggi
            - Portato la cattura su SwiftUI.
            Sviluppatore mobile — Northwind Labs, Lucca
            Maggio 2014 – Giugno 2017{sep}App per i tecnici sul campo
            - Costruito gli ordini offline.
            """, role: "Sviluppatore mobile", employer: "Northwind Labs", place: "Lucca",
            description: "App per i tecnici sul campo", ownBullets: ["Costruito gli ordini offline."],
            firstBullets: ["Portato la cattura su SwiftUI."]),
        DescribedJob(name: "company", text: """
            EXPERIENCE
            Senior iOS Engineer — Kestrel Cloud, Hamburg
            March 2020 – Present
            - Led the move of the capture flow to SwiftUI.
            Mobile Developer — Northwind Labs, Lucca, Italy
            May 2014 – June 2017{sep}App for a logistics company
            - Built the offline order screens.
            """, role: "Mobile Developer", employer: "Northwind Labs", place: "Lucca, Italy",
            description: "App for a logistics company", ownBullets: ["Built the offline order screens."],
            firstBullets: ["Led the move of the capture flow to SwiftUI."]),
        DescribedJob(name: "firm", text: """
            EXPERIENCE
            Senior iOS Engineer — Kestrel Cloud, Hamburg
            March 2020 – Present
            - Led the move of the capture flow to SwiftUI.
            Mobile Developer — Northwind Labs, Lucca, Italy
            May 2014 – June 2017{sep}Portal for an insurance firm
            - Built the offline order screens.
            """, role: "Mobile Developer", employer: "Northwind Labs", place: "Lucca, Italy",
            description: "Portal for an insurance firm", ownBullets: ["Built the offline order screens."],
            firstBullets: ["Led the move of the capture flow to SwiftUI."]),
        DescribedJob(name: "group", text: """
            EXPERIENCE
            Senior iOS Engineer — Kestrel Cloud, Hamburg
            March 2020 – Present
            - Led the move of the capture flow to SwiftUI.
            Mobile Developer — Northwind Labs, Lucca, Italy
            May 2014 – June 2017{sep}Booking tool for a hotel group
            - Built the offline order screens.
            """, role: "Mobile Developer", employer: "Northwind Labs", place: "Lucca, Italy",
            description: "Booking tool for a hotel group", ownBullets: ["Built the offline order screens."],
            firstBullets: ["Led the move of the capture flow to SwiftUI."]),
        DescribedJob(name: "engineers", text: """
            EXPERIENCE
            Senior iOS Engineer — Kestrel Cloud, Hamburg
            March 2020 – Present
            - Led the move of the capture flow to SwiftUI.
            Mobile Developer — Northwind Labs, Lucca, Italy
            May 2014 – June 2017{sep}App for field engineers
            - Built the offline order screens.
            """, role: "Mobile Developer", employer: "Northwind Labs", place: "Lucca, Italy",
            description: "App for field engineers", ownBullets: ["Built the offline order screens."],
            firstBullets: ["Led the move of the capture flow to SwiftUI."]),
        DescribedJob(name: "agency", text: """
            EXPERIENCE
            Senior iOS Engineer — Kestrel Cloud, Hamburg
            March 2020 – Present
            - Led the move of the capture flow to SwiftUI.
            Mobile Developer — Northwind Labs, Lucca, Italy
            May 2014 – June 2017{sep}Work for a public agency
            - Built the offline order screens.
            """, role: "Mobile Developer", employer: "Northwind Labs", place: "Lucca, Italy",
            description: "Work for a public agency", ownBullets: ["Built the offline order screens."],
            firstBullets: ["Led the move of the capture flow to SwiftUI."]),
    ]

    @Test("A line after the dates that says what the work was about stays with its job, under a head that names the role and the employer",
          arguments: describedJobs, [" · ", " | ", " — "])
    func descriptionAfterTheDates(job: DescribedJob, separator: String) throws {
        let text = job.text.replacingOccurrences(of: "{sep}", with: separator)
        let result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard)
            .importText("Tobias Renn\ntobias@example.com\n\n" + text)
        let jobs = result.cv.experience
        try #require(jobs.count == 2, "\(jobs.map { "\($0.role?.value ?? "-")|\($0.employer?.value ?? "-")" })")
        #expect(jobs[0].details.map(\.value) == job.firstBullets)
        #expect(jobs[1].role?.value == job.role)
        #expect(jobs[1].employer?.value == job.employer)
        #expect(jobs[1].location?.value == job.place)
        #expect(jobs[1].check == nil)
        #expect(jobs[1].details.map(\.value) == [job.description] + job.ownBullets)
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.lost(result).map(\.text))")
    }

    @Test("What follows the dates is still read as a place, or as the role and the employer of an entry whose dates come first", arguments: [
        ("Senior iOS Engineer — Kestrel Cloud, Hamburg\nMarch 2020 – Present\n- Led the move of the capture flow to SwiftUI.\n"
            + "Developer — Acme Ltd\n2020 – 2025 · Lucca\n- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud|Hamburg", "Developer|Acme Ltd|Lucca"]),
        ("Senior iOS Engineer — Kestrel Cloud, Hamburg\nMarch 2020 – Present\n- Led the move of the capture flow to SwiftUI.\n"
            + "Developer — Acme Ltd\n2020 – 2025 · London\n- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud|Hamburg", "Developer|Acme Ltd|London"]),
        ("2020 – Present · Senior iOS Engineer at Kestrel Cloud\nTrained an engineer at Client Ltd\n"
            + "2015 – 2019 · Analyst at Example Ltd\n- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud|-", "Analyst|Example Ltd|-"]),
        ("March 2020 – Present · Senior iOS Engineer at Kestrel Cloud\n- Led the move of the capture flow to SwiftUI.\n"
            + "May 2014 – June 2017 · Mobile Developer at Northwind Labs\n- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud|-", "Mobile Developer|Northwind Labs|-"]),
        ("Senior iOS Engineer — Kestrel Cloud, Hamburg\nMarch 2020 – Present\n- Led the move of the capture flow to SwiftUI.\n"
            + "May 2014 – June 2017 · Mobile Developer at Northwind Labs\n- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud|Hamburg", "Mobile Developer|Northwind Labs|-"]),
    ] as [(String, [String])])
    func afterTheDatesUnchanged(text: String, jobs: [String]) throws {
        let result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard)
            .importText("Tobias Renn\ntobias@example.com\n\nEXPERIENCE\n" + text)
        #expect(result.cv.experience.map { "\($0.role?.value ?? "-")|\($0.employer?.value ?? "-")|\($0.location?.value ?? "-")" } == jobs)
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.lost(result).map(\.text))")
    }

    /// The first job of the sections below: its head line names the role, an employer no list knows and the place.
    static let headedJob = "Senior iOS Engineer — Kestrel Cloud, Hamburg\nMarch 2020 – Present\n- Led the move of the capture flow to SwiftUI.\n"

    @Test("Under head lines, every job keeps its head and the line after its dates is its own text", arguments: [
        ("three jobs", headedJob + "Mobile Developer — Northwind Labs, Lucca, Italy\nMay 2014 – June 2017 · App for a logistics company\n"
            + "- Built the offline order screens.\nJunior Developer — Cedar Labs, Leipzig\n2012 – 2014 · Booking tool for a hotel group\n"
            + "- Built the stage rigs.",
         ["Senior iOS Engineer|Kestrel Cloud|Hamburg: Led the move of the capture flow to SwiftUI.",
          "Mobile Developer|Northwind Labs|Lucca, Italy: App for a logistics company / Built the offline order screens.",
          "Junior Developer|Cedar Labs|Leipzig: Booking tool for a hotel group / Built the stage rigs."]),
        ("every job described", "Senior iOS Engineer — Kestrel Cloud, Hamburg\nMarch 2020 – Present · Capture app for a hotel group\n"
            + "- Led the move of the capture flow to SwiftUI.\nMobile Developer — Northwind Labs, Lucca, Italy\n"
            + "May 2014 – June 2017 · App for a logistics company\n- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud|Hamburg: Capture app for a hotel group / Led the move of the capture flow to SwiftUI.",
          "Mobile Developer|Northwind Labs|Lucca, Italy: App for a logistics company / Built the offline order screens."]),
        ("blank lines", "\nSenior iOS Engineer — Kestrel Cloud, Hamburg\nMarch 2020 – Present\n- Led the move of the capture flow to SwiftUI.\n\n"
            + "Mobile Developer — Northwind Labs, Lucca, Italy\nMay 2014 – June 2017 · App for a logistics company\n"
            + "- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud|Hamburg: Led the move of the capture flow to SwiftUI.",
          "Mobile Developer|Northwind Labs|Lucca, Italy: App for a logistics company / Built the offline order screens."]),
        ("head on two lines", "Senior iOS Engineer\nKestrel Cloud, Hamburg\nMarch 2020 – Present\n- Led the move of the capture flow to SwiftUI.\n"
            + "Mobile Developer\nNorthwind Labs, Lucca, Italy\nMay 2014 – June 2017 · App for a logistics company\n"
            + "- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud|Hamburg: Led the move of the capture flow to SwiftUI.",
          "Mobile Developer|Northwind Labs|Lucca, Italy: App for a logistics company / Built the offline order screens."]),
    ] as [(String, String, [String])])
    func headsAboveDescribedDates(name: String, text: String, jobs: [String]) throws {
        let result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard)
            .importText("Tobias Renn\ntobias@example.com\n\nEXPERIENCE\n" + text)
        let read = result.cv.experience.map { job in
            "\(job.role?.value ?? "-")|\(job.employer?.value ?? "-")|\(job.location?.value ?? "-"): "
                + job.details.map(\.value).joined(separator: " / ")
        }
        #expect(read == jobs, "\(name)")
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.lost(result).map(\.text))")
    }

    @Test("A section whose dates come first, or whose head line names one part, cuts and names its jobs as before", arguments: [
        ("dates first", "2020 – Present · Tinkerer at Harbor Mill\nTrained an engineer at Client Ltd\n"
            + "2015 – 2019 · Puppeteer at Lantern Orbit\nBuilt the offline order screens",
         ["Tinkerer|Harbor Mill", "Puppeteer|Lantern Orbit"]),
        ("dates first, known role", "2020 – Present · Senior iOS Engineer at Kestrel Cloud\nTrained an engineer at Client Ltd\n"
            + "2015 – 2019 · Puppeteer at Lantern Orbit\n- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud", "Puppeteer|Lantern Orbit"]),
        ("dates first, for", "2020 – Present · Tinkerer at Harbor Mill\nWorked for a retail chain\n"
            + "2015 – 2019 · Puppeteer at Lantern Orbit\nBuilt the offline order screens",
         ["Tinkerer|Harbor Mill", "Puppeteer|Lantern Orbit"]),
        ("dates first, three jobs", "2020 – Present · Tinkerer at Harbor Mill\nTrained an engineer at Client Ltd\n"
            + "2015 – 2019 · Puppeteer at Lantern Orbit\nWorked for a retail chain\n2012 – 2015 · Juggler at Cedar Labs\nBuilt the stage rigs",
         ["Tinkerer|Harbor Mill", "Puppeteer|Lantern Orbit", "Juggler|Cedar Labs"]),
        ("dates first, after a line that introduces them", "Selected roles\n2020 – Present · Tinkerer at Harbor Mill\n"
            + "Trained an engineer at Client Ltd\n2015 – 2019 · Puppeteer at Lantern Orbit\nBuilt the offline order screens",
         ["Tinkerer|Harbor Mill", "Puppeteer|Lantern Orbit"]),
        ("dates first, known role, after a line that introduces them", "Selected roles\n"
            + "2020 – Present · Senior iOS Engineer at Kestrel Cloud\nTrained an engineer at Client Ltd\n"
            + "2015 – 2019 · Puppeteer at Lantern Orbit\n- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud", "Puppeteer|Lantern Orbit"]),
        ("employer above, role after the dates", headedJob + "Northwind Labs, Lucca\nMay 2014 – June 2017 · Mobile Developer\n"
            + "- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud", "Mobile Developer|Northwind Labs"]),
        ("unknown employer above, role after the dates", headedJob + "Harbor Mill, Lucca\nMay 2014 – June 2017 · Mobile Developer\n"
            + "- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud", "Mobile Developer|Harbor Mill"]),
        ("role and place above, employer after the dates", headedJob + "Mobile Developer — Lucca\n"
            + "May 2014 – June 2017 · Northwind Labs\n- Built the offline order screens.",
         ["Senior iOS Engineer|Kestrel Cloud", "Mobile Developer|Northwind Labs"]),
    ] as [(String, String, [String])])
    func jobsCutAsBefore(name: String, text: String, jobs: [String]) throws {
        let result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard)
            .importText("Tobias Renn\ntobias@example.com\n\nEXPERIENCE\n" + text)
        #expect(result.cv.experience.map { "\($0.role?.value ?? "-")|\($0.employer?.value ?? "-")" } == jobs, "\(name)")
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.lost(result).map(\.text))")
    }

    @Test("A name after the dates, whose only words in lower case join it, stays the job's employer", arguments: [
        ("English", "Analyst — Risk team, London\n2014 – 2017 · Bank of the West of England\n- Built the risk reports.",
         ["Analyst|Bank of the West of England"]),
        ("English, second job", headedJob + "Analyst — Risk team, London\n2014 – 2017 · Bank of the West of England\n"
            + "- Built the risk reports.",
         ["Senior iOS Engineer|Kestrel Cloud", "Analyst|Bank of the West of England"]),
        ("German", headedJob + "Analyst — Risikoteam, Leipzig\n2014 – 2017 · Bank für Wirtschaft und Handel\n"
            + "- Built the risk reports.",
         ["Senior iOS Engineer|Kestrel Cloud", "Analyst|Bank für Wirtschaft und Handel"]),
        ("French", headedJob + "Analyst — Risk team, Lyon\n2014 – 2017 · Banque de la Ville de Lyon\n- Built the risk reports.",
         ["Senior iOS Engineer|Kestrel Cloud", "Analyst|Banque de la Ville de Lyon"]),
        ("Italian", headedJob + "Mobile Developer — Platform team, Lucca\n2014 – 2017 · Ministero della Salute\n"
            + "- Built the branch app.",
         ["Senior iOS Engineer|Kestrel Cloud", "Mobile Developer|Ministero della Salute"]),
    ] as [(String, String, [String])])
    func nameAfterTheDates(name: String, text: String, jobs: [String]) throws {
        let result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard)
            .importText("Tobias Renn\ntobias@example.com\n\nEXPERIENCE\n" + text)
        let read = result.cv.experience.map { "\($0.role?.value ?? "-")|\($0.employer?.value ?? "-")" }
        #expect(read == jobs, "\(name)")
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.lost(result).map(\.text))")
    }

    @Test("Education under head lines reads its date lines as before: a degree or a school after the dates keeps its part", arguments: [
        ("degree after the dates", "Alder University — Department of Physics\n2018 – 2020 · Bachelor of science in physics\n"
            + "- Studied autonomous navigation.",
         ["Bachelor of science in physics|Alder University|Department of Physics: Studied autonomous navigation."]),
        ("degree after the dates, second entry", "Leipzig Vocational Institute — School of Design, Leipzig\n2014 – 2016 · Diploma in graphic design\n"
            + "- Drew the posters of the school fair.\nAlder University — Department of Physics\n"
            + "2018 – 2020 · Bachelor of science in physics\n- Studied autonomous navigation.",
         ["Diploma in graphic design|Leipzig Vocational Institute|Leipzig: School of Design / Drew the posters of the school fair.",
          "Bachelor of science in physics|Alder University|Department of Physics: Studied autonomous navigation."]),
        ("school after the dates", "Laurea in Fisica — Ottica quantistica, Torino\n2018 – 2020 · Università degli Studi di Torino\n"
            + "- Tesi sui laser.",
         ["Laurea in Fisica|Università degli Studi di Torino|Torino: Ottica quantistica / Tesi sui laser."]),
        ("school after the dates, second entry", "Diploma di perito — Elettronica, Torino\n2012 – 2017 · Istituto tecnico di Torino\n"
            + "- Progetto sui sensori.\nLaurea in Fisica — Ottica quantistica, Torino\n2018 – 2020 · Università degli Studi di Torino\n"
            + "- Tesi sui laser.",
         ["Diploma di perito|Istituto tecnico di Torino|Torino: Elettronica / Progetto sui sensori.",
          "Laurea in Fisica|Università degli Studi di Torino|Torino: Ottica quantistica / Tesi sui laser."]),
    ] as [(String, String, [String])])
    func educationUnderHeadLines(name: String, text: String, studies: [String]) throws {
        let result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard)
            .importText("Tobias Renn\ntobias@example.com\n\nEDUCATION\n" + text)
        let read = result.cv.education.map { study in
            "\(study.degree?.value ?? "-")|\(study.school?.value ?? "-")|\(study.location?.value ?? "-"): "
                + study.details.map(\.value).joined(separator: " / ")
        }
        #expect(read == studies, "\(name)")
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.lost(result).map(\.text))")
    }
}

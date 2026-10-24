import Testing
@testable import PrestoCVImporting

@Suite("Reading the entries of experience and education")
struct EntryReaderTests {

    private func read(_ text: String, kind: EntryReader.Kind = .experience) -> Findings {
        let (document, sections) = pasted(text)
        var findings = Findings(document: document)
        for section in sections where section.kind == .experience || section.kind == .education {
            EntryReader.read(section, kind: kind, into: &findings)
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

    @Test("An end before the start, and a range with no end, are flagged")
    func unreadablePeriods() throws {
        let found = read("""
        Experience
        Developer | Acme Ltd | 2019 –
        """)
        #expect(found.cv.experience.first?.period?.check == .periodOpenEnd)
    }
}

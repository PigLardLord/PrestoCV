import Testing
@testable import PrestoCVImporting

@Suite("Entries written as bullet lines with the period first")
struct BulletEntryTests {

    private func read(_ text: String, kind: EntryReader.Kind) -> Findings {
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

    @Test("Education bullets with a sentence under one: both entries are read, the sentence is a detail")
    func educationMixedEnglish() throws {
        let found = read("""
        Education
        * 2021 – Nursing course – Leeds College, Leeds
        I finished 1000 hours of training.
        * 2012 – Diploma – Leeds High School, Leeds
        """, kind: .education)
        #expect(found.cv.education.count == 2)
        #expect(found.cv.education.map { $0.school?.value } == ["Leeds College", "Leeds High School"])
        #expect(found.cv.education.map { $0.degree?.value } == ["Nursing course", "Diploma"])
        #expect(found.cv.education.first?.details.map(\.value) == ["I finished 1000 hours of training."])
    }

    @Test("Experience bullets with a sentence under one, in German")
    func experienceMixedGerman() throws {
        let found = read("""
        Berufserfahrung
        • 2019 – 2022 – Elektriker – Beispiel GmbH, Erfurt
        Ich habe die Installationen geplant und geprüft.
        • 2015 – 2019 – Monteur – Muster AG, Jena
        """, kind: .experience)
        #expect(found.cv.experience.count == 2)
        #expect(found.cv.experience.map { $0.role?.value } == ["Elektriker", "Monteur"])
        #expect(found.cv.experience.map { $0.employer?.value } == ["Beispiel GmbH", "Muster AG"])
        #expect(found.cv.experience.first?.details.map(\.value) == ["Ich habe die Installationen geplant und geprüft."])
    }

    @Test("Education bullets only, in Italian")
    func educationOnlyBulletsItalian() throws {
        let found = read("""
        Istruzione
        • 2021 – Corso di infermieristica – Istituto Esempio, Torino
        • 2012 – Diploma – Liceo Esempio, Torino
        """, kind: .education)
        #expect(found.cv.education.count == 2)
        #expect(found.cv.education.map { $0.school?.value } == ["Istituto Esempio", "Liceo Esempio"])
        #expect(found.cv.education.map { $0.degree?.value } == ["Corso di infermieristica", "Diploma"])
    }

    @Test("Experience bullets with sentences between them, in Italian")
    func experienceMixedItalian() throws {
        let found = read("""
        Esperienza professionale
        • 2020 – 2023 – Infermiera – Ospedale Esempio, Torino
        Assistenza ai pazienti in terapia intensiva.
        • 2016 – 2020 – Operatrice – Clinica Esempio, Milano
        Reparto di cardiologia.
        """, kind: .experience)
        #expect(found.cv.experience.count == 2)
        #expect(found.cv.experience.map { $0.role?.value } == ["Infermiera", "Operatrice"])
        #expect(found.cv.experience.map { $0.details.map(\.value) } == [["Assistenza ai pazienti in terapia intensiva."], ["Reparto di cardiologia."]])
    }

    @Test("The one-line split of a bullet: the period, the course, the school and the city")
    func oneLineSplit() throws {
        let found = read("""
        Education
        • 2021 – Course – School, City
        """, kind: .education)
        try #require(found.cv.education.count == 1)
        let entry = found.cv.education[0]
        #expect(entry.degree?.value == "Course")
        #expect(entry.school?.value == "School")
        #expect(entry.location?.value == "City")
        #expect(entry.period?.value.start == YearMonth(year: 2021, month: nil))
    }

    @Test("Undated bullets under a dated job stay its details, even when one starts with a year")
    func detailsStayDetails() throws {
        let found = read("""
        Work Experience
        Nurse at Example Hospital, Leeds
        Jan 2020 – Present
        • Cared for patients
        • 2021 moved to the night ward
        • Trained new colleagues
        """, kind: .experience)
        #expect(found.cv.experience.count == 1)
        #expect(found.cv.experience.first?.details.count == 3)
    }

    // MARK: The class: detail bullets never vote and never become entries

    fileprivate struct Words {
        let language: String
        let heading: String
        let kind: EntryReader.Kind
        let entries: [String]
        let heads: [String]
        let places: [String]
        let plain: String
        let count: String
        let yearAndProse: String
        let sentence: String
        /// A count after a year and a date separator ("• 2000 – hours of placement")
        let countAfterSeparator: String
    }

    private static let english = Words(
        language: "English", heading: "Education", kind: .education,
        entries: ["• 2021 – Nursing course – Leeds College, Leeds", "• 2012 – Diploma – Leeds High School, Leeds"],
        heads: ["Nursing course", "Diploma"], places: ["Leeds College", "Leeds High School"],
        plain: "• Clinical placements", count: "• 2000 hours of clinical training",
        yearAndProse: "• 2019 led the move to the new ward", sentence: "I completed the practical training.",
        countAfterSeparator: "• 2000 – hours of placement")
    private static let german = Words(
        language: "German", heading: "Berufserfahrung", kind: .experience,
        entries: ["• 2019 – 2022 – Elektriker – Beispiel GmbH, Erfurt", "• 2015 – 2019 – Monteur – Muster AG, Jena"],
        heads: ["Elektriker", "Monteur"], places: ["Beispiel GmbH", "Muster AG"],
        plain: "• Planung der Installationen", count: "• 2000 Stunden Baustellenpraxis",
        yearAndProse: "• 2019 leitete den Umzug in die neue Halle", sentence: "Ich habe die Installationen geprüft.",
        countAfterSeparator: "• 2000 – Stunden Praktikum")
    private static let italian = Words(
        language: "Italian", heading: "Istruzione", kind: .education,
        entries: ["• 2021 – Corso di infermieristica – Istituto Esempio, Torino", "• 2012 – Diploma – Liceo Esempio, Torino"],
        heads: ["Corso di infermieristica", "Diploma"], places: ["Istituto Esempio", "Liceo Esempio"],
        plain: "• Tirocini in reparto", count: "• 2000 ore di formazione clinica",
        yearAndProse: "• 2019 ha guidato il trasferimento al nuovo reparto", sentence: "Ho completato la formazione pratica.",
        countAfterSeparator: "• 2000 – ore di tirocinio")
    private static let spanish = Words(
        language: "Spanish", heading: "Formación", kind: .education,
        entries: ["• 2021 – Curso de enfermería – Colegio Ejemplo, Madrid", "• 2012 – Diploma – Instituto Ejemplo, Madrid"],
        heads: ["Curso de enfermería", "Diploma"], places: ["Colegio Ejemplo", "Instituto Ejemplo"],
        plain: "• Prácticas en hospital", count: "• 2000 horas de formación clínica",
        yearAndProse: "• 2019 dirigió el traslado a la nueva planta", sentence: "Completé la formación práctica.",
        countAfterSeparator: "• 2000 – horas de prácticas")
    private static let french = Words(
        language: "French", heading: "Formation", kind: .education,
        entries: ["• 2021 – Cours d'infirmerie – Lycée Exemple, Lyon", "• 2012 – Diplôme – Institut Exemple, Lyon"],
        heads: ["Cours d'infirmerie", "Diplôme"], places: ["Lycée Exemple", "Institut Exemple"],
        plain: "• Stages en service", count: "• 2000 heures de formation clinique",
        yearAndProse: "• 2019 a dirigé le transfert vers le nouveau service", sentence: "J'ai terminé la formation pratique.",
        countAfterSeparator: "• 2000 – heures de stage")

    fileprivate struct Shape: CustomTestStringConvertible, Sendable {
        let words: Words
        let detail: String
        let between: Int
        let after: Int
        var testDescription: String { "\(words.language), \(detail) x \(between) between, \(after) after" }
    }

    fileprivate static let shapes: [Shape] = [english, german, italian, spanish, french].flatMap { words -> [Shape] in
        ["plain", "count", "yearAndProse", "sentence", "countAfterSeparator"].flatMap { detail in
            [(0, 0), (1, 0), (2, 0), (1, 1), (2, 2)].map { Shape(words: words, detail: detail, between: $0.0, after: $0.1) }
        }
    }

    private static func line(of detail: String, in words: Words) -> String {
        switch detail {
        case "plain": words.plain
        case "count": words.count
        case "yearAndProse": words.yearAndProse
        case "countAfterSeparator": words.countAfterSeparator
        default: words.sentence
        }
    }

    @Test("Entry bullets keep both entries whatever detail lines stand between and after them", arguments: shapes)
    fileprivate func entriesSurviveTheirDetails(_ shape: Shape) throws {
        let words = shape.words
        let detail = Self.line(of: shape.detail, in: words)
        // The sentence under the first entry makes the section a mixed one: bullets with other lines
        let lines = [words.heading, words.entries[0], words.sentence] + Array(repeating: detail, count: shape.between)
            + [words.entries[1]] + Array(repeating: detail, count: shape.after)
        let found = read(lines.joined(separator: "\n"), kind: words.kind)
        let entries = words.kind == .education
            ? found.cv.education.map { ($0.degree?.value, $0.school?.value, $0.details.count) }
            : found.cv.experience.map { ($0.role?.value, $0.employer?.value, $0.details.count) }
        try #require(entries.count == 2)
        #expect(entries.map { $0.0 } == words.heads)
        #expect(entries.map { $0.1 } == words.places)
        #expect(entries[0].2 == shape.between + 1)
        #expect(entries[1].2 == shape.after)
    }

    @Test("Undated detail bullets beside a sentence do not erase the entries")
    func detailBulletsKeepTheEntries() throws {
        let found = read("""
        Education
        • 2021 – Nursing course – Leeds College, Leeds
        I completed the practical training.
        • Clinical placements
        • 2012 – Diploma – Leeds High School, Leeds
        • Laboratory training
        """, kind: .education)
        #expect(found.cv.education.map { $0.degree?.value } == ["Nursing course", "Diploma"])
        #expect(found.cv.education.map { $0.details.count } == [2, 1])
        #expect(found.unplaced.isEmpty)
    }

    @Test("A bullet that starts with a count is a detail, not an entry dated with that number")
    func countIsNoPeriod() throws {
        let found = read("""
        Education
        • 2021 – Nursing course – Leeds College, Leeds
        I completed the practical training.
        • 2000 hours of clinical training
        """, kind: .education)
        #expect(found.cv.education.count == 1)
        #expect(found.cv.education.first?.details.count == 2)
    }

    @Test("A bullet with its period alone, or with a head of one part, still opens an entry under details")
    func periodAloneAndShortHeads() throws {
        let found = read("""
        Istruzione
        • 2015 – Corso Croce Rossa Italiana
        A giugno 2015 ho completato il corso.
        • 2012 – Diploma – Liceo Esempio, Torino
        • 2010
        • Tirocinio in reparto
        """, kind: .education)
        #expect(found.cv.education.count == 3)
        #expect(found.cv.education.first?.degree?.value == "Corso Croce Rossa Italiana")
    }

    // MARK: What follows the year decides, with a separator or without

    fileprivate struct Dated: CustomTestStringConvertible, Sendable {
        let language: String
        let heading: String
        let kind: EntryReader.Kind
        let lines: [String]
        /// The school of an education entry, the role of an experience entry
        let heads: [String]
        var testDescription: String { "\(language), \(lines.joined(separator: " / "))" }
    }

    fileprivate static let datedHeads: [Dated] = [
        Dated(language: "English", heading: "Education", kind: .education,
              lines: ["• 2021 Leeds College", "• 2012 Leeds High School"], heads: ["Leeds College", "Leeds High School"]),
        Dated(language: "English", heading: "Education", kind: .education,
              lines: ["• 2021 – Leeds College", "• 2012 – Leeds High School"], heads: ["Leeds College", "Leeds High School"]),
        Dated(language: "English", heading: "Work Experience", kind: .experience,
              lines: ["• 2019 Electrician", "• 2015 Plumber"], heads: ["Electrician", "Plumber"]),
        Dated(language: "English", heading: "Work Experience", kind: .experience,
              lines: ["• 2019 – Electrician", "• 2015 – Plumber"], heads: ["Electrician", "Plumber"]),
        Dated(language: "German", heading: "Ausbildung", kind: .education,
              lines: ["• 2021 Hochschule Erfurt", "• 2012 Gymnasium Jena"], heads: ["Hochschule Erfurt", "Gymnasium Jena"]),
        Dated(language: "German", heading: "Berufserfahrung", kind: .experience,
              lines: ["• 2019 Elektriker", "• 2015 Monteur"], heads: ["Elektriker", "Monteur"]),
        Dated(language: "Italian", heading: "Istruzione", kind: .education,
              lines: ["• 2021 Liceo Esempio", "• 2012 Istituto Esempio"], heads: ["Liceo Esempio", "Istituto Esempio"]),
        Dated(language: "Italian", heading: "Esperienza professionale", kind: .experience,
              lines: ["• 2019 Infermiera", "• 2015 Operatrice"], heads: ["Infermiera", "Operatrice"]),
        Dated(language: "Spanish", heading: "Formación", kind: .education,
              lines: ["• 2021 Colegio Ejemplo", "• 2012 Instituto Ejemplo"], heads: ["Colegio Ejemplo", "Instituto Ejemplo"]),
        Dated(language: "French", heading: "Formation", kind: .education,
              lines: ["• 2021 Lycée Exemple", "• 2012 Institut Exemple"], heads: ["Lycée Exemple", "Institut Exemple"]),
    ]

    @Test("A bulleted section of dated schools or jobs is read entry by entry, with or without a separator", arguments: datedHeads)
    fileprivate func datedHeadsAreEntries(_ dated: Dated) throws {
        let found = read(([dated.heading] + dated.lines).joined(separator: "\n"), kind: dated.kind)
        let heads = dated.kind == .education
            ? found.cv.education.map { $0.school?.value ?? $0.degree?.value }
            : found.cv.experience.map { $0.role?.value ?? $0.employer?.value }
        #expect(heads == dated.heads)
        #expect(found.unplaced.isEmpty)
    }

    fileprivate static let counts: [(words: Words, line: String)] = [
        (english, "• 2000 – hours of placement"), (english, "• 2000 hours of placement"),
        (german, "• 1200 – Stunden Praktikum"), (german, "• 2000 – Stunden Praktikum"), (german, "• 2000 Stunden Praktikum"),
        (italian, "• 800 – ore di tirocinio"), (italian, "• 2000 – ore di tirocinio"), (italian, "• 2000 ore di tirocinio"),
        (spanish, "• 2000 – horas de prácticas"), (spanish, "• 2000 horas de prácticas"),
        (french, "• 2000 – heures de stage"), (french, "• 2000 heures de stage"),
        (english, "• 2010 – clients served"), (english, "• 2010 – people trained"), (english, "• 2000 – 3 projects delivered"),
        (german, "• 2010 – Kunden betreut"), (german, "• 2010 – Mitarbeiter geschult"),
        (italian, "• 2010 – clienti seguiti"), (italian, "• 2010 – persone formate"),
        (german, "• 2000 – Prüfungen durchgeführt"), (german, "• 2000 Prüfungen durchgeführt"),
        (german, "• 2000 – Schulungen geleitet"), (german, "• 2000 Audits begleitet"),
        (english, "• 2000 hours completed"), (english, "• 2000 – hours completed"), (english, "• 2000 – exams supervised"),
        (italian, "• 800 ore svolte"), (italian, "• 2000 – esami svolti"),
        (spanish, "• 2000 horas realizadas"), (spanish, "• 2000 – exámenes supervisados"),
        (french, "• 2000 heures effectuées"), (french, "• 2000 – examens surveillés"),
    ]

    @Test("A count after a year is a detail of the entry above, last or between, with a separator or without")
    func countsAreDetails() throws {
        for (words, line) in Self.counts {
            // The sentence under the first entry makes the section a mixed one
            let last = read(([words.heading, words.entries[0], words.sentence, line]).joined(separator: "\n"), kind: words.kind)
            let between = read(([words.heading, words.entries[0], words.sentence, line, words.entries[1]]).joined(separator: "\n"), kind: words.kind)
            let lastEntries = words.kind == .education ? last.cv.education.count : last.cv.experience.count
            let betweenEntries = words.kind == .education ? between.cv.education.count : between.cv.experience.count
            #expect(lastEntries == 1, "\(line) last")
            #expect(betweenEntries == 2, "\(line) between")
            let details = words.kind == .education ? last.cv.education.first?.details.map(\.value) : last.cv.experience.first?.details.map(\.value)
            #expect(details?.last == String(line.dropFirst(2)), "\(line) detail")
            #expect(details?.count == 2, "\(line) details")
        }
    }

    @Test("Employers with a lower-case name particle head their entries in a section that also holds sentences", arguments: [
        ("Berufserfahrung", "• 2021 – von Linden GmbH", "• 2018 – von Falk GmbH", "von Linden GmbH", "von Falk GmbH"),
        ("Esperienza professionale", "• 2021 – di Rossi S.r.l.", "• 2018 – di Bianchi S.p.A.", "di Rossi S.r.l.", "di Bianchi S.p.A."),
        ("Experiencia profesional", "• 2021 – de la Torre S.L.", "• 2018 – de Vega S.A.", "de la Torre S.L.", "de Vega S.A."),
        ("Expérience professionnelle", "• 2021 – de Lacroix SARL", "• 2018 – de Moreau SAS", "de Lacroix SARL", "de Moreau SAS"),
    ])
    func particleEmployers(_ heading: String, _ first: String, _ second: String, _ firstEmployer: String, _ secondEmployer: String) throws {
        let found = read("\(heading)\n\(first)\nSentence about the work.\n\(second)", kind: .experience)
        #expect(found.cv.experience.map { $0.employer?.value } == [firstEmployer, secondEmployer])
        #expect(found.cv.experience.map { $0.period?.value.start.year } == [2021, 2018])
    }

    @Test("An award line that starts with a particle and ends in prose stays a detail of the entry above")
    func particleAwardIsADetail() throws {
        let found = read("Max Beispiel\nBerufserfahrung\n• 2021 – Elektriker – Beispiel GmbH\nIch habe die Installationen geprüft.\n• 2019 – von Muster GmbH ausgezeichnet", kind: .experience)
        try #require(found.cv.experience.count == 1)
        #expect(found.cv.experience[0].role?.value == "Elektriker")
        #expect(found.cv.experience[0].employer?.value == "Beispiel GmbH")
        #expect(found.cv.experience[0].period?.value.start.year == 2021)
        #expect(found.cv.experience[0].details.map(\.value) == ["Ich habe die Installationen geprüft.", "2019 – von Muster GmbH ausgezeichnet"])
    }

    @Test("An employer with a particle and a qualifier, a place or a role after its company word is a second entry", arguments: [
        ("• 2019 – von Linden UG (haftungsbeschränkt)", "von Linden UG (haftungsbeschränkt)", nil),
        ("• 2019 – von Linden GmbH, Berlin", "von Linden GmbH", "Berlin"),
        ("• 2019 – von Linden GmbH & Co. KG", "von Linden GmbH & Co. KG", nil),
        ("• 2019 – von Linden GmbH, 99084 Erfurt", "von Linden GmbH", "99084 Erfurt"),
        ("• 2019 – von Linden GmbH – Elektriker", "von Linden GmbH", nil),
        ("• 2019 – von Linden GmbH, Elektriker, Berlin", "von Linden GmbH", "Berlin"),
        ("• 2019 – von Linden GmbH – Elektriker, Berlin", "von Linden GmbH", "Berlin"),
        ("• 2019 – von Linden GmbH, Elektriker, Boston, MA", "von Linden GmbH", "Boston, MA"),
        ("• 2019 – von Linden GmbH – Elektriker – Boston, MA", "von Linden GmbH", "Boston, MA"),
        ("• 2019 – von Linden GmbH, Boston, MA – Elektriker", "von Linden GmbH", "Boston, MA"),
    ] as [(String, String, String?)])
    func particleEmployerWithQualifier(_ line: String, _ employer: String, _ place: String?) throws {
        let found = read("Max Beispiel\nBerufserfahrung\n• 2021 – Elektriker – Beispiel GmbH\nIch habe die Installationen geprüft.\n\(line)", kind: .experience)
        #expect(found.cv.experience.map { $0.employer?.value } == ["Beispiel GmbH", employer])
        #expect(found.cv.experience.map { $0.period?.value.start.year } == [2021, 2019])
        #expect(found.cv.experience.last?.location?.value == place)
        #expect(found.cv.experience.first?.details.map(\.value) == ["Ich habe die Installationen geprüft."])
    }

    @Test("An award line with prose or a noun after a comma or a separator behind the company word stays a detail of the entry above", arguments: [
        "2019 – von Muster GmbH, ausgezeichnet",
        "2019 – von Muster GmbH, Auszeichnung",
        "2019 – von Muster GmbH – Auszeichnung",
        "2019 – von Muster GmbH, Auszeichnung für Elektriker, Berlin",
        "2019 – von Muster GmbH – Auszeichnung für Elektriker, Berlin",
        "2019 – von Muster GmbH, Auszeichnung, Elektriker",
        "2019 – von Muster GmbH – Auszeichnung – Elektriker",
        "2019 – von Muster GmbH – Auszeichnung – Deutschland – Elektriker",
        "2019 – von Muster GmbH, Auszeichnung, Deutschland, Elektriker",
        "2019 – von Muster GmbH, Auszeichnung, Bayern, Deutschland, Elektriker",
        "2019 – von Muster GmbH, Auszeichnung für Elektriker, Boston, MA",
        "2019 – von Muster GmbH, Elektriker, Auszeichnung, Boston, MA",
    ])
    func particleAwardAfterSeparatorIsADetail(_ award: String) throws {
        let found = read("Max Beispiel\nBerufserfahrung\n• 2021 – Elektriker – Beispiel GmbH\nIch habe die Installationen geprüft.\n• \(award)", kind: .experience)
        try #require(found.cv.experience.count == 1)
        #expect(found.cv.experience[0].details.map(\.value) == ["Ich habe die Installationen geprüft.", award])
    }

    @Test("A role and an employer with a particle, in a section that also holds a sentence, are a second entry")
    func particleEmployerAfterRole() throws {
        let found = read("Max Beispiel\nBerufserfahrung\n• 2021 – Elektriker – Beispiel GmbH\nIch habe die Installationen geprüft.\n• 2019 – Mechaniker – von Linden GmbH", kind: .experience)
        #expect(found.cv.experience.map { $0.employer?.value } == ["Beispiel GmbH", "von Linden GmbH"])
        #expect(found.cv.experience.map { $0.role?.value } == ["Elektriker", "Mechaniker"])
        #expect(found.cv.experience.map { $0.period?.value.start.year } == [2021, 2019])
    }

    @Test("The reviewed input: a course with a placement count under it")
    func placementCount() throws {
        let found = read("Education\n• 2021 – Nursing course – Leeds College, Leeds\nI completed the practical training.\n• 2000 – hours of placement", kind: .education)
        try #require(found.cv.education.count == 1)
        #expect(found.cv.education[0].degree?.value == "Nursing course")
        #expect(found.cv.education[0].details.map(\.value) == ["I completed the practical training.", "2000 – hours of placement"])
    }

    @Test("Schools without a separator after the year, as the reviewed input")
    func schoolsWithoutSeparator() throws {
        let found = read("Education\n• 2021 Leeds College\n• 2012 Leeds High School", kind: .education)
        #expect(found.cv.education.map { $0.school?.value } == ["Leeds College", "Leeds High School"])
    }

    // MARK: A word of a head counts only in the head's own part

    fileprivate struct Experience: CustomTestStringConvertible, Sendable {
        let language: String
        let heading: String
        let first: String
        let sentence: String
        let second: String
        let lines: [String]
        var testDescription: String { language }
    }

    fileprivate static let experiences: [Experience] = [
        Experience(
            language: "German", heading: "Berufserfahrung", first: "• 2021 – Elektriker – Beispiel GmbH, Erfurt",
            sentence: "Ich habe die Installationen geprüft.", second: "• 2015 – 2019 – Monteur – Muster AG, Jena",
            lines: [
                "2019 – Von Muster GmbH ausgezeichnet", "2019 – Auszeichnung für Elektriker", "2019 – Auszeichnung für Muster GmbH",
                "2000 – Prüfungen durchgeführt, dokumentiert", "2000 – Prüfungen durchgeführt – dokumentiert",
            ]),
        Experience(
            language: "English", heading: "Work Experience", first: "• 2021 – Electrician – Example Ltd, Leeds",
            sentence: "I checked the installations.", second: "• 2015 – 2019 – Plumber – Sample Ltd, York",
            lines: [
                "2019 – Award for Electrician", "2019 – Muster Ltd named supplier of the year",
                "2000 – Inspections carried out, documented",
            ]),
        Experience(
            language: "Italian", heading: "Esperienza professionale", first: "• 2021 – Elettricista – Esempio S.r.l., Torino",
            sentence: "Ho controllato gli impianti.", second: "• 2015 – 2019 – Idraulico – Campione S.r.l., Milano",
            lines: [
                "2019 – Premio per Elettricista", "2019 – Rossi S.r.l. premiata per la qualità",
                "2000 – Ispezioni svolte, documentate",
            ]),
    ]

    @Test("A line whose role or company word stands inside prose, or whose parts are only separated by a comma, is a detail", arguments: experiences)
    fileprivate func proseAroundAHeadWordIsADetail(_ experience: Experience) {
        for line in experience.lines {
            let last = read([experience.heading, experience.first, experience.sentence, "• " + line].joined(separator: "\n"), kind: .experience)
            #expect(last.cv.experience.count == 1, "\(line) last")
            guard last.cv.experience.count >= 1 else { continue }
            #expect(last.cv.experience[0].details.map(\.value) == [experience.sentence, line], "\(line) last")
            let between = read([experience.heading, experience.first, experience.sentence, "• " + line, experience.second].joined(separator: "\n"), kind: .experience)
            #expect(between.cv.experience.count == 2, "\(line) between")
            guard between.cv.experience.count >= 1 else { continue }
            #expect(between.cv.experience[0].details.map(\.value) == [experience.sentence, line], "\(line) between")
        }
    }

    @Test("The real one-line entries stay entries in a section that also holds a sentence", arguments: [
        ("• 2019 – Elektriker – Muster GmbH, München", "Elektriker", "Muster GmbH"),
        ("• 2019 – Elektriker – Siemens, München", "Elektriker", "Siemens"),
        ("• 2019 – Electrician – Example Ltd, Leeds", "Electrician", "Example Ltd"),
        ("• 2019 – Elettricista – Esempio S.r.l., Torino", "Elettricista", "Esempio S.r.l."),
    ])
    func realEntriesStayEntries(_ line: String, _ role: String, _ employer: String) throws {
        let found = read("Berufserfahrung\n• 2021 – Monteur – Beispiel AG, Jena\nIch habe die Installationen geprüft.\n\(line)", kind: .experience)
        try #require(found.cv.experience.count == 2)
        #expect(found.cv.experience.map { $0.role?.value } == ["Monteur", role])
        #expect(found.cv.experience.map { $0.employer?.value } == ["Beispiel AG", employer])
    }

    // MARK: The words that join a head word to its qualifier

    @Test("A course head joined to its qualifier by a preposition is an education entry", arguments: [
        ("Formazione", "• 2021 – Corso per OSS – FormaOSS, Milano", "A settembre 2021 ho completato le 1.000 ore di tirocinio.", "Corso per OSS", "FormaOSS", "Milano", 2021),
        ("Formation", "• 2019 – Cours pour adultes – Greta, Lyon", "J'ai terminé la formation en juin.", "Cours pour adultes", "Greta", "Lyon", 2019),
        ("Formación", "• 2018 – Curso para docentes – Instituto Cervantes, Madrid", "Completé el curso en junio.", "Curso para docentes", "Instituto Cervantes", "Madrid", 2018),
        ("Formação", "• 2017 – Curso em enfermagem – Senac, São Paulo", "Concluí o curso em junho.", "Curso em enfermagem", "Senac", "São Paulo", 2017),
        ("Formação", "• 2016 – Curso do Senac – Instituto Exemplo, Lisboa", "Concluí o curso em junho.", "Curso do Senac", "Instituto Exemplo", "Lisboa", 2016),
        ("Formazione", "• 2015 – Corso degli infermieri – Istituto Esempio, Torino", "Ho completato il corso a giugno.", "Corso degli infermieri", "Istituto Esempio", "Torino", 2015),
        ("Formation", "• 2014 – Diplôme du Conservatoire – Lycée Exemple, Lyon", "J'ai terminé le cours en juin.", "Diplôme du Conservatoire", "Lycée Exemple", "Lyon", 2014),
    ] as [(String, String, String, String, String, String, Int)])
    func joinedCourseHeads(_ heading: String, _ line: String, _ sentence: String, _ degree: String, _ school: String, _ place: String, _ year: Int) throws {
        let found = read("\(heading)\n\(line)\n\(sentence)", kind: .education)
        try #require(found.cv.education.count == 1)
        let entry = found.cv.education[0]
        #expect(entry.degree?.value == degree)
        #expect(entry.school?.value == school)
        #expect(entry.location?.value == place)
        #expect(entry.period?.value.start.year == year)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A role joined to its employer by a preposition is an experience entry", arguments: [
        ("Esperienza professionale", "• 2020 – Infermiere presso Ospedale Esempio, Milano", "Assistenza ai pazienti in reparto.", 2020),
        ("Expérience professionnelle", "• 2020 – Infirmier chez Exemple SARL, Lyon", "Soins aux patients en service.", 2020),
        ("Experiencia profesional", "• 2020 – Enfermero en Hospital Ejemplo, Madrid", "Atención a los pacientes en planta.", 2020),
        ("Experiência profissional", "• 2020 – Enfermeiro no Hospital Exemplo, Lisboa", "Cuidados aos pacientes na enfermaria.", 2020),
    ] as [(String, String, String, Int)])
    func joinedRoleHeads(_ heading: String, _ line: String, _ sentence: String, _ year: Int) throws {
        let found = read("\(heading)\n\(line)\n\(sentence)", kind: .experience)
        try #require(found.cv.experience.count == 1)
        #expect(found.cv.experience[0].period?.value.start.year == year)
        #expect(found.cv.experience[0].details.map(\.value) == [sentence])
        #expect(found.unplaced.isEmpty)
    }

    @Test("A joining word does not make the prose after it a head: the line stays a detail of the entry above", arguments: [
        "• 2019 – Electrician with responsibility for testing all installations",
        "• 2019 – Consulente per la crescita dei clienti",
        "• 2018 – Elektriker mit Verantwortung für die Prüfung aller Anlagen",
        "• 2018 – Infirmier chez les clients de la région pour les soins",
        "• 2018 – Enfermero para los pacientes de la planta",
        "• 2018 – Enfermeiro com responsabilidade pelos pacientes da enfermaria",
        "• 2018 – Electrician for the testing of installations",
    ])
    func proseAfterAJoiningWordIsADetail(_ line: String) throws {
        let found = read("Experience\n• 2021 – Electrician – Example Ltd\nI checked the installations.\n\(line)", kind: .experience)
        try #require(found.cv.experience.count == 1)
        #expect(found.cv.experience[0].details.map(\.value) == ["I checked the installations.", String(line.dropFirst(2))])
    }

    @Test("A qualifier that is a name or a short subject keeps a joined head an entry", arguments: [
        "• 2016 – Bachelor of Science in Computer Engineering – University of Leeds, Leeds",
        "• 2015 – Master in business administration – Bocconi University, Milano",
        "• 2014 – Diploma in Gestione delle Risorse Umane – Istituto Esempio, Torino",
        "• 2013 – Diploma in nursing – St Mary's Hospital School, Leeds",
    ])
    func nameOrShortSubjectQualifier(_ line: String) throws {
        let found = read("Education\n• 2021 – Nursing course – Leeds College, Leeds\nI finished 1000 hours of training.\n\(line)", kind: .education)
        #expect(found.cv.education.count == 2)
    }

    @Test("A capitalised duty joined like prose is no name: German nouns, or another language, stay a detail of the job above", arguments: [
        "• 2019 – Elektriker für Prüfung und Wartung der Anlagen",
        "• 2019 – Elektriker für Prüfung und Wartung von Anlagen",
        "• 2019 – Tecnico per Installazione e Manutenzione degli Impianti",
        "• 2019 – Elektriker für Wartung der Anlagen bei Muster GmbH",
    ])
    func capitalisedDutyIsADetail(_ line: String) throws {
        let found = read("Experience\n• 2021 – Electrician – Example Ltd\nI checked the installations.\n\(line)", kind: .experience)
        try #require(found.cv.experience.count == 1)
        #expect(found.cv.experience[0].details.map(\.value) == ["I checked the installations.", String(line.dropFirst(2))])
    }

    @Test("A degree or a role with a capitalised name qualifier is an entry in a mixed section", arguments: [
        ("Ausbildung", "• 2014 – Diplom in Technik und Wirtschaft – Hochschule Esempio, Berlin", Section.education),
        ("Esperienza professionale", "• 2020 – Infermiere presso Ospedale San Esempio, Milano", Section.experience),
    ])
    fileprivate func capitalisedNameIsAnEntry(_ heading: String, _ line: String, _ section: Section) throws {
        let first = section == .education ? "• 2021 – Nursing course – Leeds College, Leeds" : "• 2021 – Electrician – Example Ltd, Leeds"
        let found = read("\(heading)\n\(first)\nI finished the work in June.\n\(line)", kind: section == .education ? .education : .experience)
        #expect((section == .education ? found.cv.education.count : found.cv.experience.count) == 2)
    }

    @Test("A duty that opens with a sector or activity word is no institution name, even with an article and a capitalised noun", arguments: [
        "• 2019 – Elektriker für Bau und Wartung der Anlagen",
        "• 2019 – Elektriker für Bau der Anlagen",
        "• 2019 – Elektriker für Technische Prüfung der Anlagen",
        "• 2019 – Tecnico per Studio degli Impianti",
        "• 2019 – Lagerist für Logistik der Lager",
    ])
    func sectorWordDutyIsADetail(_ line: String) throws {
        let found = read("Experience\n• 2021 – Electrician – Example Ltd\nI checked the installations.\n\(line)", kind: .experience)
        try #require(found.cv.experience.count == 1)
        #expect(found.cv.experience[0].details.map(\.value) == ["I checked the installations.", String(line.dropFirst(2))])
    }

    @Test("A qualifier that is itself a school or an employer name passes with its articles", arguments: [
        ("• 2019 – Designer bei Universität der Künste", "Designer", "Universität der Künste"),
        ("• 2018 – Tecnico presso Università degli Studi di Esempio", "Tecnico", "Università degli Studi di Esempio"),
        ("• 2017 – Ingénieur chez Université de la Ville", "Ingénieur", "Université de la Ville"),
    ] as [(String, String, String)])
    func institutionNameWithArticleIsAnEntry(_ line: String, _ role: String, _ employer: String) throws {
        let found = read("Experience\n• 2021 – Electrician – Example Ltd\nI checked the installations.\n\(line)", kind: .experience)
        try #require(found.cv.experience.count == 2)
        #expect(found.cv.experience[1].role?.value == role)
        #expect(found.cv.experience[1].employer?.value == employer)
    }

    @Test("A title-case duty after a role, or a sector word as the head word, is a detail whatever its words", arguments: [
        "• 2019 – Tecnico per Manutenzione degli Impianti",
        "• 2019 – Electrician for Maintenance of Plants",
        "• 2019 – Bau von Anlagen",
        "• 2019 – Studio degli impianti",
    ])
    func titleCaseDutyIsADetail(_ line: String) throws {
        let found = read("Experience\n• 2021 – Electrician – Example Ltd\nI checked the installations.\n\(line)", kind: .experience)
        try #require(found.cv.experience.count == 1)
        #expect(found.cv.experience[0].details.map(\.value) == ["I checked the installations.", String(line.dropFirst(2))])
    }

    @Test("A municipality, a bank or a university after a joining word is an institution and keeps the entry", arguments: [
        "• 2019 – Impiegato presso Comune di Esempio",
        "• 2019 – Banca di Esempio, Milano",
        "• 2019 – Designer bei Universität der Künste",
    ])
    func institutionByItselfIsAnEntry(_ line: String) throws {
        let found = read("Experience\n• 2021 – Electrician – Example Ltd\nI checked the installations.\n\(line)", kind: .experience)
        #expect(found.cv.experience.count == 2)
    }

    // MARK: Head evidence does bounded work

    @Test("A bullet with thousands of joined words is a detail of the entry above, not a second entry")
    func overlongBulletIsADetail() throws {
        let line = "• 2019 – Designer bei " + String(repeating: "GmbH für ", count: 4_000) + "GmbH"
        let found = read("Experience\n• 2021 – Electrician – Example Ltd\nI checked the installations.\n\(line)", kind: .experience)
        try #require(found.cv.experience.count == 1)
        #expect(found.cv.experience[0].details.count == 2)
    }

    @Test("A text longer than a head can be gives no evidence of one")
    func overCapTextIsNoEvidence() {
        let head = "Nursing course – Leeds College, Leeds"
        #expect(EntryVocabulary.headEvidence(after: head) == .strong)
        let long = "Nursing course – " + String(repeating: "Leeds ", count: 60) + "College, Leeds"
        #expect(EntryVocabulary.headEvidence(after: long) != .strong)
        let wide = "Nursing course – Leeds College, " + String(repeating: "Leeds, ", count: 60) + "Leeds"
        #expect(EntryVocabulary.headEvidence(after: wide) != .strong)
    }

    fileprivate enum Section { case education, experience }
}

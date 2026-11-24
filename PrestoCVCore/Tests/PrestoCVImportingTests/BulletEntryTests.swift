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
}

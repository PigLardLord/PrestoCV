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
    }

    private static let english = Words(
        language: "English", heading: "Education", kind: .education,
        entries: ["• 2021 – Nursing course – Leeds College, Leeds", "• 2012 – Diploma – Leeds High School, Leeds"],
        heads: ["Nursing course", "Diploma"], places: ["Leeds College", "Leeds High School"],
        plain: "• Clinical placements", count: "• 2000 hours of clinical training",
        yearAndProse: "• 2019 led the move to the new ward", sentence: "I completed the practical training.")
    private static let german = Words(
        language: "German", heading: "Berufserfahrung", kind: .experience,
        entries: ["• 2019 – 2022 – Elektriker – Beispiel GmbH, Erfurt", "• 2015 – 2019 – Monteur – Muster AG, Jena"],
        heads: ["Elektriker", "Monteur"], places: ["Beispiel GmbH", "Muster AG"],
        plain: "• Planung der Installationen", count: "• 2000 Stunden Baustellenpraxis",
        yearAndProse: "• 2019 leitete den Umzug in die neue Halle", sentence: "Ich habe die Installationen geprüft.")
    private static let italian = Words(
        language: "Italian", heading: "Istruzione", kind: .education,
        entries: ["• 2021 – Corso di infermieristica – Istituto Esempio, Torino", "• 2012 – Diploma – Liceo Esempio, Torino"],
        heads: ["Corso di infermieristica", "Diploma"], places: ["Istituto Esempio", "Liceo Esempio"],
        plain: "• Tirocini in reparto", count: "• 2000 ore di formazione clinica",
        yearAndProse: "• 2019 ha guidato il trasferimento al nuovo reparto", sentence: "Ho completato la formazione pratica.")

    fileprivate struct Shape: CustomTestStringConvertible, Sendable {
        let words: Words
        let detail: String
        let between: Int
        let after: Int
        var testDescription: String { "\(words.language), \(detail) x \(between) between, \(after) after" }
    }

    fileprivate static let shapes: [Shape] = [english, german, italian].flatMap { words -> [Shape] in
        ["plain", "count", "yearAndProse", "sentence"].flatMap { detail in
            [(0, 0), (1, 0), (2, 0), (1, 1), (2, 2)].map { Shape(words: words, detail: detail, between: $0.0, after: $0.1) }
        }
    }

    private static func line(of detail: String, in words: Words) -> String {
        switch detail {
        case "plain": words.plain
        case "count": words.count
        case "yearAndProse": words.yearAndProse
        default: words.sentence
        }
    }

    @Test("Entry bullets keep both entries whatever detail lines stand between and after them", arguments: shapes)
    fileprivate func entriesSurviveTheirDetails(_ shape: Shape) throws {
        let words = shape.words
        let detail = Self.line(of: shape.detail, in: words)
        let lines = [words.heading, words.entries[0]] + Array(repeating: detail, count: shape.between)
            + [words.entries[1]] + Array(repeating: detail, count: shape.after)
        let found = read(lines.joined(separator: "\n"), kind: words.kind)
        let entries = words.kind == .education
            ? found.cv.education.map { ($0.degree?.value, $0.school?.value, $0.details.count) }
            : found.cv.experience.map { ($0.role?.value, $0.employer?.value, $0.details.count) }
        try #require(entries.count == 2)
        #expect(entries.map { $0.0 } == words.heads)
        #expect(entries.map { $0.1 } == words.places)
        #expect(entries[0].2 == shape.between)
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
}

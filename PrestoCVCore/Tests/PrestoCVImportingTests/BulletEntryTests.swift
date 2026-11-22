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
}

import Testing
@testable import PrestoCVImporting

/// A section whose every line is a bullet is read as it was before the bullet rule: its expected readings are the
/// output of the previous release for the same text, written out.
@Suite("Fully bulleted sections keep their reading")
struct BulletOnlySectionTests {

    private static let rows: [(text: String, education: Bool, expected: String)] = [
        ("Work Experience\n• 2021 – von Linden GmbH\n• 2018 – von Falk GmbH", false, "[- | von Linden GmbH | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | von Falk GmbH | - | ImportedPeriod(start: YearMonth(year: 2018, month: nil), end: nil) | ] unplaced: "),
        ("Berufserfahrung\n• 2021 – von Linden GmbH\n• 2018 – von Falk GmbH", false, "[- | von Linden GmbH | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | von Falk GmbH | - | ImportedPeriod(start: YearMonth(year: 2018, month: nil), end: nil) | ] unplaced: "),
        ("Berufserfahrung\n• 2021 von Linden GmbH\n• 2018 von Falk GmbH", false, "[- | von Linden GmbH | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | von Falk GmbH | - | ImportedPeriod(start: YearMonth(year: 2018, month: nil), end: nil) | ] unplaced: "),
        ("Esperienza professionale\n• 2021 – di Rossi S.r.l.\n• 2018 – di Bianchi S.p.A.", false, "[- | di Rossi S.r.l. | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | di Bianchi S.p.A. | - | ImportedPeriod(start: YearMonth(year: 2018, month: nil), end: nil) | ] unplaced: "),
        ("Experiencia profesional\n• 2021 – de la Torre S.L.\n• 2018 – de Vega S.A.", false, "[- | de la Torre S.L. | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | de Vega S.A. | - | ImportedPeriod(start: YearMonth(year: 2018, month: nil), end: nil) | ] unplaced: "),
        ("Expérience professionnelle\n• 2021 – de Lacroix SARL\n• 2018 – de Moreau SAS", false, "[- | de Lacroix SARL | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | de Moreau SAS | - | ImportedPeriod(start: YearMonth(year: 2018, month: nil), end: nil) | ] unplaced: "),
        ("Berufserfahrung\n• 2021 – Elektriker – Beispiel GmbH, Erfurt\n• 2000 – Prüfungen durchgeführt", false, "[Elektriker | Beispiel GmbH | Erfurt | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [Prüfungen durchgeführt | - | - | ImportedPeriod(start: YearMonth(year: 2000, month: nil), end: nil) | ] unplaced: "),
        ("Berufserfahrung\n• 2021 – Elektriker – Beispiel GmbH, Erfurt\n• 2000 Prüfungen durchgeführt", false, "[Elektriker | Beispiel GmbH | Erfurt | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [Prüfungen durchgeführt | - | - | ImportedPeriod(start: YearMonth(year: 2000, month: nil), end: nil) | ] unplaced: "),
        ("Berufserfahrung\n• 2021 – Elektriker – Beispiel GmbH, Erfurt\n• 2000 Stunden Praktikum", false, "[Elektriker | Beispiel GmbH | Erfurt | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [Stunden Praktikum | - | - | ImportedPeriod(start: YearMonth(year: 2000, month: nil), end: nil) | ] unplaced: "),
        ("Esperienza professionale\n• 2021 – Infermiera – Ospedale Esempio, Torino\n• 800 ore svolte", false, "[Infermiera | Ospedale Esempio | Torino | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | 800 ore svolte] unplaced: "),
        ("Work Experience\n• 2021 – Electrician – Example Ltd, Leeds\n• 2000 hours completed", false, "[Electrician | Example Ltd | Leeds | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [hours completed | - | - | ImportedPeriod(start: YearMonth(year: 2000, month: nil), end: nil) | ] unplaced: "),
        ("Work Experience\n• 2019 Electrician\n• 2015 Plumber", false, "[Electrician | - | - | ImportedPeriod(start: YearMonth(year: 2019, month: nil), end: nil) | ] [Plumber | - | - | ImportedPeriod(start: YearMonth(year: 2015, month: nil), end: nil) | ] unplaced: "),
        ("Work Experience\n• 2019 Acme\n• 2015 Beta", false, "[Acme | - | - | ImportedPeriod(start: YearMonth(year: 2019, month: nil), end: nil) | ] [Beta | - | - | ImportedPeriod(start: YearMonth(year: 2015, month: nil), end: nil) | ] unplaced: "),
        ("Work Experience\n• 2019 – 2022 – Electrician – Example Ltd, Leeds\n• 2019 led the move to the new ward\n• 2015 – 2019 – Plumber – Sample Ltd, Hull", false, "[Electrician | Example Ltd | Leeds | ImportedPeriod(start: YearMonth(year: 2019, month: nil), end: Optional(ImportedPeriod.End.date(YearMonth(year: 2022, month: nil)))) | ] [led the move to the new ward | - | - | ImportedPeriod(start: YearMonth(year: 2019, month: nil), end: nil) | ] [Plumber | Sample Ltd | Hull | ImportedPeriod(start: YearMonth(year: 2015, month: nil), end: Optional(ImportedPeriod.End.date(YearMonth(year: 2019, month: nil)))) | ] unplaced: "),
        ("Berufserfahrung\n• 2019 Elektriker\n• 2015 Monteur", false, "[Elektriker | - | - | ImportedPeriod(start: YearMonth(year: 2019, month: nil), end: nil) | ] [Monteur | - | - | ImportedPeriod(start: YearMonth(year: 2015, month: nil), end: nil) | ] unplaced: "),
        ("Esperienza professionale\n• 2019 Infermiera\n• 2015 Operatrice", false, "[Infermiera | - | - | ImportedPeriod(start: YearMonth(year: 2019, month: nil), end: nil) | ] [Operatrice | - | - | ImportedPeriod(start: YearMonth(year: 2015, month: nil), end: nil) | ] unplaced: "),
        ("Education\n• 2021 – Nursing course – Leeds College, Leeds\n• 2012 – Diploma – Leeds High School, Leeds", true, "[Nursing course | Leeds College | Leeds | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [Diploma | Leeds High School | Leeds | ImportedPeriod(start: YearMonth(year: 2012, month: nil), end: nil) | ] unplaced: "),
        ("Education\n• 2021 – Nursing course – Leeds College, Leeds\n• 2000 – hours of placement", true, "[Nursing course | Leeds College | Leeds | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [hours of placement | - | - | ImportedPeriod(start: YearMonth(year: 2000, month: nil), end: nil) | ] unplaced: "),
        ("Education\n• 2021 – Nursing course – Leeds College, Leeds\n• 2000 hours of placement", true, "[Nursing course | Leeds College | Leeds | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [hours of placement | - | - | ImportedPeriod(start: YearMonth(year: 2000, month: nil), end: nil) | ] unplaced: "),
        ("Education\n• 2021 Leeds College\n• 2012 Leeds High School", true, "[- | Leeds College | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | Leeds High School | - | ImportedPeriod(start: YearMonth(year: 2012, month: nil), end: nil) | ] unplaced: "),
        ("Education\n• 2021 – Leeds College\n• 2012 – Leeds High School", true, "[- | Leeds College | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | Leeds High School | - | ImportedPeriod(start: YearMonth(year: 2012, month: nil), end: nil) | ] unplaced: "),
        ("Ausbildung\n• 2021 Hochschule Erfurt\n• 2012 Gymnasium Jena", true, "[- | Hochschule Erfurt | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | Gymnasium Jena | - | ImportedPeriod(start: YearMonth(year: 2012, month: nil), end: nil) | ] unplaced: "),
        ("Ausbildung\n• 2021 – Elektriker – Berufsschule Erfurt, Erfurt\n• 2000 – Stunden Praktikum", true, "[Elektriker | Berufsschule Erfurt | Erfurt | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [Stunden Praktikum | - | - | ImportedPeriod(start: YearMonth(year: 2000, month: nil), end: nil) | ] unplaced: "),
        ("Istruzione\n• 2021 Liceo Esempio\n• 2012 Istituto Esempio", true, "[- | Liceo Esempio | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | Istituto Esempio | - | ImportedPeriod(start: YearMonth(year: 2012, month: nil), end: nil) | ] unplaced: "),
        ("Istruzione\n• 2021 – Corso di infermieristica – Istituto Esempio, Torino\n• 2000 – ore di tirocinio", true, "[Corso di infermieristica | Istituto Esempio | Torino | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [ore di tirocinio | - | - | ImportedPeriod(start: YearMonth(year: 2000, month: nil), end: nil) | ] unplaced: "),
        ("Formación\n• 2021 Colegio Ejemplo\n• 2012 Instituto Ejemplo", true, "[- | Colegio Ejemplo | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | Instituto Ejemplo | - | ImportedPeriod(start: YearMonth(year: 2012, month: nil), end: nil) | ] unplaced: "),
        ("Formación\n• 2021 – Curso de enfermería – Colegio Ejemplo, Madrid\n• 2000 horas de prácticas", true, "[Curso de enfermería | Colegio Ejemplo | Madrid | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [horas de prácticas | - | - | ImportedPeriod(start: YearMonth(year: 2000, month: nil), end: nil) | ] unplaced: "),
        ("Formation\n• 2021 Lycée Exemple\n• 2012 Institut Exemple", true, "[- | Lycée Exemple | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | Institut Exemple | - | ImportedPeriod(start: YearMonth(year: 2012, month: nil), end: nil) | ] unplaced: "),
        ("Formation\n• 2021 – Cours d'infirmerie – Lycée Exemple, Lyon\n• 2000 heures de stage", true, "[Cours d'infirmerie | Lycée Exemple | Lyon | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [heures de stage | - | - | ImportedPeriod(start: YearMonth(year: 2000, month: nil), end: nil) | ] unplaced: "),
        ("Education\n• 2021 – de Montfort University\n• 2012 – van Dijk College", true, "[- | de Montfort University | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | van Dijk College | - | ImportedPeriod(start: YearMonth(year: 2012, month: nil), end: nil) | ] unplaced: "),
        ("Istruzione\n• 2021 – di Roma Università\n• 2012 – de Sanctis Liceo", true, "[- | di Roma Università | - | ImportedPeriod(start: YearMonth(year: 2021, month: nil), end: nil) | ] [- | de Sanctis Liceo | - | ImportedPeriod(start: YearMonth(year: 2012, month: nil), end: nil) | ] unplaced: "),
        ("Education\n• 2010\n• Clinical placements\n• 2012 – Diploma – Leeds High School, Leeds", true, "[- | - | - | ImportedPeriod(start: YearMonth(year: 2010, month: nil), end: nil) | Clinical placements] [Diploma | Leeds High School | Leeds | ImportedPeriod(start: YearMonth(year: 2012, month: nil), end: nil) | ] unplaced: "),
    ]

    private func reading(of text: String, education: Bool) -> String {
        let (document, sections) = pasted(text)
        var findings = Findings(document: document)
        for section in sections where section.kind == .experience || section.kind == .education {
            do {
                try EntryReader.read(section, kind: education ? .education : .experience, into: &findings)
            } catch {
                Issue.record("The entries were not read: \(error)")
            }
        }
        let entries = education
            ? findings.cv.education.map { [$0.degree?.value, $0.school?.value, $0.location?.value, $0.period.map { "\($0.value)".replacingOccurrences(of: "PrestoCVImporting.", with: "") }, $0.details.map(\.value).joined(separator: " / ") as String?] }
            : findings.cv.experience.map { [$0.role?.value, $0.employer?.value, $0.location?.value, $0.period.map { "\($0.value)".replacingOccurrences(of: "PrestoCVImporting.", with: "") }, $0.details.map(\.value).joined(separator: " / ") as String?] }
        let shown = entries.map { "[" + $0.map { $0 ?? "-" }.joined(separator: " | ") + "]" }.joined(separator: " ")
        return shown + " unplaced: " + findings.unplaced.map(\.text).joined(separator: " / ")
    }

    @Test("Every fully bulleted section reads as before", arguments: rows.indices)
    func readsAsBefore(_ index: Int) {
        let row = Self.rows[index]
        #expect(reading(of: row.text, education: row.education) == row.expected, "row \(index)")
    }
}


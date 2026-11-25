import Testing
@testable import PrestoCVImporting

/// Two-digit years and an expected end, read through the whole import. Every value here is invented (the corpus README).
@Suite("Short years and an expected end in an import")
struct ShortYearImportTests {

    private func imported(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
    }

    @Test("Experience: an entry dated with two-digit years keeps its period, and the next entry stays an entry")
    func experience() throws {
        let found = try imported("""
        Berufserfahrung
        09/19 – 08/21    Buchhalter, Muster GmbH, Berlin
        10/21 – heute    Leiter Buchhaltung, Beispiel AG, Hamburg
        """)
        #expect(found.cv.experience.count == 2)
        #expect(found.cv.experience.allSatisfy { $0.period != nil })
    }

    @Test("A percentage or a pay range of two decimals is a detail of its entry, not an entry", arguments: [
        "3.50–4.50% commission on sales", "10.50–12.50 €/hour plus bonus", "10.50–12.50 /h plus bonus",
        "10.50–12.50 /hour plus bonus", "10.50–12.50 per hour plus bonus", "10.50–12.50 pro Stunde plus Bonus",
    ])
    func payIsADetail(line: String) throws {
        let found = try imported("""
        Berufserfahrung
        09/19 – 08/21    Verkäufer, Muster GmbH, Berlin
        \(line)
        """)
        #expect(found.cv.experience.count == 1)
        let entry = try #require(found.cv.experience.first)
        #expect(entry.period?.value.start.year == 2019)
        #expect(entry.period?.value.end == .date(YearMonth(year: 2021, month: 8)))
    }

    @Test("A job title or a currency amount that begins the description does not hide the period", arguments: [
        ("09/19 – 08/21    HR Manager, Muster GmbH, Berlin", 2019),
        ("09/19 – 08/21    EUR 5 million budget responsibility, Muster GmbH, Berlin", 2019),
    ] as [(String, Int)])
    func descriptionWords(line: String, year: Int) throws {
        let found = try imported("""
        Berufserfahrung
        \(line)
        10/21 – heute    Leiter Buchhaltung, Beispiel AG, Hamburg
        """)
        #expect(found.cv.experience.count == 2)
        #expect(found.cv.experience.first?.period?.value.start.year == year)
    }

    /// The role, employer, place and lines of an entry, as one text.
    private func text(of entry: ImportedExperience) -> String {
        ([entry.role?.value, entry.employer?.value, entry.location?.value] + entry.details.map { $0.value })
            .compactMap { $0 }.joined(separator: " | ")
    }

    @Test("Pay with a currency and a gross or net word, or with no unit, stays in its entry in six languages", arguments: [
        "Salary 10.50 – 12.50 EUR gross", "Gehalt 10.50 – 12.50 EUR brutto", "Stipendio 10.50 – 12.50 EUR lordi",
        "Salaire 10.50 – 12.50 EUR brut", "Salario 10.50 – 12.50 EUR bruto", "Salário 10.50 – 12.50 EUR líquido",
        "10.50 – 12.50 EUR net", "10.50 – 12.50 EUR netto", "10.50 – 12.50 EUR netti", "10.50 – 12.50 EUR neto",
        "3.50 – 4.50 EUR gross",
        "10.20 – 12.20k/year", "10.20 – 12.20k, gross", "10.20 – 12.20k/month",
    ])
    func payWithAWordIsADetail(line: String) throws {
        let found = try imported("""
        Berufserfahrung
        09/19 – 08/21    Verkäufer, Muster GmbH, Berlin
        \(line)
        """)
        #expect(found.cv.experience.count == 1)
        let entry = try #require(found.cv.experience.first)
        #expect(entry.period?.value.start == YearMonth(year: 2019, month: 9))
        #expect(entry.period?.value.end == .date(YearMonth(year: 2021, month: 8)))
        #expect(text(of: entry).contains(line.split(separator: " ").last.map(String.init) ?? line))
    }

    @Test("A version range is a detail of its entry: no period, no extra entry", arguments: [
        "Python 3.10 – 3.12", "Django 3.10-3.12", "Version 3.10 – 3.12",
    ])
    func versionRangeIsADetail(line: String) throws {
        let found = try imported("""
        Berufserfahrung
        09/19 – 08/21    Entwickler, Muster GmbH, Berlin
        \(line)
        """)
        #expect(found.cv.experience.count == 1)
        let entry = try #require(found.cv.experience.first)
        #expect(entry.period?.value.start == YearMonth(year: 2019, month: 9))
        #expect(entry.period?.value.end == .date(YearMonth(year: 2021, month: 8)))
        #expect(text(of: entry).contains(line.split(separator: " ").first.map(String.init) ?? line))
        #expect(text(of: entry).contains("3.12"))
    }

    @Test("Two employers whose dates follow the company name stay two entries")
    func employerBeforeShortDatesKeepsBoundaries() throws {
        let found = try imported("""
        Berufserfahrung
        Beispiel AG 10.21 – heute
        Leiter Buchhaltung, Hamburg
        Muster GmbH 9.19 – 8.21
        Verkäufer, Berlin
        """)
        #expect(found.cv.experience.count == 2)
        let first = try #require(found.cv.experience.first)
        let second = try #require(found.cv.experience.last)
        #expect(first.period?.value.start == YearMonth(year: 2021, month: 10))
        #expect(first.period?.value.end == .current)
        #expect(second.period?.value.start == YearMonth(year: 2019, month: 9))
        #expect(second.period?.value.end == .date(YearMonth(year: 2021, month: 8)))
        #expect(text(of: first).contains("Beispiel"))
        #expect(text(of: second).contains("Muster"))
    }

    @Test("An employer with no legal form and a two-year job stays its own entry", arguments: [
        ("Acme 9.10 – 9.12", 2010, 9, 2012, 9), ("Acme 09/10 – 09/12", 2010, 9, 2012, 9),
        ("Acme 09/2010 – 09/2012", 2010, 9, 2012, 9), ("Acme 9.2010 – 9.2012", 2010, 9, 2012, 9),
    ])
    func twoYearJobAtAnUnformedEmployer(line: String, fromYear: Int, fromMonth: Int, toYear: Int, toMonth: Int) throws {
        let found = try imported("""
        Berufserfahrung
        Beispiel AG 10.21 – heute
        Leiter Buchhaltung, Hamburg
        \(line)
        Verkäufer, Berlin
        """)
        #expect(found.cv.experience.count == 2)
        let first = try #require(found.cv.experience.first)
        let second = try #require(found.cv.experience.last)
        #expect(first.period?.value.start == YearMonth(year: 2021, month: 10))
        #expect(first.period?.value.end == .current)
        #expect(second.period?.value.start == YearMonth(year: fromYear, month: fromMonth))
        #expect(second.period?.value.end == .date(YearMonth(year: toYear, month: toMonth)))
        #expect(text(of: first).contains("Beispiel"))
        #expect(text(of: second).contains("Acme"))
    }

    @Test("An employer named like a software product keeps its job boundary and period", arguments: [
        ("Unity 9.10 – 9.12", 2010, 9, 2012, 9), ("Unity 09/10 – 09/12", 2010, 9, 2012, 9),
        ("Unity 09/2010 – 09/2012", 2010, 9, 2012, 9), ("Unity 9.2010 – 9.2012", 2010, 9, 2012, 9),
    ])
    func twoYearJobAtASoftwareNamedEmployer(line: String, fromYear: Int, fromMonth: Int, toYear: Int, toMonth: Int) throws {
        let found = try imported("""
        Berufserfahrung
        Beispiel AG 10.21 – heute
        Leiter Buchhaltung, Hamburg
        \(line)
        Verkäufer, Berlin
        """)
        #expect(found.cv.experience.count == 2)
        let first = try #require(found.cv.experience.first)
        let second = try #require(found.cv.experience.last)
        #expect(first.period?.value.start == YearMonth(year: 2021, month: 10))
        #expect(first.period?.value.end == .current)
        #expect(second.period?.value.start == YearMonth(year: fromYear, month: fromMonth))
        #expect(second.period?.value.end == .date(YearMonth(year: toYear, month: toMonth)))
        #expect(text(of: first).contains("Beispiel"))
        #expect(text(of: second).contains("Unity"))
    }

    @Test("A period followed by a lookalike of a unit keeps both ends and the description", arguments: [
        ("K-12 Teacher", "K-12"), ("k8s platform", "k8s"), ("% of revenue", "of revenue"),
        ("% des Umsatzes", "Umsatzes"), ("% del fatturato", "fatturato"), ("% du chiffre", "chiffre"),
        ("% de ingresos", "ingresos"), ("% da receita", "receita"), ("per diem staff", "diem"),
        ("pro bono counsel", "bono"), ("EUR desk analyst", "desk"), ("/ Berlin", "Berlin"),
    ])
    func lookalikeAfterAPeriod(description: String, kept: String) throws {
        let found = try imported("""
        Berufserfahrung
        09/19 – 08/21    \(description), Muster GmbH
        10/21 – heute    Leiter Buchhaltung, Beispiel AG, Hamburg
        """)
        #expect(found.cv.experience.count == 2)
        let entry = try #require(found.cv.experience.first)
        #expect(entry.period?.value.start == YearMonth(year: 2019, month: 9))
        #expect(entry.period?.value.end == .date(YearMonth(year: 2021, month: 8)))
        #expect(text(of: entry).contains(kept))
    }

    @Test("Education: an expected end belongs to the period, not to the degree")
    func education() throws {
        let found = try imported("""
        Education
        08/2020 – expected 06/2024  Bachelor of Science, University of Leeds
        """)
        let study = try #require(found.cv.education.first)
        #expect(study.period != nil)
        #expect(study.degree?.value == "Bachelor of Science")
    }
}

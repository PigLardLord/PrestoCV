import Testing
@testable import PrestoCVImporting

@Suite("Reading dates and periods")
struct DateReaderTests {

    private func ym(_ year: Int, _ month: Int? = nil) -> YearMonth { YearMonth(year: year, month: month) }

    /// The one period in a text, and the text it was read from.
    private func firstPeriod(_ text: String) -> (String, ImportedPeriod)? {
        guard let match = DateReader.periods(in: text).first else { return nil }
        return (String(text[match.range]), match.period)
    }

    @Test("Ranges in every language's forms, with the text they were read from", arguments: [
        ("03/2019 – heute", "03/2019 – heute", 2019, 3, ImportedPeriod.End.current),
        ("da marzo 2019 a oggi", "da marzo 2019 a oggi", 2019, 3, .current),
        ("2016–2020", "2016–2020", 2016, nil, .date(YearMonth(year: 2020, month: nil))),
        ("Jan 2020 – Present", "Jan 2020 – Present", 2020, 1, .current),
        ("Marzo 2019 – ATTUALE", "Marzo 2019 – ATTUALE", 2019, 3, .current),
        ("ottobre 2015 - febbraio 2019", "ottobre 2015 - febbraio 2019", 2015, 10, .date(YearMonth(year: 2019, month: 2))),
        ("10/2015 – 02/2019", "10/2015 – 02/2019", 2015, 10, .date(YearMonth(year: 2019, month: 2))),
        ("Sept. 2016 – Juli 2020", "Sept. 2016 – Juli 2020", 2016, 9, .date(YearMonth(year: 2020, month: 7))),
        ("enero de 2019 - actualidad", "enero de 2019 - actualidad", 2019, 1, .current),
        ("janv. 2019 – déc. 2021", "janv. 2019 – déc. 2021", 2019, 1, .date(YearMonth(year: 2021, month: 12))),
        ("janeiro de 2019 – presente", "janeiro de 2019 – presente", 2019, 1, .current),
        ("dal 2016 al 2020", "dal 2016 al 2020", 2016, nil, .date(YearMonth(year: 2020, month: nil))),
        ("de 2016 a 2020", "de 2016 a 2020", 2016, nil, .date(YearMonth(year: 2020, month: nil))),
        ("du 03/2017 au 06/2019", "du 03/2017 au 06/2019", 2017, 3, .date(YearMonth(year: 2019, month: 6))),
        ("From March 2019 to June 2021", "From March 2019 to June 2021", 2019, 3, .date(YearMonth(year: 2021, month: 6))),
        ("2019-03 – 2021-11", "2019-03 – 2021-11", 2019, 3, .date(YearMonth(year: 2021, month: 11))),
        ("März 2018 bis heute", "März 2018 bis heute", 2018, 3, .current),
        ("2015 – in corso", "2015 – in corso", 2015, nil, .current),
        ("2017 – à ce jour", "2017 – à ce jour", 2017, nil, .current),
        ("2014 – até hoje", "2014 – até hoje", 2014, nil, .current),
        ("2016/2017", "2016/2017", 2016, nil, .date(YearMonth(year: 2017, month: nil))),
        ("marzo – giugno 2019", "marzo – giugno 2019", 2019, 3, .date(YearMonth(year: 2019, month: 6))),
    ] as [(String, String, Int, Int?, ImportedPeriod.End)])
    func ranges(text: String, quote: String, year: Int, month: Int?, end: ImportedPeriod.End) throws {
        let (read, period) = try #require(firstPeriod(text))
        #expect(read == quote)
        #expect(period == ImportedPeriod(start: ym(year, month), end: end))
    }

    @Test("Since a date means it is current", arguments: ["seit 2019", "seit 03/2019", "dal 2019", "desde 2019", "depuis 2019", "since 2019", "ab 2019", "a partir de 2019"])
    func since(text: String) throws {
        let (read, period) = try #require(firstPeriod(text))
        #expect(read == text)
        #expect(period.start.year == 2019)
        #expect(period.end == .current)
    }

    @Test("A single date: a year, a month and year, or a full date read to its month")
    func singleDates() throws {
        #expect(try #require(firstPeriod("Laurea, 2016")).1 == ImportedPeriod(start: ym(2016), end: nil))
        #expect(try #require(firstPeriod("Juni 2018")).1 == ImportedPeriod(start: ym(2018, 6), end: nil))
        #expect(try #require(firstPeriod("Berlin, 12.03.2026")).1 == ImportedPeriod(start: ym(2026, 3), end: nil))
        #expect(try #require(firstPeriod("Berlin, 12.03.2026")).0 == "12.03.2026")
    }

    @Test("A range whose end is missing stays open, with its end unstated")
    func openEnd() throws {
        let (read, period) = try #require(firstPeriod("2019 –"))
        #expect(read == "2019 –")
        #expect(period == ImportedPeriod(start: ym(2019), end: .unstated))
    }

    @Test("Numbers that are no dates are not read as dates")
    func notDates() {
        #expect(DateReader.periods(in: "+39 333 000 0000").isEmpty)
        #expect(DateReader.periods(in: "20121 Milano").isEmpty)
        #expect(DateReader.periods(in: "Team of 12 people, 3500 patients").isEmpty)
        #expect(DateReader.periods(in: "I may join in March").isEmpty)
        #expect(DateReader.periods(in: "8001 Zürich").isEmpty)
    }

    @Test("Several periods in a text are read in order")
    func severalPeriods() {
        let periods = DateReader.periods(in: "2012 – 2016 Bachelor, 2016 – 2018 Master")
        #expect(periods.map(\.period.start.year) == [2012, 2016])
    }

    @Test("A two-digit year is read inside a range, with the century rule", arguments: [
        ("09/19 – 08/21", 2019, 9, ImportedPeriod.End.date(YearMonth(year: 2021, month: 8))),
        ("08/78-06/82", 1978, 8, .date(YearMonth(year: 1982, month: 6))),
        ("10/21 – heute", 2021, 10, .current),
        ("10.21 – 03.23", 2021, 10, .date(YearMonth(year: 2023, month: 3))),
        ("09/19 – 08/2021", 2019, 9, .date(YearMonth(year: 2021, month: 8))),
        ("03/2019 – 08/21", 2019, 3, .date(YearMonth(year: 2021, month: 8))),
        ("11/98 – 02/03", 1998, 11, .date(YearMonth(year: 2003, month: 2))),
    ] as [(String, Int, Int, ImportedPeriod.End)])
    func shortYears(text: String, year: Int, month: Int, end: ImportedPeriod.End) throws {
        let (read, period) = try #require(firstPeriod(text))
        #expect(read == text)
        #expect(period == ImportedPeriod(start: ym(year, month), end: end))
    }

    @Test("A two-digit year alone, or in a full date, is no date", arguments: ["12/96", "Rev 03.21 of the plan", "12.03.26", "Room 5/21"])
    func shortYearAlone(text: String) {
        #expect(DateReader.periods(in: text).isEmpty)
    }

    @Test("A two-digit range beside a percentage, a price or a rate is a number range, not dates", arguments: [
        "3.50–4.50% commission", "03.50–04.50% commission", "10.50–12.50 €/hour", "10.50–12.50 EUR per hour",
        "10.50-12.50/h", "€10.50–12.50", "$ 10.50 – 12.50", "10.50 – 12.50 CHF", "10.50 – 12.50k",
        "10.50–12.50 /h", "10.50–12.50 / h", "10.50–12.50 /hour", "10.50 – 12.50 /Std.", "10.50 – 12.50 / Stunde",
        "10.50–12.50 €/h", "10.50–12.50 € / h", "10.50–12.50 per hour", "10.50–12.50 pro Stunde",
        "10.50–12.50 all'ora", "10.50–12.50 l'heure", "10.50–12.50 por hora", "10.50–12.50 EUR/h", "10.50–12.50 USD per hour",
        "10.50–12.50 % margin", "10.50–12.50 k",
    ])
    func shortRangeBesideAUnit(text: String) {
        #expect(DateReader.periods(in: text).isEmpty)
    }

    @Test("A range of single-digit dotted months is a period, both ends and a current end", arguments: [
        ("9.19 – 8.21", 2019, 9, ImportedPeriod.End.date(YearMonth(year: 2021, month: 8))),
        ("09.19 – 8.21", 2019, 9, .date(YearMonth(year: 2021, month: 8))),
        ("9.19 – heute", 2019, 9, .current),
        ("9.19 – 10.21", 2019, 9, .date(YearMonth(year: 2021, month: 10))),
    ] as [(String, Int, Int, ImportedPeriod.End)])
    func singleDigitDottedMonths(text: String, year: Int, month: Int, end: ImportedPeriod.End) throws {
        let (read, period) = try #require(firstPeriod(text))
        #expect(read == text)
        #expect(period == ImportedPeriod(start: ym(year, month), end: end))
    }

    @Test("A word after a range that is no unit of its own leaves the range a period", arguments: [
        "09/19 – 08/21 HR Manager", "09/19 – 08/21 EUR 5 million budget responsibility",
        "09/19 – 08/21 Hour of Code teacher", "09/19 – 08/21 Euro zone analyst", "09/19 – 08/21 € 5 million budget",
        "09/19 – heute HR Manager", "09/19 – 08/21 hr business partner",
    ])
    func wordsAfterARange(text: String) throws {
        let (_, period) = try #require(firstPeriod(text))
        #expect(period.start == ym(2019, 9))
    }

    @Test("A two-digit year follows the bounds of a four-digit year: the 1930s are read in neither form", arguments: [
        ("08/30 – 06/39", "08/1930 – 06/1939"), ("08/35 – heute", "08/1935 – heute"), ("08/30 – 06/38", "08/1930 – 06/1938"),
    ])
    func shortAndLongFormAgree(short: String, long: String) {
        #expect(DateReader.periods(in: short).isEmpty == DateReader.periods(in: long).isEmpty)
        #expect(DateReader.periods(in: long).isEmpty)
    }

    @Test("The pivot: 29 is 2029, 40 is 1940, and the years 30 to 39 stay outside the reader's bounds", arguments: [
        ("05/29 – heute", 2029, 5), ("05/40 – 06/41", 1940, 5), ("05/99 – 06/01", 1999, 5),
    ] as [(String, Int, Int)])
    func pivotBoundaries(text: String, year: Int, month: Int) throws {
        let (_, period) = try #require(firstPeriod(text))
        #expect(period.start == ym(year, month))
    }

    @Test("A two-digit range of the 1930s is no period", arguments: ["08/30 – 06/39", "08/35 – heute", "08/39 – 06/40"])
    func nineteenThirties(text: String) {
        #expect(DateReader.periods(in: text).isEmpty)
    }

    @Test("An expected end is the end of the range, and its word stays in the span", arguments: [
        ("08/2020 – expected 06/2024", 2020, 8, 2024, 6),
        ("08/2020 – voraussichtlich 06/2024", 2020, 8, 2024, 6),
        ("08/2020 – previsto 06/2024", 2020, 8, 2024, 6),
        ("08/2020 – prevista 06/2024", 2020, 8, 2024, 6),
        ("08/2020 – prévu 06/2024", 2020, 8, 2024, 6),
        ("08/2020 – esperado 06/2024", 2020, 8, 2024, 6),
        ("2020 – Expected 2024", 2020, 0, 2024, 0),
    ] as [(String, Int, Int, Int, Int)])
    func expectedEnd(text: String, startYear: Int, startMonth: Int, endYear: Int, endMonth: Int) throws {
        let (read, period) = try #require(firstPeriod(text))
        #expect(read == text)
        let end = YearMonth(year: endYear, month: endMonth == 0 ? nil : endMonth)
        #expect(period == ImportedPeriod(start: ym(startYear, startMonth == 0 ? nil : startMonth), end: .date(end)))
    }

    @Test("Pay beside a currency, with an ordinary word after it or none, is no period", arguments: [
        "3.50 – 4.50 EUR gross", "10.50 – 12.50 EUR gross", "10.50 – 12.50 EUR net", "10.50 – 12.50 EUR brutto",
        "10.50 – 12.50 EUR netto", "10.50 – 12.50 EUR lordi", "10.50 – 12.50 EUR netti", "10.50 – 12.50 EUR brut",
        "10.50 – 12.50 EUR bruto", "10.50 – 12.50 EUR neto", "10.50 – 12.50 EUR líquido", "10.50 – 12.50 € brut",
        "10.50 – 12.50 CHF netto", "10.50 – 12.50 USD gross",
    ])
    func payWithACurrencyAndAWord(text: String) {
        #expect(DateReader.periods(in: text).isEmpty)
    }

    @Test("A dotted range whose years fall in 1940-1969 is no period, with a unit or none", arguments: [
        "3.50 – 4.50", "10.50 – 12.50", "10.50-12.50", "9.45 – 12.60",
    ])
    func dottedRangeOfThePricesYears(text: String) {
        #expect(DateReader.periods(in: text).isEmpty)
    }

    @Test("A dotted range with a k before punctuation or a rate is pay, no period", arguments: [
        "10.20 – 12.20k/year", "10.20 – 12.20k, gross", "10.20 – 12.20k/month", "10.20 – 12.20k)",
        "10.20 – 12.20 k/year", "10.20 – 12.20k.",
    ])
    func kBeforePunctuationIsAUnit(text: String) {
        #expect(DateReader.periods(in: text).isEmpty)
    }

    @Test("A slash range is a period whatever word follows, the words of a unit included", arguments: [
        "09/19 – 08/21 K-12 Teacher", "09/19 – 08/21 k8s platform", "09/19 – 08/21 % of revenue",
        "09/19 – 08/21 % des Umsatzes", "09/19 – 08/21 % del fatturato", "09/19 – 08/21 % du chiffre d'affaires",
        "09/19 – 08/21 % de ingresos", "09/19 – 08/21 % da receita", "09/19 – 08/21 per diem staff",
        "09/19 – 08/21 pro bono counsel", "09/19 – 08/21 EUR desk analyst", "09/19 – 08/21 / Berlin",
        "09/19 – 08/21 EUR brut", "09/19 – 08/21 k",
    ])
    func slashRangeBeforeALookalike(text: String) throws {
        let (read, period) = try #require(firstPeriod(text))
        #expect(period == ImportedPeriod(start: ym(2019, 9), end: .date(ym(2021, 8))))
        #expect(read.hasPrefix("09/19 – 08/21"))
    }

    @Test("A dotted range is a period before a word that is no unit, and a k that begins a word is no unit", arguments: [
        "09.19 – 08.21 K-12 Teacher", "09.19 – 08.21 k8s platform", "09.19 – 08.21 per diem staff",
        "09.19 – 08.21 pro bono counsel", "09.19 – 08.21 / Berlin", "09.19 – 08.21 EUR 5 million budget",
    ])
    func dottedRangeBeforeALookalike(text: String) throws {
        let (_, period) = try #require(firstPeriod(text))
        #expect(period == ImportedPeriod(start: ym(2019, 9), end: .date(ym(2021, 8))))
    }
}

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
}

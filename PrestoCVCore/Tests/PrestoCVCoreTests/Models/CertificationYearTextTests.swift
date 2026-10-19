import Testing
@testable import PrestoCVCore

@Suite("Certification year text - what the year field shows and what typing in it stores")
struct CertificationYearTextTests {

    @Test("A certification without a year shows an empty field, so its placeholder is read instead of 0")
    func noYearShowsAnEmptyField() {
        #expect(Certification().yearText == "")
    }

    @Test("A certification with a year shows it")
    func yearIsShown() {
        #expect(Certification(year: 2020).yearText == "2020")
    }

    @Test("Typing a year into the empty field stores it as typed, not after a 0")
    func typingIntoTheEmptyFieldStoresTheYear() {
        var certification = Certification()

        certification.yearText = certification.yearText + "2020"

        #expect(certification.year == 2020)
        #expect(certification.yearText == "2020")
    }

    @Test("Clearing the field removes the year")
    func clearingTheFieldRemovesTheYear() {
        var certification = Certification(year: 2020)

        certification.yearText = ""

        #expect(certification.year == 0)
        #expect(certification.yearText == "")
    }

    @Test("Only the digits of what is typed or pasted count, and no more than the four of a year")
    func onlyFourDigitsCount() {
        var certification = Certification()

        certification.yearText = " 2021a"
        #expect(certification.year == 2021)

        certification.yearText = "202199999999999999999999"
        #expect(certification.year == 2021, "A long paste must not turn into no year at all")
    }
}

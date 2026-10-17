import Testing
@testable import PrestoCV
@testable import PrestoCVCore

@Suite("Phone number hint - when the phone field warns that it holds no number")
struct PhoneNumberHintTests {

    @Test("A phone without a single digit gets the hint", arguments: ["abc", "call me", " - "])
    func phoneWithoutDigitsGetsTheHint(phone: String) {
        #expect(PersonalInfo(phone: phone).phoneLacksDigits)
    }

    @Test("A phone with digits, written in any way, gets no hint", arguments: ["+39 06 1234567", "(555) 010-0199", "tel. 0612"])
    func phoneWithDigitsGetsNoHint(phone: String) {
        #expect(!PersonalInfo(phone: phone).phoneLacksDigits)
    }

    @Test("An empty phone gets no hint: the field is optional", arguments: ["", "   "])
    func emptyPhoneGetsNoHint(phone: String) {
        #expect(!PersonalInfo(phone: phone).phoneLacksDigits)
    }
}

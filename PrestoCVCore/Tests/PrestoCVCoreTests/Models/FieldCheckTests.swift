import Testing
@testable import PrestoCVCore

@Suite("FieldCheck Tests - what the editor says about an e-mail address, a phone number and a web address")
struct FieldCheckTests {

    // MARK: - E-mail address

    @Test("An address with an at sign and a dot reads as one", arguments: ["ada@example.com", " ada@example.com\n", "a@b.c"])
    func emailWithAtSignAndDot(email: String) {
        #expect(FieldCheck.email(email) == .plausible)
    }

    @Test("An address without an at sign or without a dot is not one", arguments: ["ada", "ada@example", "ada.example.com"])
    func emailWithoutAtSignOrDot(email: String) {
        #expect(FieldCheck.email(email) == .implausible)
    }

    @Test("An empty address says nothing", arguments: ["", "   ", "\n"])
    func emptyEmail(email: String) {
        #expect(FieldCheck.email(email) == .empty)
    }

    // MARK: - Phone number

    @Test("A phone without a single digit cannot be called", arguments: ["abc", "call me", " - "])
    func phoneWithoutDigits(phone: String) {
        #expect(FieldCheck.phoneNumber(phone) == .implausible)
    }

    @Test("A phone with digits, written in any way, reads as one", arguments: ["+39 06 1234567", "(555) 010-0199", "tel. 0612"])
    func phoneWithDigits(phone: String) {
        #expect(FieldCheck.phoneNumber(phone) == .plausible)
    }

    @Test("An empty phone says nothing: the field is optional", arguments: ["", "   "])
    func emptyPhone(phone: String) {
        #expect(FieldCheck.phoneNumber(phone) == .empty)
    }

    // MARK: - Web address

    @Test("A web address starts with http, in any case", arguments: ["https://ada.dev", "http://ada.dev", " HTTPS://ADA.DEV "])
    func webAddressWithScheme(address: String) {
        #expect(FieldCheck.webAddress(address) == .plausible)
    }

    @Test("A web address without http is doubtful", arguments: ["ada.dev", "www.ada.dev", "ftp://ada.dev"])
    func webAddressWithoutScheme(address: String) {
        #expect(FieldCheck.webAddress(address) == .implausible)
    }

    @Test("An empty web address says nothing", arguments: ["", "  "])
    func emptyWebAddress(address: String) {
        #expect(FieldCheck.webAddress(address) == .empty)
    }
}

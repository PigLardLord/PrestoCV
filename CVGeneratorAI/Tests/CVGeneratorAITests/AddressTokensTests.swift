import Testing
import Foundation
@testable import CVGeneratorAI

/// An address is read as it looks to the reader: a full stop or an at sign of another script is the dot and the at sign of one,
/// and the text around the addresses is returned as it was written (ADR 0031).
@Suite("Address tokens: lookalike dots and at signs")
struct AddressTokensTests {
    @Test("A domain written with a full stop of another script is a link", arguments: [
        "\u{3002}", "\u{FF0E}", "\u{FF61}", "\u{2024}", "\u{FE52}",
    ])
    func lookalikeDotOfALink(dot: String) {
        let tokens = AddressTokens("Visit market\(dot)io now")

        #expect(tokens.links == ["market.io"], "\(dot.unicodeScalars.map(\.value))")
        #expect(tokens.emails.isEmpty)
        #expect(!tokens.hasAmbiguousAddress)
    }

    @Test("An email written with an at sign of another script, or a dot of another script, is an email", arguments: [
        "anna\u{FF20}example.com", "anna\u{FE6B}example.com", "anna@example\u{3002}com", "anna@example\u{FF0E}com",
    ])
    func lookalikeSignsOfAnEmail(address: String) {
        let tokens = AddressTokens("Write to \(address) today")

        #expect(tokens.emails == ["anna@example.com"], "\(address.unicodeScalars.map(\.value))")
        #expect(tokens.links.isEmpty)
        #expect(!tokens.hasAmbiguousAddress)
    }

    @Test("The text left once the addresses are blanked is built from the characters as written, one for one")
    func remainderKeepsTheWrittenCharacters() {
        let text = "Cost 3\u{3002}5 euro, see market\u{3002}io now"
        let tokens = AddressTokens(text)

        #expect(tokens.links == ["market.io"])
        #expect(tokens.remainder == "Cost 3\u{3002}5 euro, see " + String(repeating: " ", count: 9) + " now")
        #expect(tokens.remainder.count == text.count)
    }

    @Test("A text in a script with its own full stop holds no address")
    func noAddressInAnotherScript() {
        let text = "\u{4F60}\u{597D}\u{3002}\u{4E16}\u{754C}\u{FF0E}"
        let tokens = AddressTokens(text)

        #expect(tokens.emails.isEmpty && tokens.links.isEmpty && !tokens.hasAmbiguousAddress)
        #expect(tokens.remainder == text)
    }

    @Test("An address written with a plain dot and a plain at sign is read as before")
    func plainAddresses() {
        let tokens = AddressTokens("Write to anna@example.com or see market.io.")

        #expect(tokens.emails == ["anna@example.com"])
        #expect(tokens.links == ["market.io"])
    }
}

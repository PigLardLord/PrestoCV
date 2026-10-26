import Testing
import SwiftUI
@testable import PrestoCV

@Suite("Color.fromHex Tests - the colours of the palettes the export sheet shows")
struct ColorHexTests {

    @Test("A six-digit code is read as red, green and blue", arguments: ["#FF8000", "FF8000", "#ff8000"])
    func sixDigits(hex: String) {
        #expect(Color.fromHex(hex) == Color(red: 1, green: 128.0 / 255, blue: 0))
    }

    @Test("A three-digit code doubles each digit")
    func threeDigits() {
        #expect(Color.fromHex("#F80") == Color.fromHex("#FF8800"))
    }

    @Test("A code that cannot be read shows the secondary background", arguments: ["", "#12345", "#GGGGGG", "red"])
    func unreadableCode(hex: String) {
        #expect(Color.fromHex(hex) == DesignTokens.Colors.backgroundSecondary)
    }
}

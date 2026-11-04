import Testing
import Foundation
import SwiftUI
@testable import PrestoCV

/// A control drawn in the accent shows its press without losing contrast. The rule that every button, navigation
/// link, menu or link in the accent goes through a style of the design system reads the app's sources, so it is in
/// Tools/SourceChecks, which runs where the repository is; this suite checks the colours it leads to.
@Suite("Buttons in the accent - an opaque press through the design system")
@MainActor
struct ButtonPressTests {

    // MARK: - The add button

    /// The add button draws its title with AccentTextButtonStyle: Tools/SourceChecks reads that from its source.
    @Test("The title of an add button, drawn with AccentTextButtonStyle, is readable at rest and pressed on a form row, a card and a screen",
          arguments: [false, true])
    func addButtonIsReadable(isPressed: Bool) {
        let title = AccentTextButtonStyle.foregroundColor(isPressed: isPressed)
        for appearance in AccentColorTests.Appearance.allCases {
            for background in AccentColorTests.TextBackground.allCases {
                let pair = AccentColorTests.ContrastPair(name: "", foreground: title, background: background.color)
                let ratio = appearance.contrast(of: pair)

                #expect(ratio >= 4.5, "an add button, pressed \(isPressed), on \(background.name) in the \(appearance.rawValue) appearance reaches \(ratio):1")
            }
        }
    }
}

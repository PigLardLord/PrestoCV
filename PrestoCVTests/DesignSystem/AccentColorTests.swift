import Testing
import Foundation
import SwiftUI
import UIKit
@testable import PrestoCV

/// The accent of the app is the brand's Mint from the asset catalog, and what is drawn in it or on it stays readable.
@Suite("Accent colour - the Mint of the brand, readable in every appearance")
@MainActor
struct AccentColorTests {

    // MARK: - The accent

    @Test("The accent token is the AccentColor of the asset catalog", arguments: Appearance.allCases)
    func accentIsTheAssetAccent(appearance: Appearance) throws {
        let asset = try #require(UIColor(named: "AccentColor"))

        #expect(appearance.hex(of: DesignTokens.Colors.accent) == appearance.hex(of: asset))
    }

    @Test("The primary button is filled with the accent", arguments: Appearance.allCases)
    func primaryButtonIsFilledWithTheAccent(appearance: Appearance) {
        #expect(appearance.hex(of: DesignTokens.Colors.primaryButtonBackground) == appearance.hex(of: DesignTokens.Colors.accent))
    }

    @Test("A swipe action is filled with the accent of the light appearance, whatever the appearance", arguments: Appearance.allCases)
    func swipeActionIsFilledWithTheLightAccent(appearance: Appearance) throws {
        let asset = try #require(UIColor(named: "AccentColor"))

        #expect(appearance.hex(of: DesignTokens.Colors.swipeActionTint) == Appearance.light.hex(of: asset))
    }

    // MARK: - Contrast

    /// A colour drawn on another, named as in the table of `docs/design/app-icon.md`. A translucent colour is drawn over
    /// what lies beneath it, and the whole control at its opacity over the screen.
    struct ContrastPair: CustomTestStringConvertible, Sendable {
        let name: String
        let foreground: Color
        let background: Color
        /// The opacity of the whole control
        var opacity: Double = 1
        var testDescription: String { name }
    }

    /// A pair to check, named for the report. Its colours are made when the test runs, on the main actor, so that the
    /// cases can be listed as the arguments of a test from outside it.
    struct ContrastCase: CustomTestStringConvertible, Sendable {
        let name: String
        let make: @MainActor @Sendable (_ name: String) -> ContrastPair
        @MainActor var pair: ContrastPair { make(name) }
        var testDescription: String { name }
    }

    /// The label and the fill of a primary button, at rest or pressed.
    static func primaryButton(_ name: String, isPressed: Bool) -> ContrastPair {
        let look = PrimaryButton.Look(isDisabled: false, isPressed: isPressed)
        return ContrastPair(name: name, foreground: look.foreground, background: look.background, opacity: look.opacity)
    }

    /// The labels the app draws on a fill of the accent.
    nonisolated static let filledAccents = [
        ContrastCase(name: "Label of a primary button (`OnAccentColor` on `AccentColor`)") { primaryButton($0, isPressed: false) },
        ContrastCase(name: "Label of a pressed primary button (`OnAccentColor` on `AccentPressedColor`)") {
            primaryButton($0, isPressed: true)
        },
        // The system draws the symbol of a swipe action in white, whatever its tint
        ContrastCase(name: "Symbol of a swipe action (white on `SwipeActionColor`)") {
            ContrastPair(name: $0, foreground: .white, background: DesignTokens.Colors.swipeActionTint)
        },
    ]

    /// The backgrounds the app draws text in the accent on: the screens, the cards, and the rows of a list or a form.
    enum TextBackground: CaseIterable, Sendable {
        case screen, card, row

        var name: String {
            switch self {
            case .screen: "a screen (`systemBackground`)"
            case .card: "a card (`tertiarySystemBackground`)"
            case .row: "a row of a list or form (`secondarySystemGroupedBackground`)"
            }
        }

        @MainActor var color: Color {
            switch self {
            case .screen: DesignTokens.Colors.background
            case .card: DesignTokens.Colors.backgroundTertiary
            case .row: Color(UIColor.secondarySystemGroupedBackground)
            }
        }
    }

    nonisolated static let accentTexts = TextBackground.allCases.map { background in
        ContrastCase(name: "Accent text on \(background.name)") {
            ContrastPair(name: $0, foreground: DesignTokens.Colors.accent, background: background.color)
        }
    } + [
        ContrastCase(name: "Title of a pressed secondary button on a screen (`AccentPressedColor` on `systemBackground`)") {
            ContrastPair(
                name: $0,
                foreground: AccentTextButtonStyle.foregroundColor(isPressed: true),
                background: DesignTokens.Colors.background
            )
        },
        ContrastCase(name: "Title of a pressed add button on a form row (`AccentPressedColor` on `secondarySystemGroupedBackground`)") {
            ContrastPair(
                name: $0,
                foreground: AccentTextButtonStyle.foregroundColor(isPressed: true),
                background: Color(UIColor.secondarySystemGroupedBackground)
            )
        },
    ]

    @Test("A label on a fill of the accent reaches 4.5:1, also while the button is pressed", arguments: filledAccents, Appearance.allCases)
    func labelOnTheAccentIsReadable(accent: ContrastCase, appearance: Appearance) {
        let pair = accent.pair
        let ratio = appearance.contrast(of: pair)

        #expect(ratio >= 4.5, "\(pair.name) in the \(appearance.rawValue) appearance reaches \(ratio):1")
    }

    @Test("Text in the accent reaches 4.5:1 on the backgrounds it is drawn on", arguments: accentTexts, Appearance.allCases)
    func textInTheAccentIsReadable(text: ContrastCase, appearance: Appearance) {
        let pair = text.pair
        let ratio = appearance.contrast(of: pair)

        #expect(ratio >= 4.5, "\(pair.name) in the \(appearance.rawValue) appearance reaches \(ratio):1")
    }

    @Test("A button drawn as text in the accent, such as a secondary or an add button, reaches 4.5:1 at rest and pressed on every background",
          arguments: [false, true])
    func accentTextButtonTitleIsReadable(isPressed: Bool) {
        let title = AccentTextButtonStyle.foregroundColor(isPressed: isPressed)

        for appearance in Appearance.allCases {
            for background in TextBackground.allCases {
                let ratio = appearance.contrast(of: ContrastPair(name: "", foreground: title, background: background.color))

                #expect(ratio >= 4.5, "the title, pressed \(isPressed), on \(background.name) in the \(appearance.rawValue) appearance reaches \(ratio):1")
            }
        }
    }

    @Test("A press shows in the colour of the button, which stays opaque, not by fading it", arguments: Appearance.allCases)
    func pressShowsInTheColour(appearance: Appearance) {
        let resting = PrimaryButton.Look(isDisabled: false, isPressed: false)
        let pressed = PrimaryButton.Look(isDisabled: false, isPressed: true)
        let restingTitle = AccentTextButtonStyle.foregroundColor(isPressed: false)
        let pressedTitle = AccentTextButtonStyle.foregroundColor(isPressed: true)

        #expect(appearance.hex(of: pressed.background) != appearance.hex(of: resting.background))
        #expect(appearance.alpha(of: pressed.background) == 1 && pressed.opacity == 1)
        #expect(appearance.hex(of: pressedTitle) != appearance.hex(of: restingTitle))
        #expect(appearance.alpha(of: pressedTitle) == 1)
    }

    // MARK: - Buttons

    /// A button of the design system and the colour its title is meant to have.
    enum DesignSystemButton: String, CaseIterable, CustomTestStringConvertible, Sendable {
        case primary, secondary

        var testDescription: String { "the \(rawValue) button" }

        @MainActor var view: AnyView {
            switch self {
            case .primary: AnyView(PrimaryButton(title: "Preview & export") {}.frame(width: 320))
            case .secondary: AnyView(SecondaryButton.text(title: "Start from an example") {})
            }
        }

        @MainActor var titleColour: Color {
            switch self {
            case .primary: DesignTokens.Colors.primaryButtonForeground
            case .secondary: AccentTextButtonStyle.foregroundColor(isPressed: false)
            }
        }
    }

    @Test("A button draws its title in its own colour, not in the colour of body text",
          arguments: DesignSystemButton.allCases, [ColorScheme.light, .dark])
    func buttonTitleIsInTheButtonsColour(button: DesignSystemButton, scheme: ColorScheme) throws {
        let title = try RenderedPixels(of: button.view, in: scheme)
        let titleColour = try #require(RenderedPixels(of: Rectangle().fill(button.titleColour), in: scheme).firstOpaqueColour)
        let bodyText = try #require(RenderedPixels(of: Rectangle().fill(DesignTokens.Colors.primary), in: scheme).firstOpaqueColour)

        #expect(title.count(of: titleColour) > 10, "\(button.rawValue) in \(scheme): no pixel of the title is in the button's colour")
        #expect(title.count(of: bodyText) == 0, "\(button.rawValue) in \(scheme): the title is in the colour of body text")
    }

    @Test("A disabled primary button draws its title in the disabled colour, not in the label colour of the accent",
          arguments: Appearance.allCases)
    func disabledPrimaryButtonTitleIsInTheDisabledColour(appearance: Appearance) {
        let look = PrimaryButton.Look(isDisabled: true, isPressed: false)

        #expect(appearance.hex(of: look.foreground) == appearance.hex(of: DesignTokens.Colors.disabledButtonForeground))
    }

    // MARK: - Documentation

    /// The colours of the accent, named as in the table of `docs/design/app-icon.md`.
    static let documentedColours: [(name: String, color: Color)] = [
        ("`AccentColor` (`DesignTokens.Colors.accent`)", DesignTokens.Colors.accent),
        ("`OnAccentColor` (`DesignTokens.Colors.onAccent`)", DesignTokens.Colors.onAccent),
        ("`SwipeActionColor` (`DesignTokens.Colors.swipeActionTint`)", DesignTokens.Colors.swipeActionTint),
        ("`AccentPressedColor` (`DesignTokens.Colors.accentPressed`)", DesignTokens.Colors.accentPressed),
    ]

    @Test("The accent section of docs/design/app-icon.md shows the colours and the contrasts the app has")
    func documentationShowsTheColoursAndContrasts() throws {
        let document = try TestBundle.text(of: "app-icon", withExtension: "md")
        let colourRows = Self.documentedColours.map { colour in
            Self.row(colour.name, Appearance.allCases.map { "`\($0.hex(of: colour.color))`" })
        }
        let contrastRows = (Self.filledAccents + Self.accentTexts).map { contrastCase in
            let pair = contrastCase.pair
            return Self.row(pair.name, Appearance.allCases.map { String(format: "%.2f:1", $0.contrast(of: pair)) })
        }

        for row in colourRows + contrastRows {
            #expect(document.contains(row), "docs/design/app-icon.md lacks the row\n\(row)")
        }
    }

    /// A row of a Markdown table whose columns are the appearances, in the order of `Appearance.allCases`.
    private static func row(_ name: String, _ cells: [String]) -> String {
        "| \(name) | \(cells.joined(separator: " | ")) |"
    }

    // MARK: - Appearances

    /// The appearances a colour is checked in: light and dark, each with and without Increase Contrast.
    enum Appearance: String, CaseIterable, CustomTestStringConvertible, Sendable {
        case light, dark, lightIncreasedContrast, darkIncreasedContrast

        var testDescription: String { rawValue }

        private var traits: UITraitCollection {
            UITraitCollection { traits in
                traits.userInterfaceStyle = (self == .light || self == .lightIncreasedContrast) ? .light : .dark
                traits.accessibilityContrast = (self == .light || self == .dark) ? .normal : .high
            }
        }

        func resolve(_ color: UIColor) -> UIColor {
            color.resolvedColor(with: traits)
        }

        func resolve(_ color: Color) -> UIColor {
            resolve(UIColor(color))
        }

        /// The colour as `#RRGGBB` in this appearance, to compare two colours.
        func hex(of color: UIColor) -> String {
            let (red, green, blue, _) = WCAG.channels(of: resolve(color))
            return String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
        }

        func hex(of color: Color) -> String {
            hex(of: UIColor(color))
        }

        func alpha(of color: Color) -> Double {
            WCAG.channels(of: resolve(color)).alpha
        }

        /// The contrast of the pair as the screen shows it: the background over the screen, the foreground over the
        /// background, and the whole at the pair's opacity over the screen.
        func contrast(of pair: ContrastPair) -> Double {
            let screen = resolve(DesignTokens.Colors.background)
            let fill = WCAG.composite(resolve(pair.background), over: screen)
            let label = WCAG.composite(resolve(pair.foreground), over: fill)
            return WCAG.contrast(
                WCAG.blend(label, over: screen, opacity: pair.opacity),
                WCAG.blend(fill, over: screen, opacity: pair.opacity)
            )
        }
    }
}

// MARK: - Helpers

/// Contrast as the Web Content Accessibility Guidelines (WCAG 2) define it.
private enum WCAG {
    static func channels(of color: UIColor) -> (red: Double, green: Double, blue: Double, alpha: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }

    /// A colour drawn over another by its own alpha, as an opaque colour.
    static func composite(_ top: UIColor, over bottom: UIColor) -> UIColor {
        blend(top, over: bottom, opacity: channels(of: top).alpha)
    }

    /// A colour drawn at an opacity over another, as an opaque colour.
    static func blend(_ top: UIColor, over bottom: UIColor, opacity: Double) -> UIColor {
        let (upper, lower) = (channels(of: top), channels(of: bottom))
        func mix(_ one: Double, _ other: Double) -> CGFloat { CGFloat(one * opacity + other * (1 - opacity)) }
        return UIColor(red: mix(upper.red, lower.red), green: mix(upper.green, lower.green), blue: mix(upper.blue, lower.blue), alpha: 1)
    }

    /// The relative luminance of an opaque sRGB colour.
    static func luminance(of color: UIColor) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let (red, green, blue, _) = channels(of: color)
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    static func contrast(_ first: UIColor, _ second: UIColor) -> Double {
        let (one, other) = (luminance(of: first), luminance(of: second))
        return (max(one, other) + 0.05) / (min(one, other) + 0.05)
    }
}

/// The pixels of a view drawn off screen, as sRGB bytes.
@MainActor
private struct RenderedPixels {
    private let rgba: [UInt8]

    init(of view: some View, in scheme: ColorScheme) throws {
        let renderer = ImageRenderer(content: view.frame(minWidth: 8, minHeight: 8).environment(\.colorScheme, scheme))
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = rgba.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                          bytesPerRow: image.width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        try #require(drawn)
        self.rgba = rgba
    }

    private var opaquePixels: [ArraySlice<UInt8>] {
        stride(from: 0, to: rgba.count, by: 4).map { rgba[$0..<$0 + 4] }.filter { $0.last == 255 }
    }

    /// The colour of the first opaque pixel, which for a filled shape is its colour.
    var firstOpaqueColour: [UInt8]? {
        opaquePixels.first.map { Array($0.prefix(3)) }
    }

    /// How many opaque pixels have this colour, give or take the rounding of the renderer.
    func count(of colour: [UInt8]) -> Int {
        opaquePixels.filter { pixel in zip(pixel.prefix(3), colour).allSatisfy { abs(Int($0) - Int($1)) <= 2 } }.count
    }
}

/// The documents the tests compare the app with, which the test bundle carries: the tests run where the repository is not.
private enum TestBundle {
    private final class Marker {}

    static func text(of name: String, withExtension type: String) throws -> String {
        let url = try #require(Bundle(for: Marker.self).url(forResource: name, withExtension: type), "The test bundle has no \(name).\(type)")
        return try String(contentsOf: url, encoding: .utf8)
    }
}

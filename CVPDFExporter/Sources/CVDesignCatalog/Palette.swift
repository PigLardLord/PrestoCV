import Foundation

/// A palette colour: only `#RRGGBB` can exist, so it is safe to write into CSS.
public struct HexColor: Sendable, Equatable {
    public let value: String

    /// Returns nil unless `value` is `#` followed by six hexadecimal digits and nothing else.
    public init?(_ value: String) {
        guard value.fullyMatches(#"#[0-9A-Fa-f]{6}"#) else { return nil }
        self.value = value
    }

    /// WCAG relative luminance.
    var luminance: Double {
        let digits = Array(value.dropFirst())
        func channel(at offset: Int) -> Double {
            let level = Double(Int(String(digits[offset...offset + 1]), radix: 16) ?? 0) / 255
            return level <= 0.03928 ? level / 12.92 : pow((level + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(at: 0) + 0.7152 * channel(at: 2) + 0.0722 * channel(at: 4)
    }

    /// The WCAG contrast ratio between the two colours, from 1 (identical) to 21 (black on white).
    public func contrast(with other: HexColor) -> Double {
        let lighter = max(luminance, other.luminance), darker = min(luminance, other.luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

/// Only readable palettes exist: text on background ≥ 4.5:1, primary on background ≥ 3:1. Designs can
/// only colour text with these variables, so no palette can make text invisible.
public struct Palette: Sendable, Equatable {
    public let primary: HexColor, text: HexColor, background: HexColor

    /// Returns nil when the text or the primary colour is not readable on the background.
    public init?(primary: HexColor, text: HexColor, background: HexColor) {
        guard text.contrast(with: background) >= 4.5, primary.contrast(with: background) >= 3 else { return nil }
        self.primary = primary; self.text = text; self.background = background
    }

    /// The `:root` rule that gives a design its colour variables.
    public var customProperties: String {
        ":root{--color-primary:\(primary.value);--color-text:\(text.value);--color-background:\(background.value)}"
    }
}

/// Font stacks are a closed set of system families; designs refer to them only through variables.
public enum FontScheme: String, Sendable, CaseIterable {
    case system, serif, rounded

    /// The `:root` rule that gives a design its font variables.
    public var customProperties: String {
        let stack = switch self {
        case .system: "-apple-system,system-ui,Helvetica,Arial,sans-serif"
        case .serif: "Georgia,'Times New Roman',serif"
        case .rounded: "ui-rounded,-apple-system,system-ui,sans-serif"
        }
        return ":root{--font-body:\(stack);--font-heading:\(stack)}"
    }
}

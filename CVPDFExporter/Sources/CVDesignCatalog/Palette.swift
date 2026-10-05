import Foundation

/// A palette colour: only `#RRGGBB` can exist, so it is safe to write into CSS.
public struct HexColor: Sendable, Equatable {
    public let value: String
    public init?(_ value: String) {
        guard value.fullyMatches(#"#[0-9A-Fa-f]{6}"#) else { return nil }
        self.value = value
    }
    /// WCAG relative luminance.
    var luminance: Double {
        let hex = Array(value.dropFirst())
        func channel(_ k: Int) -> Double {
            let v = Double(Int(String(hex[k...k + 1]), radix: 16) ?? 0) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4)
    }
    public func contrast(with other: HexColor) -> Double {
        let (a, b) = (luminance, other.luminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// Only readable palettes exist: text on background ≥ 4.5:1, primary on background ≥ 3:1. Designs can
/// only colour text with these variables, so no palette can make text invisible.
public struct Palette: Sendable, Equatable {
    public let primary: HexColor, text: HexColor, background: HexColor
    public init?(primary: HexColor, text: HexColor, background: HexColor) {
        guard text.contrast(with: background) >= 4.5, primary.contrast(with: background) >= 3 else { return nil }
        self.primary = primary; self.text = text; self.background = background
    }
    public var customProperties: String {
        ":root{--color-primary:\(primary.value);--color-text:\(text.value);--color-background:\(background.value)}"
    }
}

/// Font stacks are a closed set of system families; designs refer to them only through variables.
public enum FontScheme: String, Sendable, CaseIterable {
    case system, serif, rounded
    public var customProperties: String {
        let stack = switch self {
        case .system: "-apple-system,system-ui,Helvetica,Arial,sans-serif"
        case .serif: "Georgia,'Times New Roman',serif"
        case .rounded: "ui-rounded,-apple-system,system-ui,sans-serif"
        }
        return ":root{--font-body:\(stack);--font-heading:\(stack)}"
    }
}

import Foundation

/// The lengths a property accepts. The bounds are what a CV design plausibly needs; anything outside them can hide
/// or displace content. With `relativeUnits` false only pt and px are accepted: em and % compound through nesting
/// (60% of 60% of …) and rem depends on the root's size, so an absolute unit is the only way a floor holds whatever
/// the rest of the stylesheet does.
struct LengthBounds {
    let pt: ClosedRange<Double>
    let em: ClosedRange<Double>
    let percent: ClosedRange<Double>?
    var relativeUnits = true

    private static let pointsPerPixel = 0.75

    static let fontSize = LengthBounds(pt: 7...48, em: 0.6...4, percent: nil, relativeUnits: false)
    static let spacing = LengthBounds(pt: 0...48, em: 0...4, percent: nil)
    static let borderWidth = LengthBounds(pt: 0...4, em: 0...0.3, percent: nil)
    static let letterSpacing = LengthBounds(pt: 0...3, em: 0...0.3, percent: nil)
    static let borderRadius = LengthBounds(pt: 0...16, em: 0...1, percent: nil)
    /// The width of a box or a grid track.
    static let extent = LengthBounds(pt: 36...600, em: 3...40, percent: 10...100)
    /// Flex and grid drop the space between inline entries, so their column gap must replace it.
    static let columnGap = LengthBounds(pt: 3...48, em: 0.25...4, percent: nil)

    /// The canonical text of `token`, or the refusal of a token that is not an allowed length.
    func canonicalLength(of token: CSSToken) throws(CSSRejection) -> String {
        switch token {
        case .number(0) where pt.contains(0): return "0"      // a bare 0 only where zero is allowed (not font-size)
        case .dimension(let value, "pt") where pt.contains(value): return canonicalNumber(value) + "pt"
        case .dimension(let value, "px") where pt.contains(value * Self.pointsPerPixel): return canonicalNumber(value) + "px"
        case .dimension(let value, let unit) where acceptsFontRelative(unit, value): return canonicalNumber(value) + unit
        case .percentage(let value) where acceptsPercentage(value): return canonicalNumber(value) + "%"
        default: throw CSSRejection(reason: "length out of bounds or unit not allowed")
        }
    }

    private func acceptsFontRelative(_ unit: String, _ value: Double) -> Bool {
        relativeUnits && (unit == "em" || unit == "rem") && em.contains(value)
    }

    private func acceptsPercentage(_ value: Double) -> Bool { relativeUnits && percent?.contains(value) == true }
}

/// Formats a number that the caller has already bounded. The tokenizer refuses more than 9 digits before the point,
/// so the conversion to `Int` cannot overflow.
func canonicalNumber(_ number: Double) -> String {
    let rounded = (number * 1000).rounded() / 1000
    guard rounded.magnitude < 1e9 else { return "0" }
    return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
}

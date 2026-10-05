import Foundation

enum Unit { case pt, em, percent, fr }

/// Bounds are what a CV design plausibly needs; anything outside them can hide or displace content.
/// `relativeUnits: false` accepts only pt and px. em and % compound through nesting (60% of 60% of …), and rem
/// depends on the root's size; an absolute unit is the only way a floor holds whatever the rest of the stylesheet does.
struct LengthBounds { let pt: ClosedRange<Double>; let em: ClosedRange<Double>; let percent: ClosedRange<Double>?; var relativeUnits = true }

/// Formats a number that the caller has already bounded. Values outside ±1e9 never reach here: the
/// tokenizer rejects numbers with more than 9 digits before the point (review: Int(Double) overflow trap).
func fmt(_ d: Double) -> String {
    let r = (d * 1000).rounded() / 1000
    guard r.magnitude < 1e9 else { return "0" }
    return r == r.rounded() ? String(Int(r)) : String(r)
}

enum CSSValue {
    typealias Check = @Sendable ([CSSToken]) throws(CSSRejection) -> String

    static func keyword(_ allowed: Set<String>) -> Check {
        { (t: [CSSToken]) throws(CSSRejection) -> String in
            guard t.count == 1, case .ident(let k) = t[0], allowed.contains(k.lowercased()) else { throw CSSRejection(reason: "value not allowed") }
            return k.lowercased()
        }
    }

    static func variable(_ allowed: Set<String>, orKeywords keywords: Set<String> = []) -> Check {
        { (t: [CSSToken]) throws(CSSRejection) -> String in
            if t.count == 1, case .ident(let k) = t[0], keywords.contains(k.lowercased()) { return k.lowercased() }
            guard t.count == 3, t[0] == .function("var"), case .ident(let v) = t[1], allowed.contains(v), t[2] == .rparen else {
                throw CSSRejection(reason: "only \(allowed.sorted()) are allowed here")
            }
            return "var(\(v))"
        }
    }

    static func length(_ token: CSSToken, _ b: LengthBounds) throws(CSSRejection) -> String {
        switch token {
        case .number(0) where b.pt.contains(0): return "0"      // a bare 0 only where zero is allowed (not font-size)
        case .dimension(let v, "pt") where b.pt.contains(v): return "\(fmt(v))pt"
        case .dimension(let v, "px") where b.pt.contains(v * 0.75): return "\(fmt(v))px"
        case .dimension(let v, let u) where (u == "em" || u == "rem") && b.relativeUnits && b.em.contains(v): return "\(fmt(v))\(u)"
        case .percentage(let v) where b.relativeUnits && b.percent?.contains(v) == true: return "\(fmt(v))%"
        default: throw CSSRejection(reason: "length out of bounds or unit not allowed")
        }
    }

    static func lengths(_ b: LengthBounds, count: ClosedRange<Int>) -> Check {
        { (t: [CSSToken]) throws(CSSRejection) -> String in
            guard count.contains(t.count) else { throw CSSRejection(reason: "wrong number of values") }
            var out: [String] = []
            for token in t { out.append(try length(token, b)) }
            return out.joined(separator: " ")
        }
    }

    static func number(_ range: ClosedRange<Double>, keywords: Set<String> = []) -> Check {
        { (t: [CSSToken]) throws(CSSRejection) -> String in
            if t.count == 1, case .ident(let k) = t[0], keywords.contains(k.lowercased()) { return k.lowercased() }
            guard t.count == 1, case .number(let v) = t[0], range.contains(v) else { throw CSSRejection(reason: "number out of bounds") }
            return fmt(v)
        }
    }

    static let colorVars: Set<String> = ["--color-text", "--color-primary"]
    static let fontSize = LengthBounds(pt: 7...48, em: 0.6...4, percent: nil, relativeUnits: false)
    static let spacing = LengthBounds(pt: 0...48, em: 0...4, percent: nil)
    static let borderWidth = LengthBounds(pt: 0...4, em: 0...0.3, percent: nil)
    /// Flex and grid drop the space between inline entries, so their column gap must replace it.
    static let columnGap = LengthBounds(pt: 3...48, em: 0.25...4, percent: nil)

    /// `gap: <row> <column>` or `gap: <both>`: the column component is bounded like `column-gap`.
    static let gap: Check = { (t: [CSSToken]) throws(CSSRejection) -> String in
        switch t.count {
        case 1: return try length(t[0], columnGap)
        case 2: return try length(t[0], spacing) + " " + length(t[1], columnGap)
        default: throw CSSRejection(reason: "gap takes 1 or 2 lengths")
        }
    }

    static func border(styles: Set<String>) -> Check {
        { (t: [CSSToken]) throws(CSSRejection) -> String in
            var width: String?, style: String?, color: String?
            var i = 0
            while i < t.count {
                if case .ident(let k) = t[i], styles.contains(k.lowercased()), style == nil { style = k.lowercased(); i += 1; continue }
                if t[i] == .function("var"), i + 2 < t.count { color = try variable(colorVars)(Array(t[i...(i + 2)])); i += 3; continue }
                if width == nil { width = try length(t[i], borderWidth); i += 1; continue }
                throw CSSRejection(reason: "border value not allowed")
            }
            return [width, style, color].compactMap { $0 }.joined(separator: " ")
        }
    }

    static let gridColumns: Check = { (t: [CSSToken]) throws(CSSRejection) -> String in
        guard (1...4).contains(t.count) else { throw CSSRejection(reason: "1 to 4 grid tracks") }
        var out: [String] = []
        for token in t {
            if case .dimension(let v, "fr") = token, (0.1...10).contains(v) { out.append("\(fmt(v))fr") }
            else { out.append(try length(token, LengthBounds(pt: 36...600, em: 3...40, percent: 10...100))) }
        }
        return out.joined(separator: " ")
    }
}

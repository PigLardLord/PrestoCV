import Foundation

/// Formats a number that the caller has already bounded. The tokenizer refuses more than 9 digits before the point,
/// so the conversion to `Int` cannot overflow.
func canonicalNumber(_ number: Double) -> String {
    let rounded = (number * 1000).rounded() / 1000
    guard rounded.magnitude < 1e9 else { return "0" }
    return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
}

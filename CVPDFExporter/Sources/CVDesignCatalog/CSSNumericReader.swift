import Foundation

/// A number, a percentage or a dimension (a number and its unit, lower-cased). The digits are bounded here, so a
/// value later turned into an `Int` can never overflow.
struct CSSNumericReader: CSSTokenReader {
    private static let maxIntegerDigits = 9, maxCharacters = 16

    /// An optional sign, then digits, or a point and a digit.
    func begins(in input: CSSInput) -> Bool {
        let digits = input.satisfies(\.isCSSSign) ? 1 : 0
        return input.satisfies(\.isCSSDigit, at: digits) || (input.matches(".", at: digits) && input.satisfies(\.isCSSDigit, at: digits + 1))
    }

    func read(from input: inout CSSInput) throws(CSSRejection) -> CSSToken? {
        let value = try readValue(from: &input)
        if input.matches("%") {
            input.skip()
            return .percentage(value)
        }
        guard input.satisfies(\.isCSSNameStart) else { return .number(value) }
        return .dimension(value, input.takeName().lowercased())
    }

    private func readValue(from input: inout CSSInput) throws(CSSRejection) -> Double {
        let sign = input.satisfies(\.isCSSSign) ? input.take(1) : ""
        let integer = input.take(while: \.isCSSDigit)
        let text = sign + integer + readFraction(from: &input)
        guard integer.count <= Self.maxIntegerDigits, text.count <= Self.maxCharacters, let value = Double(text) else {
            throw CSSRejection(reason: "number out of range")
        }
        return value
    }

    /// A point and the digits after it; a point with no digit after it is not part of the number.
    private func readFraction(from input: inout CSSInput) -> String {
        guard input.matches("."), input.satisfies(\.isCSSDigit, at: 1) else { return "" }
        return input.take(1) + input.take(while: \.isCSSDigit)
    }
}

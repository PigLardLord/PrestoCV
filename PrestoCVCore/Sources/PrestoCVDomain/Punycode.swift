/// The length of a domain label once it is encoded for the wire (IDNA, RFC 5891): an all-ASCII label stays as it is,
/// any other becomes `xn--` and its Punycode (RFC 3492). Only the length check of `EmailAddress` uses it.
enum IDNALabel {
    static let prefix = "xn--"

    static func encodedByteCount(_ label: Substring) -> Int {
        if label.unicodeScalars.allSatisfy(\.isASCII) { return label.utf8.count }
        return prefix.utf8.count + Punycode.encode(Array(label.unicodeScalars)).utf8.count
    }
}

/// The Punycode encoder of RFC 3492, section 6.3, with the parameters of section 5 and the digits of section 5
/// (a to z, then 0 to 9). It keeps the basic (ASCII) code points as they are and writes the others as deltas.
enum Punycode {
    private static let base = 36, tMin = 1, tMax = 26, skew = 38, damp = 700, initialBias = 72, initialN = 128
    private static let delimiter: Unicode.Scalar = "-"

    static func encode(_ input: [Unicode.Scalar]) -> String {
        var output = String(String.UnicodeScalarView(input.filter(\.isASCII)))
        let basicCount = output.unicodeScalars.count
        if basicCount > 0 { output.unicodeScalars.append(delimiter) }
        var n = initialN, delta = 0, bias = initialBias, handled = basicCount
        while handled < input.count {
            let next = input.map { Int($0.value) }.filter { $0 >= n }.min() ?? n
            delta += (next - n) * (handled + 1)
            n = next
            for scalar in input.map({ Int($0.value) }) {
                if scalar < n { delta += 1 }
                if scalar == n {
                    appendDelta(delta, bias: bias, to: &output)
                    bias = adapt(delta: delta, points: handled + 1, first: handled == basicCount)
                    delta = 0
                    handled += 1
                }
            }
            delta += 1
            n += 1
        }
        return output
    }

    private static func appendDelta(_ value: Int, bias: Int, to output: inout String) {
        var q = value, k = base
        while true {
            let threshold = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias)
            if q < threshold { break }
            output.unicodeScalars.append(digit(threshold + (q - threshold) % (base - threshold)))
            q = (q - threshold) / (base - threshold)
            k += base
        }
        output.unicodeScalars.append(digit(q))
    }

    private static func adapt(delta: Int, points: Int, first: Bool) -> Int {
        var d = first ? delta / damp : delta / 2
        d += d / points
        var k = 0
        while d > ((base - tMin) * tMax) / 2 {
            d /= base - tMin
            k += base
        }
        return k + (base - tMin + 1) * d / (d + skew)
    }

    /// 0 to 25 are "a" to "z", 26 to 35 are "0" to "9".
    private static func digit(_ value: Int) -> Unicode.Scalar {
        Unicode.Scalar(UInt8(value < 26 ? 97 + value : 22 + value))
    }
}

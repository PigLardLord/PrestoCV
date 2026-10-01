/// Punycode (RFC 3492): the encoding that writes a label with non-ASCII letters in ASCII, as an IDNA A-label does
/// after its `xn--` prefix (RFC 5891). Only encoding is needed, to know how long a label is on the wire.
enum Punycode {
    private static let base: UInt32 = 36, tMin: UInt32 = 1, tMax: UInt32 = 26, skew: UInt32 = 38, damp: UInt32 = 700
    private static let initialBias: UInt32 = 72, initialN: UInt32 = 128
    private static let delimiter = UInt8(ascii: "-")

    /// The encoding of `label`, or nil when a counter would pass 32 bits, as the RFC requires.
    static func encode(_ label: String) -> String? {
        let input = label.unicodeScalars.map(\.value)
        var output = label.unicodeScalars.filter(\.isASCII).map { UInt8(ascii: $0) }
        let basicCount = output.count
        if basicCount > 0 { output.append(delimiter) }

        var handled = basicCount, n = initialN, delta: UInt32 = 0, bias = initialBias
        while handled < input.count {
            guard let next = input.filter({ $0 >= n }).min(), let passPoints = UInt32(exactly: handled + 1) else { return nil }
            let (step, stepOverflow) = (next - n).multipliedReportingOverflow(by: passPoints)
            let (jumped, jumpOverflow) = delta.addingReportingOverflow(step)
            guard !stepOverflow, !jumpOverflow else { return nil }
            n = next; delta = jumped
            for scalar in input {
                if scalar < n {
                    let (passed, overflow) = delta.addingReportingOverflow(1)
                    guard !overflow else { return nil }
                    delta = passed
                } else if scalar == n {
                    guard let points = UInt32(exactly: handled + 1) else { return nil }
                    appendInteger(delta, bias: bias, to: &output)
                    bias = adapt(delta, points: points, firstTime: handled == basicCount)
                    delta = 0
                    handled += 1
                }
            }
            let (advanced, overflow) = delta.addingReportingOverflow(1)
            guard !overflow else { return nil }
            delta = advanced; n += 1
        }
        return String(decoding: output, as: UTF8.self)
    }

    /// Writes `value` as a generalised variable-length integer: base 36 digits, the threshold moving with the bias.
    private static func appendInteger(_ value: UInt32, bias: UInt32, to output: inout [UInt8]) {
        var q = value, k = base
        while true {
            let t = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias)
            if q < t { break }
            output.append(digit(t + (q - t) % (base - t)))
            q = (q - t) / (base - t)
            k += base
        }
        output.append(digit(q))
    }

    private static func adapt(_ delta: UInt32, points: UInt32, firstTime: Bool) -> UInt32 {
        var d = firstTime ? delta / damp : delta / 2
        d += d / points
        var k: UInt32 = 0
        while d > ((base - tMin) * tMax) / 2 {
            d /= base - tMin
            k += base
        }
        return k + (base - tMin + 1) * d / (d + skew)
    }

    /// 0...25 are "a"..."z", 26...35 are "0"..."9".
    private static func digit(_ value: UInt32) -> UInt8 {
        UInt8(truncatingIfNeeded: value < 26 ? value + UInt32(UInt8(ascii: "a")) : value - 26 + UInt32(UInt8(ascii: "0")))
    }
}

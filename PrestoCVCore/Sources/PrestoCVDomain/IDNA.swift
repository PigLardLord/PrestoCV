import Foundation   // String normalisation only: no ambient state (R2)

/// How a domain label is written on the wire by IDNA (RFC 5890, RFC 5891), to check how long it is once encoded. The
/// label is prepared the way a lookup prepares it, lowercased and in Unicode NFC, without the further mappings of UTS 46
/// (ligatures expand, fullwidth letters shrink). The length is therefore a necessary condition for a label to be
/// deliverable, not a guarantee that a mail system accepts it.
enum IDNA {
    /// The prepared label when it is ASCII, otherwise `xn--` and its Punycode. nil when the encoding overflows.
    static func aLabel(_ label: String) -> String? {
        let prepared = label.lowercased().precomposedStringWithCanonicalMapping
        guard !prepared.unicodeScalars.allSatisfy(\.isASCII) else { return prepared }
        return Punycode.encode(prepared).map { "xn--" + $0 }
    }
}

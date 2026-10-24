/// The credentials that follow a name in the head of a CV: "Jane Rowe, RN", "John Smith, CPA", "Lena Hartmann, Dipl.-Ing.",
/// "Jane Rowe, Bachelor of Science in Nursing". The name is read before them and they go with the title, so the name is
/// the name of the person and nothing else.
enum Credentials {

    struct Split {
        let name: Piece
        /// Each credential, in the order of the line.
        let credentials: [Piece]
        /// The text from the first credential to the end of the line, to show when no title takes the credentials.
        let tail: Piece
        /// Whether a code that is also a state ("MD", "PA") stands among them: the name is then a guess.
        let isAmbiguous: Bool
    }

    /// The line cut into the name and its credentials, when every part after the name is a credential: the parts after a
    /// comma, and a run of codes in capitals at the end of the name ("JOHN SMITH CPA"). A code that is also the code of a
    /// state is a credential only when `allowingAmbiguous` is set: "Silver Spring, MD" is a place, "Jane Rowe, MD" a physician.
    static func split(_ piece: Piece, allowingAmbiguous: Bool) -> Split? {
        let parts = piece.split(by: [","])
        guard let head = parts.first else { return nil }
        var credentials: [Piece] = []
        var isAmbiguous = false
        for part in parts.dropFirst() {
            switch kind(of: part.text) {
            case .credential:
                credentials.append(part)
            case .ambiguous where allowingAmbiguous:
                credentials.append(part)
                isAmbiguous = true
            default:
                return nil
            }
        }

        // The codes right after the name, with no comma, at least two words of name before them
        let tokens = head.text.split(separator: " ")
        var kept = tokens.count
        while kept > 2, kind(of: String(tokens[kept - 1])) == .credential { kept -= 1 }
        var name = head
        if kept < tokens.count {
            let run = tokens[kept...].map { head.sub($0.startIndex..<$0.endIndex) }
            credentials = run + credentials
            name = head.sub(head.text.startIndex..<tokens[kept].startIndex).trimmed()
        }

        guard let first = credentials.first, !name.isEmpty else { return nil }
        let scalars = piece.text.unicodeScalars
        let offset = max(0, min(first.span.lowerBound - piece.span.lowerBound, scalars.count))
        let start = scalars.index(scalars.startIndex, offsetBy: offset)
        return Split(name: name, credentials: credentials, tail: piece.sub(start..<piece.text.endIndex).trimmed(), isAmbiguous: isAmbiguous)
    }

    // MARK: What a credential is

    private enum Kind {
        case none, credential, ambiguous
    }

    private static func kind(of text: String) -> Kind {
        let words = text.split(separator: " ")
        guard (1...8).contains(words.count), !text.contains(where: \.isNumber) else { return .none }
        if words.count == 1 { return codeKind(of: text) }
        // A code with the field it is in: "BS in Nursing", "MSc in Data Science"
        if words.count >= 3, connectors.contains(words[1].folded) {
            let first = codeKind(of: String(words[0]))
            if first != .none { return first }
        }
        return EntryVocabulary.startsWithDegree(text) ? .credential : .none
    }

    /// A code: letters with dots or hyphens, short, in capitals or in the mixed forms of the degrees ("PhD", "MSc").
    private static func codeKind(of text: String) -> Kind {
        guard text.count <= 12, text.allSatisfy({ $0.isLetter || ".-".contains($0) }) else { return .none }
        let letters = text.filter(\.isLetter)
        let upper = letters.uppercased()
        let isDotted = text.contains(".")
        let isCapitals = letters == upper
        if ambiguousCodes.contains(upper) {
            if isDotted { return .credential }
            return isCapitals ? .ambiguous : .none
        }
        guard codes.contains(upper) else { return .none }
        return isCapitals || isDotted || mixedCaseCodes.contains(upper) ? .credential : .none
    }

    private static let connectors: Set<String> = ["in", "of", "en", "em", "di", "de", "im"]

    /// Codes that name no state or province.
    private static let codes: Set<String> = [
        "RN", "LPN", "LVN", "MSN", "BSN", "ADN", "NP", "APRN", "CRNA", "CNM", "CNS", "CNA", "FNP", "DNP", "CCRN", "CEN", "PMP", "CPA",
        "CFA", "CFP", "CMA", "CISSP", "CISA", "CISM", "CCNA", "CCNP", "MBA", "EMBA", "PHD", "EDD", "DBA", "DDS", "DMD", "DVM", "DPT",
        "OTR", "COTA", "LCSW", "LMFT", "LPC", "RDN", "MSC", "BSC", "MENG", "BENG", "MPH", "MPA", "MFA", "MPP", "MED", "LLM", "LLB", "JD",
        "FRCS", "FACS", "FACP", "MPHIL", "DPHIL", "DIPLING", "DIPLKFM", "DIPLINF", "BS", "BA", "DO", "OD",
    ]

    /// Codes that are also the code of a state or a province: Maryland, Massachusetts, Mississippi, Pennsylvania, the
    /// District of Columbia, Prince Edward Island.
    private static let ambiguousCodes: Set<String> = ["MD", "MA", "MS", "PA", "DC", "PE"]

    private static let mixedCaseCodes: Set<String> = ["PHD", "MSC", "BSC", "MENG", "BENG", "MED", "EDD", "MPHIL", "DPHIL", "DIPLING", "DIPLKFM", "DIPLINF"]
}

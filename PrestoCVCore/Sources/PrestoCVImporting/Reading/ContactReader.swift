import PrestoCVDomain

/// Reads e-mail addresses, phone numbers and web addresses in a piece of text. A value is kept only as the domain's
/// value object accepts it (`EmailAddress`, `PhoneNumber`, `WebLink`), so the rule of what an address is exists once
/// (R6).
enum ContactReader {

    struct Contacts {
        var emails: [Sourced<EmailAddress>] = []
        var phones: [Sourced<PhoneNumber>] = []
        var links: [ImportedLink] = []
        /// What is left of the piece, split where a contact was, without the labels of the contacts.
        var rest: [Piece] = []

        var isEmpty: Bool { emails.isEmpty && phones.isEmpty && links.isEmpty }
    }

    static func read(_ piece: Piece) -> Contacts {
        var contacts = Contacts()
        var consumed: [Range<String.Index>] = []
        let text = piece.text

        for range in emailRanges(in: text) {
            let candidate = piece.sub(range)
            if let email = EmailAddress(candidate.text) {
                contacts.emails.append(Sourced(value: email, spans: [candidate.span]))
                consumed.append(range)
            }
        }
        for range in tokenRanges(in: text) where !consumed.contains(where: { $0.overlaps(range) }) {
            let candidate = piece.sub(range)
            if let link = link(candidate) {
                contacts.links.append(link)
                consumed.append(range)
            }
        }
        for range in phoneRanges(in: text) where !consumed.contains(where: { $0.overlaps(range) }) {
            let candidate = piece.sub(range)
            if let phone = PhoneNumber(candidate.text) {
                contacts.phones.append(Sourced(value: phone, spans: [candidate.span]))
                consumed.append(range)
            }
        }
        contacts.rest = piece.removing(consumed).flatMap { $0.split(by: Separators.strong) }.filter { !isContactLabel($0.text) }
        return contacts
    }

    // MARK: Labels

    /// The label of a contact field, such as "E-mail", "Tel.", "Handy" or "(Mobile)".
    static func isContactLabel(_ text: String) -> Bool {
        contactLabels.contains(SectionVocabulary.key(text))
    }

    static func isPhoneLabel(_ text: String) -> Bool {
        phoneLabels.contains(SectionVocabulary.key(text))
    }

    private static let phoneLabels: Set<String> = Set([
        "tel", "tel.", "telefon", "telefono", "telefonnummer", "telephone", "téléphone", "teléfono", "telefone", "phone", "mobile",
        "mobil", "handy", "cell", "cellulare", "cell.", "móvil", "portable", "telemóvel", "celular", "tlf", "tlm", "mob", "fon",
        "mobile phone", "numero di telefono", "número de teléfono", "número de telefone", "tél", "mobiltelefon", "work", "home",
    ].map(SectionVocabulary.key))

    private static let contactLabels: Set<String> = phoneLabels.union([
        "mail", "e-mail", "email", "e mail", "posta elettronica", "correo", "correo electrónico", "courriel", "correio eletrónico",
        "correio eletrônico", "linkedin", "github", "xing", "website", "web", "sito", "sito web", "homepage", "webseite", "sitio web",
        "site web", "site", "portfolio", "personal", "company", "other", "blog",
    ].map(SectionVocabulary.key))

    // MARK: E-mail addresses

    private static func emailRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var index = text.startIndex
        while let at = text[index...].firstIndex(of: "@") {
            var start = at
            while start > text.startIndex {
                let previous = text[text.index(before: start)]
                guard previous.isLetter || previous.isNumber || "._%+-'".contains(previous) else { break }
                start = text.index(before: start)
            }
            var end = text.index(after: at)
            while end < text.endIndex, text[end].isLetter || text[end].isNumber || ".-".contains(text[end]) { end = text.index(after: end) }
            while end > text.index(after: at), ".-".contains(text[text.index(before: end)]) { end = text.index(before: end) }
            if start < at, end > text.index(after: at) { ranges.append(start..<end) }
            index = text.index(after: at)
        }
        return ranges
    }

    // MARK: Web addresses

    /// The ranges of the text's words, without the brackets and punctuation around them.
    private static func tokenRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start: String.Index?
        var index = text.startIndex
        func close(at end: String.Index) {
            guard var lower = start else { return }
            var upper = end
            while lower < upper, "(<[\"'".contains(text[lower]) { lower = text.index(after: lower) }
            while upper > lower, ")>],;:.!?\"'".contains(text[text.index(before: upper)]) { upper = text.index(before: upper) }
            if lower < upper { ranges.append(lower..<upper) }
            start = nil
        }
        while index < text.endIndex {
            if text[index].isWhitespace || text[index] == "|" || text[index] == "·" || text[index] == "•" {
                close(at: index)
            } else if start == nil {
                start = index
            }
            index = text.index(after: index)
        }
        close(at: text.endIndex)
        return ranges
    }

    private static func link(_ candidate: Piece) -> ImportedLink? {
        let token = candidate.text
        let lowered = token.lowercased()
        guard !token.contains("@") else { return nil }
        let address: Sourced<WebLink>
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
            guard let link = WebLink(token) else { return nil }
            address = Sourced(value: link, spans: [candidate.span])
        } else if lowered.hasPrefix("www.") || looksLikeDomain(token) {
            guard let link = WebLink("https://" + token) else { return nil }
            address = Sourced(value: link, spans: [candidate.span], reading: .webAddress)
        } else {
            return nil
        }
        let host = lowered.split(separator: "/").first { $0.contains(".") } ?? Substring(lowered)
        let kind: ImportedLink.Kind
        if host.contains("linkedin.") { kind = .linkedIn }
        else if host.contains("github.") { kind = .gitHub }
        else if host.contains("xing.") { kind = .xing }
        else { kind = .website }
        return ImportedLink(address: address, kind: kind)
    }

    /// A domain in lower case with a known top-level domain, such as "linkedin.com/in/…" or "example.dev".
    private static func looksLikeDomain(_ token: String) -> Bool {
        let host = token.split(separator: "/", maxSplits: 1).first.map(String.init) ?? token
        guard host == host.lowercased(), host.contains(".") else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } }),
              let tld = labels.last, topLevelDomains.contains(String(tld)), let name = labels.dropLast().last, name.count >= 2 else {
            return false
        }
        return true
    }

    private static let topLevelDomains: Set<String> = [
        "com", "org", "net", "io", "dev", "app", "me", "eu", "it", "de", "es", "fr", "pt", "ch", "at", "co", "uk", "info", "page",
        "site", "be", "nl", "br", "online", "tech", "design", "blog",
    ]

    // MARK: Phone numbers

    private static func phoneRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var index = text.startIndex
        let allowed: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", " ", "+", "(", ")", ".", "/", "-"]
        while index < text.endIndex {
            let character = text[index]
            let startsNumber = character == "+" || (character.isASCII && character.isNumber)
                || (character == "(" && text.index(after: index) < text.endIndex && text[text.index(after: index)].isNumber)
            let startsWord = index == text.startIndex || !(text[text.index(before: index)].isLetter || text[text.index(before: index)].isNumber)
            guard startsNumber, startsWord else {
                index = text.index(after: index)
                continue
            }
            var end = index
            while end < text.endIndex, allowed.contains(text[end]) { end = text.index(after: end) }
            while end > index, !(text[text.index(before: end)].isNumber) { end = text.index(before: end) }
            let candidate = text[index..<end]
            if isPhone(candidate, labelled: label(before: index, in: text)) {
                ranges.append(index..<end)
                index = end
            } else {
                index = end > index ? end : text.index(after: index)
            }
        }
        return ranges
    }

    private enum Label { case phone, fax, none }

    /// The label right before a number: "Tel.:", "Handy", "📞", or "Fax".
    private static func label(before index: String.Index, in text: String) -> Label {
        let before = text[..<index].trimmingSpaces()
        if let last = before.last, Piece.isIcon(last), "📞📱☎✆".contains(last) { return .phone }
        let words = before.split(whereSeparator: { $0 == " " || $0 == ":" || $0 == "|" || $0 == "·" }).suffix(2)
        guard let lastWord = words.last else { return .none }
        let lastTwo = words.joined(separator: " ")
        if SectionVocabulary.key(String(lastWord)) == "fax" { return .fax }
        return isPhoneLabel(String(lastWord)) || isPhoneLabel(lastTwo) ? .phone : .none
    }

    private static func isPhone(_ candidate: Substring, labelled: Label) -> Bool {
        let digits = candidate.filter(\.isNumber)
        guard (7...17).contains(digits.count), labelled != .fax else { return false }
        // A date or a period is no phone number
        if let period = DateReader.periods(in: candidate).first, candidate[period.range].filter(\.isNumber).count * 2 >= digits.count {
            return false
        }
        if labelled == .phone { return true }
        if candidate.hasPrefix("+") || candidate.hasPrefix("0") || candidate.hasPrefix("(") { return true }
        return digits.count >= 9 && candidate.contains(" ")
    }
}

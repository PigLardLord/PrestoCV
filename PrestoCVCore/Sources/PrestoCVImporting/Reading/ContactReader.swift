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
        /// The labels before a contact that the vocabulary does not know ("Contact via"), to be shown as text not imported.
        var unknownLabels: [Piece] = []
        /// The labels of a contact with no contact beside them ("iOS Engineer · Mobile"): they name no value of the piece.
        var labels: [Piece] = []
        /// The kind of the first contact, when nothing but its labels comes before it: the value a label alone on the line
        /// above may name ("Mobile" over "+49 170 1234567").
        var leading: Kind?

        var isEmpty: Bool { emails.isEmpty && phones.isEmpty && links.isEmpty }
    }

    /// What a contact is.
    enum Kind { case email, phone, link }

    /// `label` is the label the value was given under, when the line had one ("Phone" before a number): a number under
    /// the label of a phone is the phone, whatever its shape.
    static func read(_ piece: Piece, label: EntryVocabulary.PersonalLabel? = nil) -> Contacts {
        var contacts = Contacts()
        var found: [(range: Range<String.Index>, kind: Kind)] = []
        let text = piece.text

        for range in emailRanges(in: text) {
            let candidate = piece.sub(range)
            if let email = EmailAddress(candidate.text) {
                contacts.emails.append(Sourced(value: email, spans: [candidate.span]))
                found.append((range, .email))
            }
        }
        // The words are apart from each other, and so are the numbers: a candidate meets only what was read before its
        // loop, and finding that is a search in order, not a look at each of the ranges (R8)
        let addresses = Taken(found.map(\.range))
        for range in tokenRanges(in: text) where !addresses.overlaps(range) {
            let candidate = piece.sub(range)
            if let link = link(candidate) {
                contacts.links.append(link)
                found.append((range, .link))
            }
        }
        let taken = found.map(\.range)
        let beside = Taken(taken)
        for range in phoneRanges(in: text, hinted: label == .phone, beside: taken) where !beside.overlaps(range) {
            let candidate = piece.sub(range)
            if let phone = PhoneNumber(candidate.text) {
                contacts.phones.append(Sourced(value: phone, spans: [candidate.span]))
                found.append((range, .phone))
            }
        }
        split(piece, around: found, into: &contacts)
        return contacts
    }

    /// The places of the text that the contacts read so far take, in order and apart from each other, so that whether a
    /// candidate meets one is found by halving them.
    private struct Taken {
        private var ranges: [Range<String.Index>] = []

        init(_ taken: [Range<String.Index>]) {
            for range in taken.sorted(by: { $0.lowerBound < $1.lowerBound }) {
                if let last = ranges.last, range.lowerBound < last.upperBound {
                    ranges[ranges.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
                } else {
                    ranges.append(range)
                }
            }
        }

        func overlaps(_ range: Range<String.Index>) -> Bool {
            guard !range.isEmpty else { return false }
            var low = 0
            var high = ranges.count
            while low < high {
                let middle = (low + high) / 2
                if ranges[middle].upperBound <= range.lowerBound { low = middle + 1 } else { high = middle }
            }
            return low < ranges.count && ranges[low].lowerBound < range.upperBound
        }
    }

    // MARK: What is left of the line

    /// The pieces between the contacts, split at the strong separators. A label right beside a contact is not a part
    /// of the line: a known one is dropped, an unknown one before a contact is kept apart to be shown, never read as a
    /// place or a title. A known label with no contact beside it names nothing of the piece and is kept apart too.
    private static func split(_ piece: Piece, around found: [(range: Range<String.Index>, kind: Kind)], into contacts: inout Contacts) {
        var start = piece.text.startIndex
        var afterAContact = false
        for (range, kind) in found.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) where range.lowerBound >= start {
            gap(piece.sub(start..<range.lowerBound), beforeAContact: true, afterAContact: afterAContact, into: &contacts)
            if !afterAContact && contacts.rest.isEmpty && contacts.labels.isEmpty && contacts.unknownLabels.isEmpty {
                contacts.leading = kind
            }
            afterAContact = true
            start = range.upperBound
        }
        gap(piece.sub(start..<piece.text.endIndex), beforeAContact: false, afterAContact: afterAContact, into: &contacts)
    }

    private static func gap(_ gap: Piece, beforeAContact: Bool, afterAContact: Bool, into contacts: inout Contacts) {
        let trimmed = gap.trimmed()
        var segments = trimmed.isEmpty ? [] : trimmed.split(by: Separators.strong)
        let endsWithColon = beforeAContact && gap.text.trimmingSpaces().hasSuffix(":")
        if endsWithColon, let last = segments.last, !isContactLabel(last.text) {
            if let (head, _) = strippingLabel(last) {
                segments.removeLast()
                if !head.isEmpty { segments.append(head) }
            } else if isLabelLike(last.text) {
                segments.removeLast()
                contacts.unknownLabels.append(last)
            }
        }
        // The labels next to a contact are its own: those before it ("Mobile · +49 …") and those after it ("+49 … (mobile)")
        var lower = segments.startIndex
        var upper = segments.endIndex
        if beforeAContact { while upper > lower, isContactLabel(segments[upper - 1].text) { upper -= 1 } }
        if afterAContact { while lower < upper, isContactLabel(segments[lower].text) { lower += 1 } }
        for segment in segments[lower..<upper] {
            if isContactLabel(segment.text) { contacts.labels.append(segment) } else { contacts.rest.append(segment) }
        }
    }

    /// The piece without a label of a contact at its end, as in "Available for relocation. Mail".
    private static func strippingLabel(_ piece: Piece) -> (head: Piece, label: Piece)? {
        let words = piece.words
        guard words.count >= 2 else { return nil }
        for count in stride(from: min(4, words.count - 1), through: 1, by: -1) {
            let start = words[words.count - count].startIndex
            let label = piece.sub(start..<piece.text.endIndex)
            guard isStrictLabel(label.text) else { continue }
            return (piece.sub(piece.text.startIndex..<start).trimmed(), label)
        }
        return nil
    }

    /// A short run of words with no digit and no comma, the shape of a label, not of a sentence or a list.
    private static func isLabelLike(_ text: String) -> Bool {
        let words = text.words
        return (1...4).contains(words.count) && text.allSatisfy { $0.isLetter || " ’'.-&/()".contains($0) }
    }

    // MARK: Labels

    /// The label of a contact field, such as "E-mail", "Tel.", "Handy", "Phone number" or "(Mobile)".
    static func isContactLabel(_ text: String) -> Bool {
        labelKind(text) != nil
    }

    static func isPhoneLabel(_ text: String) -> Bool {
        EntryVocabulary.personalLabel(text) == .phone || extraLabels[SectionVocabulary.key(text)] == .phone
    }

    /// The labels of a contact on a line of the document that name no value: no contact is beside them, and for a label
    /// alone on its line, no contact of its kind opens the line below ("Mobile" over "+49 170 1234567" names that number,
    /// "Mobile" over an e-mail address names nothing). The header shows them and the net of silent losses counts them, by
    /// this one rule (R6).
    static func labelsWithoutAValue(in block: SourceBlock, of document: SourceDocument) -> [Piece] {
        let line = Piece(text: document.text(of: block.span), span: block.span)
        let labels = read(line).labels
        guard labels.count == 1, let label = labels.first, label.span == line.trimmed().span, let kind = labelKind(label.text)
        else { return labels }
        let next = block.index + 1
        guard document.blocks.indices.contains(next) else { return labels }
        let below = document.blocks[next]
        guard let leading = read(Piece(text: document.text(of: below.span), span: below.span)).leading, names(kind, leading)
        else { return labels }
        return []
    }

    /// What a label names: a phone ("Mobile", "Work"), an e-mail address, a web address ("Blog"), or any of them
    /// ("Personal").
    private enum LabelKind { case phone, email, link, any }

    private static func labelKind(_ text: String) -> LabelKind? {
        if let kind = plainLabelKind(text) { return kind }
        // A qualifier in brackets does not change what the label is: "Telefon (privat)"
        let piece = Piece(text: text, span: SourceSpan(0, text.unicodeScalars.count))
        let ranges = piece.bracketedRanges()
        guard !ranges.isEmpty else { return nil }
        let parts = piece.removing(ranges)
        return parts.count == 1 ? plainLabelKind(parts[0].text) : nil
    }

    private static func plainLabelKind(_ text: String) -> LabelKind? {
        switch EntryVocabulary.personalLabel(text) {
        case .phone: .phone
        case .email: .email
        case .web: .link
        default: extraLabels[SectionVocabulary.key(text)]
        }
    }

    private static func names(_ label: LabelKind, _ kind: Kind) -> Bool {
        switch (label, kind) {
        case (.any, _), (.phone, .phone), (.email, .email), (.link, .link): true
        default: false
        }
    }

    /// A label the personal details of the CV know: the vocabulary of the labels exists once.
    private static func isStrictLabel(_ text: String) -> Bool {
        switch EntryVocabulary.personalLabel(text) {
        case .phone, .email, .web: true
        default: false
        }
    }

    /// Words a CV puts before a contact that are not the names of its fields: "Work" and "Home" before a phone, "Blog"
    /// before a web address, "Personal" before any of them.
    private static let extraLabels: [String: LabelKind] = Dictionary(
        ([("work", .phone), ("home", .phone), ("blog", .link), ("personal", .any), ("company", .any), ("other", .any)] as [(String, LabelKind)])
            .map { (SectionVocabulary.key($0.0), $0.1) },
        uniquingKeysWith: { first, _ in first }
    )

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
        return ImportedLink(address: address, kind: kind(of: address.value))
    }

    /// The platforms whose profile a link can be, each by its own domain. A link is a profile only when its host is that
    /// domain or a subdomain of it ("www.github.com", "de.linkedin.com"); any other host is a website: a site on GitHub
    /// Pages ("tobiasrenn.github.io") and a host that only holds the word ("linkedin.example.org") too.
    private static let profileDomains: [(domain: String, kind: ImportedLink.Kind)] = [
        ("linkedin.com", .linkedIn), ("github.com", .gitHub), ("xing.com", .xing),
    ]

    /// The kind of a link by its host: the host stands between the scheme and the first "/", "?" or "#", without the
    /// port and without a final dot.
    private static func kind(of link: WebLink) -> ImportedLink.Kind {
        let value = link.value.lowercased()
        // A WebLink always holds its scheme; a value without one is no profile.
        guard let scheme = value.firstRange(of: "://") else { return .website }
        var host = value[scheme.upperBound...].prefix { !"/?#".contains($0) }
        if let colon = host.firstIndex(of: ":") { host = host[..<colon] }
        while host.hasSuffix(".") { host = host.dropLast() }
        return profileDomains.first { host == $0.domain || host.hasSuffix("." + $0.domain) }?.kind ?? .website
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

    /// `hinted`: the line gave the value under the label of a phone. `beside` are the ranges of the other contacts of
    /// the line, which count as the edge of a number as the text's own edges do.
    private static func phoneRanges(in text: String, hinted: Bool, beside taken: [Range<String.Index>]) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        let edges = Edges(taken)
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
            let run = end
            while end > index, !(text[text.index(before: end)].isNumber) { end = text.index(before: end) }
            // No digit in the run of characters of a number: no place in it starts one ("+ + + +"), and it is passed in one step
            guard end > index else {
                index = run
                continue
            }
            let shape = Shape(text: text, range: index..<end, edges: edges)
            let start = index
            if isPhone(shape, marker: { marker(before: start, in: text) }, hinted: hinted) {
                ranges.append(start..<end)
            }
            index = end
        }
        return ranges
    }

    private enum Marker { case phone, fax, none }

    /// How many characters before a number its label is looked for: the longest label of the vocabulary is a few words, and a
    /// number is read once for each place it could start, so the text before it is not read from its start each time (R8).
    private static let markerReach = 120

    private static func isMarkerSeparator(_ character: Character) -> Bool {
        character == " " || character == ":" || character == "|" || character == "·"
    }

    /// The label right before a number: "Tel.:", "Handy", "Phone number", "📞", or "Fax".
    private static func marker(before index: String.Index, in text: String) -> Marker {
        var end = index
        while end > text.startIndex, text[text.index(before: end)].isWhitespace { end = text.index(before: end) }
        guard end > text.startIndex else { return .none }
        let last = text[text.index(before: end)]
        if Piece.isIcon(last), "📞📱☎✆".contains(last) { return .phone }
        var start = end
        var reach = 0
        while start > text.startIndex, reach < markerReach {
            start = text.index(before: start)
            reach += 1
        }
        var words = text[start..<end].split(whereSeparator: isMarkerSeparator)
        // The first word of the reach is cut short, when the reach starts inside a word: it is no word of the label
        if start > text.startIndex, !isMarkerSeparator(text[start]), !isMarkerSeparator(text[text.index(before: start)]) {
            words = Array(words.dropFirst())
        }
        let lastWords = words.suffix(3)
        guard let lastWord = lastWords.last else { return .none }
        if SectionVocabulary.key(String(lastWord)) == "fax" { return .fax }
        let suffixes = (1...lastWords.count).map { lastWords.suffix($0).joined(separator: " ") }
        return suffixes.contains(where: isPhoneLabel) ? .phone : .none
    }

    /// Where the other contacts of the line start and end: a place found by its index, not by a look at each contact.
    private struct Edges {
        let starts: Set<String.Index>
        let ends: Set<String.Index>

        init(_ taken: [Range<String.Index>]) {
            starts = Set(taken.map(\.lowerBound))
            ends = Set(taken.map(\.upperBound))
        }
    }

    /// A candidate number with what surrounds it in its text.
    private struct Shape {
        let candidate: Substring
        let digits: String
        /// Whether it stands alone in its text or between two separators, as a number of a line of contacts does.
        let isAlone: Bool

        init(text: String, range: Range<String.Index>, edges: Edges) {
            candidate = text[range]
            digits = String(candidate.filter(\.isNumber))
            isAlone = Shape.isEdge(before: range.lowerBound, in: text, edges: edges) && Shape.isEdge(after: range.upperBound, in: text, edges: edges)
        }

        private static let separators: Set<Character> = ["|", "·", "•", "—", "–", ";", "‧", "∙", "▪", "⋅"]

        private static func isEdge(before index: String.Index, in text: String, edges: Edges) -> Bool {
            var lower = index
            while lower > text.startIndex, text[text.index(before: lower)].isWhitespace {
                lower = text.index(before: lower)
                if text[lower] == "\t" { return true }
            }
            return lower == text.startIndex || separators.contains(text[text.index(before: lower)]) || edges.ends.contains(lower)
        }

        private static func isEdge(after index: String.Index, in text: String, edges: Edges) -> Bool {
            var upper = index
            while upper < text.endIndex, text[upper].isWhitespace {
                if text[upper] == "\t" { return true }
                upper = text.index(after: upper)
            }
            return upper == text.endIndex || separators.contains(text[upper]) || edges.starts.contains(upper)
        }
    }

    /// `marker` is read only for a number that has the digits of a phone number: most places that start a number do not.
    private static func isPhone(_ shape: Shape, marker readMarker: () -> Marker, hinted: Bool) -> Bool {
        let candidate = shape.candidate
        guard (7...17).contains(shape.digits.count) else { return false }
        let marker = readMarker()
        guard marker != .fax else { return false }
        // A date or a period is no phone number
        // The range of a period is in the string it was read in: read it in a string of its own, not in a slice
        let text = String(candidate)
        if let period = DateReader.periods(in: text).first, text[period.range].filter(\.isNumber).count * 2 >= shape.digits.count {
            return false
        }
        if marker == .phone || hinted { return true }
        if isPostalCode(text) { return false }
        if candidate.hasPrefix("+") || candidate.hasPrefix("0") || candidate.hasPrefix("(") { return true }
        if shape.digits.count >= 9 && candidate.contains(" ") { return true }
        return hasNorthAmericanShape(text, isAlone: shape.isAlone)
    }

    /// A postal code written with a dash: "01010-000" in Brazil, "1000-001" in Portugal, "12345-6789" in the United States.
    static func isPostalCode(_ text: String) -> Bool {
        guard let sizes = groupSizes(of: text, separatedBy: "-") else { return false }
        return [[5, 3], [4, 3], [5, 4]].contains(sizes)
    }

    /// Ten digits in the groups of the United States and Canada ("555-555-5555", "1-555-555-5555"), or ten or eleven
    /// digits without a separator. Only the dashed form is a phone number wherever it stands; the others are one only
    /// when the number is a part of the line by itself, so that a figure in a sentence is no phone number.
    private static func hasNorthAmericanShape(_ text: String, isAlone: Bool) -> Bool {
        let groups = [[3, 3, 4], [1, 3, 3, 4]]
        if let sizes = groupSizes(of: text, separatedBy: "-"), groups.contains(sizes) { return true }
        guard isAlone else { return false }
        if let sizes = groupSizes(of: text, separatedBy: "."), groups.contains(sizes) { return true }
        return (10...11).contains(text.count) && text.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// The sizes of the groups of digits between the separators, when the text is only digits and that separator.
    private static func groupSizes(of text: String, separatedBy separator: Character) -> [Int]? {
        let groups = text.split(separator: separator, omittingEmptySubsequences: false)
        guard groups.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return nil }
        return groups.map(\.count)
    }
}

import Foundation
import CVGeneratorAI

/// The counter of the drafting evaluation (#202): it puts every field of a draft in one class, against the description the
/// person wrote and the hand-written expectations of the input. It is deliberately simpler than the rules it checks
/// (ADR 0023, ADR 0028), so that it is an independent witness of them: it never calls the sanitizer or its vocabulary, and
/// it knows only words, folded for case, accents and width.
///
/// Where it cannot prove a value, the value goes to review, never to quote: a doubt must be visible. A value is invented
/// only when it is provably wrong (a word, a number or a year the description lacks, a fact of another entry).
///
/// A job or a school (an entry) owns the sentences that hold its employer or school name. A date, a job title and a place
/// of the entry are its own only when one of its sentences, that no other entry shares, says them.
enum InventedFacts {
    enum Class: String, Codable, Sendable {
        /// Found as a contiguous phrase of the description, with case, accents and punctuation folded.
        case quote
        /// Allowed without being a quote: a date reduced from a year the description gives, the literal "null".
        case derived
        /// States something the description does not: it fails the evaluation.
        case invented
        /// A level, a date in another shape, a current job and every prose field: a person reads them once per run set.
        case review
    }

    struct Finding: Codable, Equatable, Sendable {
        let path: String
        let value: String
        let kind: Class
        let reason: String
        /// What a reviewer needs beside the value: the language of a level, the job of a "current" flag.
        let context: String?
    }

    /// A year the sentence of a job or a school gives and the draft's dates for that entry do not hold.
    struct LostYear: Codable, Equatable, Hashable, Sendable {
        let entry: String
        let year: String
    }

    struct Report: Codable, Equatable, Sendable {
        /// One finding per field of the draft, in the order of the draft.
        let findings: [Finding]
        let kept: [ExpectedFact]
        let lost: [ExpectedFact]
        /// The paths of the fields that keep the person's title, in the headline or on a job.
        let titleAt: [String]
        let lostYears: [LostYear]

        var titleInHeadline: Bool { titleAt.contains("personalInfo.title") }

        var invented: [Finding] { findings.filter { $0.kind == .invented } }
        var toReview: [Finding] { findings.filter { $0.kind == .review } }

        func keeps(_ kind: ExpectedFact.Kind) -> Bool { kept.contains { $0.kind == kind } }
        func finding(at path: String) -> Finding? { findings.first { $0.path == path } }
    }

    static func count(_ cv: CVData, for input: DraftingInput) -> Report {
        count(cv, description: input.description, facts: input.facts, traps: input.traps)
    }

    static func count(_ cv: CVData, description: String, facts: [ExpectedFact] = [], traps: [String] = []) -> Report {
        let source = Source(description, cv: cv)
        let trapWords = traps.map { (trap: $0, words: words(of: $0)) }.filter { !$0.words.isEmpty }
        let names = Names(cv: cv, facts: facts)
        let leaves = Sheet.leaves(of: cv)
        let findings = leaves.map { classify($0, of: cv, against: source, traps: trapWords, names: names) }
        let kept = facts.filter { !keptPaths(of: $0, in: leaves, findings: findings, source: source).isEmpty }
        let titleAt = Set(facts.filter { $0.kind == .title }.flatMap { keptPaths(of: $0, in: leaves, findings: findings, source: source) })
        return Report(
            findings: findings, kept: kept, lost: facts.filter { !kept.contains($0) },
            titleAt: leaves.map(\.path).filter(titleAt.contains), lostYears: lostYears(of: leaves, source: source)
        )
    }

    // MARK: - Words

    /// The words of a text: the runs of letters and digits, folded for case, accents and width.
    static func words(of text: String) -> [String] {
        tokens(of: text).map(fold)
    }

    /// The sentences of a text, each as its words: a sentence ends at `. ! ? ; …` followed by a space or the end, and at a
    /// new line, so an email address or a decimal number stays whole.
    static func sentences(of text: String) -> [[String]] {
        var sentences: [[String]] = []
        var current = ""
        func end() {
            let sentence = words(of: current)
            if !sentence.isEmpty { sentences.append(sentence) }
            current = ""
        }
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            if character.isNewline {
                end()
                continue
            }
            current.append(character)
            if ".!?;…".contains(character), index + 1 == characters.count || characters[index + 1].isWhitespace { end() }
        }
        end()
        return sentences
    }

    private static func tokens(of text: String) -> [String] {
        tokensWithStarts(of: text).map(\.token)
    }

    /// The runs of letters and digits of a text, each with whether it starts a sentence: the first of the text, or the first
    /// after `. ! ? ; …` followed by a space or the end (as `sentences(of:)` ends one), or after a new line. A capital letter at
    /// the start of a sentence says nothing about a proper name.
    private static func tokensWithStarts(of text: String) -> [(token: String, initial: Bool)] {
        var found: [(token: String, initial: Bool)] = []
        var token = ""
        var tokenStartsSentence = false
        var startsSentence = true
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            if character.isLetter || character.isNumber {
                if token.isEmpty {
                    tokenStartsSentence = startsSentence
                    startsSentence = false
                }
                token.append(character)
                continue
            }
            if !token.isEmpty {
                found.append((token, tokenStartsSentence))
                token = ""
            }
            if character.isNewline {
                startsSentence = true
            } else if ".!?;…".contains(character), index + 1 == characters.count || characters[index + 1].isWhitespace {
                startsSentence = true
            }
        }
        if !token.isEmpty { found.append((token, tokenStartsSentence)) }
        return found
    }

    private static func fold(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Whether `run` occurs in `words` as a contiguous run.
    static func holds(_ words: [String], run: [String]) -> Bool {
        !starts(of: run, in: words).isEmpty
    }

    /// The positions at which `run` occurs in `words`.
    private static func starts(of run: [String], in words: [String]) -> [Int] {
        guard !run.isEmpty, run.count <= words.count else { return [] }
        return (0...(words.count - run.count)).filter { words[$0..<($0 + run.count)].elementsEqual(run) }
    }

    /// The trap that a value is a part of: the value occurs in the description, and every place it occurs overlaps an
    /// occurrence of a trap, without the value holding that trap whole. A word of the colleague's employer, or the first
    /// name in another person's email address, is a part of a trap; a word that the description also says elsewhere is not.
    private static func trapHoldingAll(
        occurrencesOf words: [String], in source: Source, traps: [(trap: String, words: [String])]
    ) -> String? {
        let places = starts(of: words, in: source.words)
        guard !places.isEmpty else { return nil }
        let spans = traps.flatMap { trap in
            starts(of: trap.words, in: source.words).map { (trap: trap.trap, range: $0..<($0 + trap.words.count)) }
        }
        var first: String?
        for place in places {
            let range = place..<(place + words.count)
            guard let span = spans.first(where: { $0.range.overlaps(range) }) else { return nil }
            first = first ?? span.trap
        }
        return first
    }

    // MARK: - The description

    /// A job or a school of the draft and the sentences of the description that name its employer or school.
    private struct Entry {
        enum Kind { case job, study }

        let kind: Kind
        let index: Int
        /// The employer or school as the draft writes it.
        let label: String
        let anchor: [String]
        /// The sentences that hold the anchor.
        let owners: [Int]
    }

    private struct Source {
        let words: [String]
        let vocabulary: Set<String>
        let sentences: [[String]]
        let entries: [Entry]
        /// The sentences that name two or more entries: what only they say belongs to no entry for sure.
        let shared: Set<Int>
        /// The sentences that name at least one entry.
        let owned: Set<Int>
        let emails: Set<String>
        /// Every run of the description that is written as a phone number: not a date, not a range of years.
        let phones: [PhoneNumber]
        /// The web addresses, domains and handles of the description, as `link(_:)` writes them.
        let addresses: [String]
        /// The domains of the email addresses of the description.
        let emailDomains: Set<String>

        init(_ description: String, cv: CVData) {
            words = InventedFacts.words(of: description)
            vocabulary = Set(words)
            sentences = InventedFacts.sentences(of: description)
            emails = Set(description.matches(of: /[\w.+-]+@[\w-]+(\.[\w-]+)+/).map { $0.output.0.lowercased() })
            phones = description.matches(of: /\+?\d[\d ()\/.-]{4,}\d/).compactMap { PhoneNumber(String($0.output)) }.filter(\.isPhoneShaped)
            let found = InventedFacts.addresses(in: description)
            addresses = found.addresses
            emailDomains = found.emailDomains

            let sentences = sentences
            func entry(_ kind: Entry.Kind, _ index: Int, _ label: String) -> Entry {
                let anchor = InventedFacts.words(of: label)
                let owners = anchor.isEmpty ? [] : sentences.indices.filter { InventedFacts.holds(sentences[$0], run: anchor) }
                return Entry(kind: kind, index: index, label: label, anchor: anchor, owners: owners)
            }
            entries = cv.experience.enumerated().map { entry(.job, $0.offset, $0.element.company) }
                + cv.education.enumerated().map { entry(.study, $0.offset, $0.element.institution ?? "") }
            var named: [Int: Int] = [:]
            for entry in entries { for owner in entry.owners { named[owner, default: 0] += 1 } }
            shared = Set(named.filter { $0.value >= 2 }.keys)
            owned = Set(named.keys)
        }

        /// The job or the school a field belongs to.
        func entry(of leaf: Sheet.Leaf) -> Entry? {
            guard let first = leaf.steps.first, let index = first.index else { return nil }
            let kind: Entry.Kind
            switch first.name {
            case "experience": kind = .job
            case "education": kind = .study
            default: return nil
            }
            return entries.first { $0.kind == kind && $0.index == index }
        }

        /// The sentences of the entry that no other entry shares.
        func ownSentences(of entry: Entry) -> [Int] {
            entry.owners.filter { !shared.contains($0) }
        }

        /// The sentences that hold the run.
        func holders(of run: [String]) -> [Int] {
            sentences.indices.filter { InventedFacts.holds(sentences[$0], run: run) }
        }

        /// A sentence with the employer or school name of the entry blanked out.
        func masked(_ sentence: Int, of entry: Entry) -> [String] {
            let words = sentences[sentence]
            let anchor = entry.anchor
            var masked: [String] = []
            var index = 0
            while index < words.count {
                if !anchor.isEmpty, index + anchor.count <= words.count, words[index..<(index + anchor.count)].elementsEqual(anchor) {
                    masked += Array(repeating: "\u{0}", count: anchor.count)
                    index += anchor.count
                } else {
                    masked.append(words[index])
                    index += 1
                }
            }
            return masked
        }
    }

    /// What a skill, a language or an interest could be mistaken for: the languages, skills, employers, schools, titles and
    /// name that the input expects or the draft holds.
    private struct Names {
        private let named: [(kind: ExpectedFact.Kind, words: [String])]

        init(cv: CVData, facts: [ExpectedFact]) {
            var named = facts.flatMap { fact in fact.forms.map { (kind: fact.kind, words: InventedFacts.words(of: $0)) } }
            named.append((.name, InventedFacts.words(of: cv.personalInfo.name ?? "")))
            named.append((.title, InventedFacts.words(of: cv.personalInfo.title ?? "")))
            named += cv.experience.flatMap { [(kind: ExpectedFact.Kind.employer, words: InventedFacts.words(of: $0.company)),
                                              (.title, InventedFacts.words(of: $0.title))] }
            named += cv.education.map { (.school, InventedFacts.words(of: $0.institution ?? "")) }
            named += cv.languages.map { (.language, InventedFacts.words(of: $0.name)) }
            named += cv.skills.map { (.skill, InventedFacts.words(of: $0.name)) }
            self.named = named.filter { !$0.words.isEmpty }
        }

        /// The first other kind of thing that is, or holds, or is a piece of, the value: a skill that is the name of a
        /// language, a language that is the name of a skill.
        func mistaken(_ words: [String], for own: ExpectedFact.Kind?) -> ExpectedFact.Kind? {
            named.first { $0.kind != own && (InventedFacts.holds($0.words, run: words) || InventedFacts.holds(words, run: $0.words)) }?.kind
        }
    }

    private static let linkPunctuation = CharacterSet(charactersIn: "()<>[]\"'.,;:!?")

    /// A web address without its scheme, `www.`, the punctuation around it, the `@` of a handle or a closing slash.
    private static func link(_ text: String) -> String {
        var address = text.lowercased().trimmingCharacters(in: linkPunctuation)
        if address.hasPrefix("@") { address.removeFirst() }
        for prefix in ["https://", "http://", "www."] where address.hasPrefix(prefix) {
            address.removeFirst(prefix.count)
        }
        while address.hasSuffix("/") { address.removeLast() }
        return address
    }

    /// Whether a text is written as a domain, with an optional path: dotted labels that end in two letters or more.
    private static func isDomainShaped(_ address: String) -> Bool {
        let host = address.prefix { $0 != "/" && $0 != "?" && $0 != "#" }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, let last = labels.last, last.count >= 2, last.allSatisfy(\.isLetter) else { return false }
        return labels.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } }
    }

    /// The addresses that a description gives: web addresses (with a scheme or `www.`), domains and `@handles`, and the
    /// domains of its email addresses. A word that is none of them is not an address.
    private static func addresses(in description: String) -> (addresses: [String], emailDomains: Set<String>) {
        var addresses: [String] = []
        var domains: Set<String> = []
        for token in description.split(whereSeparator: \.isWhitespace) {
            let text = String(token).trimmingCharacters(in: linkPunctuation)
            if let at = text.firstIndex(of: "@") {
                let rest = text[text.index(after: at)...]
                if at == text.startIndex {
                    if !rest.isEmpty, !rest.contains("@") { addresses.append(link(text)) }
                } else {
                    let domain = link(String(rest))
                    if isDomainShaped(domain) { domains.insert(domain) }
                }
                continue
            }
            let lowered = text.lowercased()
            let schemed = ["http://", "https://", "www."].contains { lowered.hasPrefix($0) }
            let address = link(text)
            if schemed || isDomainShaped(address) { addresses.append(address) }
        }
        return (addresses, domains)
    }

    /// A phone number as its digits, without the leading `+` or `00` that only say a country code follows.
    private struct PhoneNumber {
        enum Relation { case same, countryCode, part }

        let digits: String
        let international: Bool
        /// The length of the country code when it is written apart from the rest (`+39 333 ...`).
        let codeLength: Int?
        /// Only years, days and months: a range of years or a date, whatever its digits.
        let isDateLike: Bool

        init?(_ text: String) {
            let trimmed = text.drop(while: { $0.isWhitespace || $0 == "(" })
            let plus = trimmed.hasPrefix("+")
            let abroad = plus || trimmed.hasPrefix("00")
            let body = plus ? trimmed.dropFirst() : (abroad ? trimmed.dropFirst(2) : trimmed)
            let digits = String(body.filter(InventedFacts.isDigit))
            guard !digits.isEmpty else { return nil }
            self.digits = digits
            international = abroad
            let lead = body.prefix(while: InventedFacts.isDigit)
            codeLength = abroad && (1...3).contains(lead.count) && lead.count < body.count ? lead.count : nil
            let groups = body.split(whereSeparator: { !InventedFacts.isDigit($0) })
            isDateLike = groups.contains(where: Self.isYear) && groups.allSatisfy { Self.isYear($0) || Self.isDayOrMonth($0) }
        }

        /// A number of 7 to 15 digits that is no date: what the description can give as a phone number.
        var isPhoneShaped: Bool { !isDateLike && (7...15).contains(digits.count) }

        private static func isYear(_ group: Substring) -> Bool {
            group.count == 4 && (1900...2100).contains(Int(group) ?? 0)
        }

        private static func isDayOrMonth(_ group: Substring) -> Bool {
            group.count <= 2 && (Int(group) ?? 99) <= 31
        }

        /// How the number is written at home: without the country code, with or without the trunk 0.
        private var nationalForms: Set<String> {
            guard international else { return [] }
            return Set((codeLength.map { [$0] } ?? [1, 2, 3]).flatMap { length -> [String] in
                let rest = String(digits.dropFirst(length))
                guard !rest.isEmpty else { return [] }
                return rest.hasPrefix("0") ? [rest, String(rest.dropFirst())] : [rest, "0" + rest]
            })
        }

        /// How this number is the other one: the same digits, the same number with the country code added or left out, or a
        /// piece of it (six digits or more). Nil when it is none of them.
        func relation(to other: PhoneNumber) -> Relation? {
            if digits == other.digits, international == other.international { return .same }
            if international != other.international {
                let (abroad, home) = international ? (self, other) : (other, self)
                if abroad.nationalForms.contains(home.digits) { return .countryCode }
            }
            let (short, long) = digits.count <= other.digits.count ? (digits, other.digits) : (other.digits, digits)
            return short.count >= 6 && long.contains(short) ? .part : nil
        }
    }

    private static func phone(_ value: String, against source: Source) -> (Class, String) {
        guard let number = PhoneNumber(value), number.digits.count >= 6 else {
            return (.invented, "a phone number the description lacks")
        }
        let relations = source.phones.compactMap { number.relation(to: $0) }
        if relations.contains(.same) { return (.quote, "a phone number of the description") }
        if relations.contains(.countryCode) {
            return (.derived, "a phone number of the description, with the country code added or left out")
        }
        if relations.contains(.part) { return (.review, "a piece of a phone number of the description") }
        return (.invented, "a phone number the description lacks")
    }

    private static func address(_ value: String, against source: Source) -> (Class, String) {
        let address = link(value)
        if source.addresses.contains(address) { return (.quote, "an address of the description") }
        if address.count >= 3, source.addresses.contains(where: { $0.contains(address) || address.contains($0) }) {
            return (.review, "a piece of an address of the description, or more than it")
        }
        if source.emailDomains.contains(String(address.prefix { $0 != "/" })) {
            return (.review, "the domain of an email of the description")
        }
        if !address.contains("."), !address.contains("/"), holds(source.words, run: words(of: address)) {
            return (.review, "a word of the description, not an address")
        }
        return (.invented, "an address the description lacks")
    }

    // MARK: - Classes

    private enum Field {
        case nameLike, headline, jobTitle, jobLocation, degree, skill, language, interest, email, phone, link, date, level
        case current, prose
    }

    private static func field(of leaf: Sheet.Leaf) -> Field {
        switch (leaf.steps.first?.name ?? "", leaf.steps.last?.name ?? "") {
        case ("personalInfo", "email"): .email
        case ("personalInfo", "phone"): .phone
        case ("personalInfo", "website"), ("personalInfo", "linkedin"), ("personalInfo", "github"), ("certifications", "url"): .link
        case ("personalInfo", "title"): .headline
        case ("experience", "title"): .jobTitle
        case ("experience", "location"): .jobLocation
        case ("education", "degree"): .degree
        case ("skills", "name"): .skill
        case ("languages", "name"): .language
        case ("interests", _): .interest
        case (_, "startDate"), (_, "endDate"), ("certifications", "date"): .date
        case ("skills", "level"), ("languages", "proficiency"): .level
        case ("experience", "current"): .current
        case ("summary", _), (_, "description"), (_, "achievements"): .prose
        default: .nameLike
        }
    }

    private static func classify(
        _ leaf: Sheet.Leaf, of cv: CVData, against source: Source, traps: [(trap: String, words: [String])], names: Names
    ) -> Finding {
        let field = field(of: leaf)
        let value = leaf.value
        let words = words(of: value)
        func finding(_ kind: Class, _ reason: String, context: String? = nil) -> Finding {
            Finding(path: leaf.path, value: value, kind: kind, reason: reason, context: context)
        }

        if let trap = traps.first(where: { holds(words, run: $0.words) }) {
            return finding(.invented, "trap: \(trap.trap)")
        }
        if let trap = trapHoldingAll(occurrencesOf: words, in: source, traps: traps) {
            return finding(.invented, "part of a trap: \(trap)")
        }
        if words == ["null"] { return finding(.derived, "the literal null") }

        switch field {
        case .nameLike:
            guard !words.isEmpty else { return finding(.review, "no word") }
            return holds(source.words, run: words)
                ? finding(.quote, "a phrase of the description")
                : finding(.invented, "not a phrase of the description")

        case .headline:
            guard !words.isEmpty else { return finding(.review, "no word") }
            let holders = source.holders(of: words)
            if holders.isEmpty { return notOneSentence(words, source: source, finding) }
            if holders.contains(where: { !source.owned.contains($0) }) { return finding(.quote, "a phrase of the description") }
            return finding(.review, "said only in the sentence of an employer or a school")

        case .jobTitle, .jobLocation:
            guard !words.isEmpty else { return finding(.review, "no word") }
            return entryBound(words, entry: source.entry(of: leaf), source: source, isJobTitle: field == .jobTitle, finding)

        case .degree:
            // The sentence of a school holds the degree, and as much else: the counter cannot tell which phrase is the degree.
            guard !words.isEmpty else { return finding(.review, "no word") }
            let bound = entryBound(words, entry: source.entry(of: leaf), source: source, finding)
            guard bound.kind == .quote else { return bound }
            return finding(.review, "in the sentence of the school; the counter cannot tell a degree from another phrase", context: bound.context)

        case .skill, .language:
            guard !words.isEmpty else { return finding(.review, "no word") }
            guard holds(source.words, run: words) else { return finding(.invented, "not a phrase of the description") }
            if let other = names.mistaken(words, for: field == .skill ? .skill : .language) {
                return finding(.review, "the words of another kind of value (\(other.rawValue)), in this field")
            }
            return finding(.quote, "a phrase of the description")

        case .interest:
            // A hobby is a word or two of the description; a phrase of several words may be a clause with a verb in it.
            guard !words.isEmpty else { return finding(.review, "no word") }
            guard holds(source.words, run: words) else { return finding(.invented, "not a phrase of the description") }
            if let other = names.mistaken(words, for: nil) {
                return finding(.review, "the words of another kind of value (\(other.rawValue)), in this field")
            }
            return words.count == 1
                ? finding(.quote, "a word of the description")
                : finding(.review, "several words of the description; the counter cannot tell a hobby from a clause")

        case .email:
            let address = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return source.emails.contains(address)
                ? finding(.quote, "an email of the description")
                : finding(.invented, "an email the description lacks")

        case .phone:
            let (kind, reason) = phone(value, against: source)
            return finding(kind, reason)

        case .link:
            let (kind, reason) = address(value, against: source)
            return finding(kind, reason)

        case .date:
            let (kind, reason) = date(of: leaf, value: value, in: cv, against: source)
            return finding(kind, reason, context: source.entry(of: leaf)?.label)

        case .level:
            return finding(.review, "a level", context: owner(of: leaf, in: cv))

        case .current:
            return finding(.review, "a current job", context: owner(of: leaf, in: cv))

        case .prose:
            let tokens = tokensWithStarts(of: value)
            let absent = zip(tokens, words).filter { !source.vocabulary.contains($0.1) }
            let numbers = absent.filter { $0.1.contains(where: \.isNumber) }.map(\.0.token)
            let capitals = absent.filter { !$0.1.contains(where: \.isNumber) && ($0.0.token.first?.isUppercase ?? false) }
            let inside = capitals.filter { !$0.0.initial }.map(\.0.token)
            let atStart = capitals.filter { $0.0.initial }.map(\.0.token)
            let context = owner(of: leaf, in: cv)
            guard numbers.isEmpty, inside.isEmpty else {
                let reasons = [
                    numbers.isEmpty ? nil : "numbers the description lacks: \(numbers.joined(separator: ", "))",
                    inside.isEmpty ? nil : "capitalised words the description lacks: \(inside.joined(separator: ", "))",
                ]
                return finding(.invented, reasons.compactMap { $0 }.joined(separator: "; "), context: context)
            }
            if !atStart.isEmpty {
                return finding(
                    .review, "a capitalised word the description lacks at the start of a sentence: \(atStart.joined(separator: ", "))",
                    context: context
                )
            }
            return finding(.review, holds(source.words, run: words) ? "prose, a phrase of the description" : "prose", context: context)
        }
    }

    /// A phrase no single sentence holds: words the description has, in a run that crosses a sentence, are a doubt; any
    /// other phrase is invented.
    private static func notOneSentence(
        _ words: [String], source: Source, _ finding: (Class, String, String?) -> Finding
    ) -> Finding {
        holds(source.words, run: words)
            ? finding(.review, "a run of words that crosses sentences of the description", nil)
            : finding(.invented, "not a phrase of the description", nil)
    }

    private static func notOneSentence(
        _ words: [String], source: Source, _ finding: (Class, String) -> Finding
    ) -> Finding {
        notOneSentence(words, source: source) { kind, reason, _ in finding(kind, reason) }
    }

    // MARK: - Titles and places

    /// A job title or a place of a job: the employer's own sentence says it (a quote); every other source is a doubt or
    /// another entry's. The one exception is the title of a job that has ended (`isOver`), said only in a sentence that names no
    /// employer or school, such as the headline: the person said it of what they are now, so it is invented for that job.
    private static func entryBound(
        _ words: [String], entry: Entry?, source: Source, isJobTitle: Bool = false, _ finding: (Class, String, String?) -> Finding
    ) -> Finding {
        let holders = source.holders(of: words)
        if holders.isEmpty { return notOneSentence(words, source: source, finding) }
        guard let entry, !entry.owners.isEmpty else {
            return finding(.review, "no sentence of the description names this employer or school", entry?.label)
        }
        let own = source.ownSentences(of: entry)
        if own.contains(where: { holds(source.masked($0, of: entry), run: words) }) {
            return finding(.quote, "a phrase of the sentence of the entry", entry.label)
        }
        if entry.owners.contains(where: { source.shared.contains($0) && holds(source.masked($0, of: entry), run: words) }) {
            return finding(.review, "said only in a sentence that names several entries", entry.label)
        }
        if entry.owners.contains(where: { holders.contains($0) }) {
            return finding(.review, "taken from the name of the employer or the school", entry.label)
        }
        if holders.contains(where: { !source.owned.contains($0) }) {
            if isJobTitle, isOver(entry, in: source) {
                return finding(.invented, "said in a sentence that names no employer or school, for a job that has ended", entry.label)
            }
            return finding(.review, "said in a sentence that names no employer or school", entry.label)
        }
        return finding(.invented, "a phrase of the sentence of another entry", entry.label)
    }

    /// Whether the sentences of the entry itself say that it is over: they give two different years and no word of the present.
    /// The counter reads words only, with a rule of its own (the grounding reads the clauses, and also the words of ending), so a
    /// title it flags is one that the grounding has to drop for its own reasons.
    private static func isOver(_ entry: Entry, in source: Source) -> Bool {
        let own = source.ownSentences(of: entry)
        guard Set(own.flatMap { yearTokens(in: source.sentences[$0]) }).count >= 2 else { return false }
        return !own.contains { sentence in
            presentWords.contains { holds(source.sentences[sentence], run: $0.split(separator: " ").map(String.init)) }
        }
    }

    // MARK: - Dates

    private static func isYear(_ word: String) -> Bool {
        word.count == 4 && word.allSatisfy(isDigit) && (word.hasPrefix("19") || word.hasPrefix("20"))
    }

    private static func yearTokens(in words: [String]) -> [String] {
        words.filter(isYear)
    }

    /// The date of the other end of the same job or school.
    private static func sibling(of leaf: Sheet.Leaf, in cv: CVData) -> String? {
        guard let first = leaf.steps.first, let index = first.index, let role = leaf.steps.last?.name else { return nil }
        switch (first.name, role) {
        case ("experience", "startDate") where cv.experience.indices.contains(index): return cv.experience[index].endDate
        case ("experience", "endDate") where cv.experience.indices.contains(index): return cv.experience[index].startDate
        case ("education", "startDate") where cv.education.indices.contains(index): return cv.education[index].endDate
        case ("education", "endDate") where cv.education.indices.contains(index): return cv.education[index].startDate
        default: return nil
        }
    }

    /// A date, by the sentences that can back it: the entry's own, or for a certification those that hold its years. The
    /// first provable mistake decides; failing that, the first doubt; failing that, the shape of the value.
    private static func date(of leaf: Sheet.Leaf, value: String, in cv: CVData, against source: Source) -> (Class, String) {
        let words = words(of: value)
        let role = leaf.steps.last?.name
        let entry = source.entry(of: leaf)
        let own = entry.map { source.ownSentences(of: $0) } ?? []
        let ownYears = Set(own.flatMap { yearTokens(in: source.sentences[$0]) })

        if presentWords.contains(words.joined(separator: " ")) {
            return presentSaid(words, by: entry, own: own, against: source)
        }

        let years = yearTokens(in: words)
        if years.isEmpty {
            let numbers = words.filter { $0.contains(where: \.isNumber) && !source.vocabulary.contains($0) }
            if !numbers.isEmpty { return (.invented, "numbers the description lacks: \(numbers.joined(separator: ", "))") }
            if own.contains(where: { holds(source.sentences[$0], run: words) }) { return (.quote, "a phrase of the sentence of the entry") }
            return (.review, "a date in another shape")
        }
        let absent = years.filter { !source.vocabulary.contains($0) }
        guard absent.isEmpty else { return (.invented, "a year the description lacks: \(absent.joined(separator: ", "))") }

        let backing: [Int] = entry == nil
            ? source.sentences.indices.filter { sentence in years.contains { source.sentences[sentence].contains($0) } }
            : own
        let iso = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .wholeMatch(of: /([0-9]{4})(?:-([0-9]{2})(?:-([0-9]{2}))?)?/)
        var invented: [String] = []
        var review: [String] = []

        if iso == nil {
            let pool = backing.isEmpty ? source.vocabulary : Set(backing.flatMap { source.sentences[$0] })
            let numbers = words.filter { $0.contains(where: \.isNumber) && !isYear($0) && !pool.contains($0) }
            if !numbers.isEmpty { invented.append("numbers the sentence of the entry lacks: \(numbers.joined(separator: ", "))") }
        }

        if let entry {
            if entry.owners.isEmpty {
                review.append("no sentence of the description names this employer or school")
            } else if own.isEmpty {
                review.append("the sentence that names this entry names another entry too")
            } else {
                let distinct = years.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                for year in distinct {
                    let holders = source.holders(of: [year])
                    if holders.contains(where: { own.contains($0) }) { continue }
                    if holders.contains(where: { entry.owners.contains($0) }) {
                        review.append("\(year) is said only in a sentence that names several entries")
                    } else if holders.contains(where: { !source.owned.contains($0) }) {
                        review.append("\(year) is said in a sentence that names no employer or school")
                    } else {
                        invented.append("\(year) is a year of another entry")
                    }
                }
            }
        }

        let other = sibling(of: leaf, in: cv).map { yearTokens(in: InventedFacts.words(of: $0)) } ?? []
        let startYears = role == "endDate" ? other : years
        let endYears = role == "startDate" ? other : years
        if let start = startYears.first.flatMap({ Int($0) }), let end = endYears.last.flatMap({ Int($0) }), start > end {
            invented.append("it starts after it ends: \(start) after \(end)")
        }

        if let iso, let monthText = iso.output.2, !backing.isEmpty {
            let month = Int(monthText) ?? 0
            let day = iso.output.3.flatMap { Int($0) }
            if !(1...12).contains(month) {
                invented.append("not a month: \(monthText)")
            } else if let day, !(1...31).contains(day) {
                invented.append("not a day: \(day)")
            } else {
                let backed = backs(month: month, day: day, year: String(iso.output.1), in: backing.map { source.sentences[$0] })
                if !backed.month {
                    invented.append("a month the sentence does not give: \(monthText)")
                } else if let day, !backed.day {
                    invented.append("a day the sentence does not give: \(day)")
                }
            }
        }

        if let entry, entry.kind == .study, role == "startDate", ownYears.count == 1, let year = years.first,
           completionOnly(year, in: own.map { source.sentences[$0] }) {
            invented.append("\(year) is said only as the completion year of the studies")
        }

        if entry != nil, years.count == 1, ownYears.count >= 2 {
            let sorted = ownYears.sorted()
            if role == "startDate", years[0] != sorted.first { review.append("the start of the entry is not its earliest year") }
            if role == "endDate", years[0] != sorted.last { review.append("the end of the entry is not its latest year") }
        }

        if let reason = invented.first { return (.invented, reason) }
        if let reason = review.first { return (.review, reason) }
        if backing.contains(where: { holds(source.sentences[$0], run: words) }) { return (.quote, "a phrase of the sentence of the entry") }
        if iso != nil || words.allSatisfy(isYear) { return (.derived, "reduced from a year of the sentence of the entry") }
        return (.review, "a date in another shape")
    }

    /// Whether every mention of `year` in the sentences of a school is the year the studies were completed: a word of completion
    /// before it, or right after it, and no word of a start that dates this year. A verb of a start anywhere before the year
    /// dates it ("I started my graduate studies in 2013"), and so does a preposition of a start right before it ("from 2013"),
    /// but not one far before it ("graduated from Gamma University in 2013"). Such a year is never the start of the studies,
    /// and the counter does not borrow the production rule to say so.
    private static func completionOnly(_ year: String, in sentences: [[String]]) -> Bool {
        var mentions = 0
        for sentence in sentences {
            for index in sentence.indices where sentence[index] == year {
                mentions += 1
                let before = sentence[..<index]
                let after = sentence[(index + 1)...].prefix(2)
                // A verb of a start dates the year unless a verb of completion stands between them: "I started to study and
                // graduated in 2013" dates the graduation, "I started my graduate studies in 2013" dates the start.
                let verb = before.lastIndex(where: startVerbs.contains)
                let started = verb.map { !before[$0...].contains(where: completionVerbs.contains) } ?? false
                    || before.suffix(2).contains(where: startPrepositions.contains)
                let completed = before.contains(where: completionWords.contains) || after.contains(where: completionWords.contains)
                if started || !completed { return false }
            }
        }
        return mentions > 0
    }

    /// The words that say the studies were completed, in the six languages of the app, folded.
    private static let completionWords: Set<String> = [
        "graduated", "graduate", "graduating", "graduation", "finished", "completed", "completing", "completion",
        "laureato", "laureata", "laureai", "laurea", "diplomato", "diplomata", "diplomai", "concluso", "conclusi", "terminato",
        "abgeschlossen", "abschluss", "schloss", "beendet", "absolviert", "graduiert",
        "graduado", "graduada", "licenciado", "licenciada", "titulado", "titulada", "termine", "terminado", "finalizado",
        "diplome", "diplomee", "obtenu", "fini",
        "formado", "formada", "formei", "graduei", "concluido", "concluida", "conclui", "terminei",
    ]

    /// The verbs that say the studies were completed, folded: a subset of the words of completion, with no noun in it.
    private static let completionVerbs: Set<String> = [
        "graduated", "finished", "completed", "laureato", "laureata", "laureai", "diplomato", "diplomata", "diplomai", "concluso",
        "conclusi", "terminato", "abgeschlossen", "schloss", "beendet", "absolviert", "graduiert", "graduado", "graduada",
        "licenciado", "licenciada", "titulado", "titulada", "termine", "terminado", "finalizado", "obtenu", "diplome", "diplomee",
        "formado", "formada", "formei", "graduei", "concluido", "concluida", "conclui", "terminei",
    ]

    /// The verbs that say the studies began, in the six languages of the app, folded: they date a year wherever they stand before it.
    private static let startVerbs: Set<String> = [
        "started", "starting", "began", "begun", "enrolled",
        "iniziato", "iniziata", "iniziai",
        "begann", "angefangen", "begonnen",
        "comence", "empece",
        "commence", "debute",
        "iniciei", "comecei",
    ]

    /// The prepositions that say the studies began, folded: they date the year only right before it.
    private static let startPrepositions: Set<String> = [
        "from", "since", "dal", "dall", "dalla", "seit", "von", "desde", "depuis", "du",
    ]

    /// What the description says of the word of the present in a date. The present is the entry's own only when a sentence of the
    /// entry itself holds the word, a quote. Nothing else proves it, and nothing proves it wrong either, so every other case is a
    /// doubt for a person: never a derivation and never a mistake. The counter reads words, not tenses: "since 2019" dates the
    /// start of a job, and "I had worked at Alpha Corp since 2019 before leaving" says that it ended, so a job that goes on says
    /// so with a tense that no word shows. A date no entry owns (a certification) has no sentence to say it.
    private static func presentSaid(
        _ words: [String], by entry: Entry?, own: [Int], against source: Source
    ) -> (Class, String) {
        let unsaid = (Class.review, "the present is not said by a sentence of the entry")
        guard let entry else { return unsaid }
        let holders = source.holders(of: words)
        if own.contains(where: { holds(source.masked($0, of: entry), run: words) }) {
            return (.quote, "a phrase of the sentence of the entry")
        }
        if holders.isEmpty { return unsaid }
        if entry.owners.isEmpty { return (.review, "no sentence of the description names this employer or school") }
        if entry.owners.contains(where: { source.shared.contains($0) && holds(source.masked($0, of: entry), run: words) }) {
            return (.review, "the present is said only in a sentence that names several entries")
        }
        if entry.owners.contains(where: { holders.contains($0) }) {
            return (.review, "the present is taken from the name of the employer or the school")
        }
        if holders.contains(where: { !source.owned.contains($0) }) {
            return (.review, "the present is said in a sentence that names no employer or school")
        }
        // Said only of another entry: the word may be another entry's, or only another way to say it.
        if own.isEmpty { return (.review, "the present is said of another entry, and no sentence of the description names this one alone") }
        return (.review, "the present is said only of another entry")
    }

    /// Whether the sentences give the month, and the day, of a year: a month name (in full, in the six languages) within
    /// three words of the year, or a number of one or two digits within two, that has no other year nearer; a day is another
    /// number of one or two digits within three.
    private static func backs(month: Int, day: Int?, year: String, in sentences: [[String]]) -> (month: Bool, day: Bool) {
        var backedMonth = false
        var backedDay = false
        for sentence in sentences {
            let yearAt = sentence.indices.filter { isYear(sentence[$0]) }
            for position in yearAt where sentence[position] == year {
                func attached(_ index: Int) -> Bool {
                    let nearest = yearAt.map { abs($0 - index) }.min() ?? Int.max
                    return abs(position - index) == nearest
                }
                let months = sentence.indices.filter { index in
                    guard !isYear(sentence[index]), attached(index) else { return false }
                    let word = sentence[index]
                    let distance = abs(position - index)
                    if monthNames[word] == month { return distance <= 3 }
                    return distance <= 2 && isSmallNumber(word) && Int(word) == month
                }
                if months.isEmpty { continue }
                backedMonth = true
                guard let day else { continue }
                let days = sentence.indices.filter { index in
                    isSmallNumber(sentence[index]) && Int(sentence[index]) == day && abs(position - index) <= 3
                }
                if days.contains(where: { candidate in months.contains { $0 != candidate } }) { backedDay = true }
            }
        }
        return (backedMonth, backedDay)
    }

    private static func isSmallNumber(_ word: String) -> Bool {
        (1...2).contains(word.count) && word.allSatisfy(isDigit)
    }

    /// The months in full in the six languages of the app, folded.
    private static let monthNames: [String: Int] = {
        let names: [[String]] = [
            ["january", "gennaio", "januar", "janner", "enero", "janvier", "janeiro"],
            ["february", "febbraio", "februar", "febrero", "fevrier", "fevereiro"],
            ["march", "marzo", "marz", "mars", "marco"],
            ["april", "aprile", "abril", "avril"],
            ["may", "maggio", "mai", "mayo", "maio"],
            ["june", "giugno", "juni", "junio", "juin", "junho"],
            ["july", "luglio", "juli", "julio", "juillet", "julho"],
            ["august", "agosto", "aout"],
            ["september", "settembre", "septiembre", "setiembre", "septembre", "setembro"],
            ["october", "ottobre", "oktober", "octubre", "octobre", "outubro"],
            ["november", "novembre", "noviembre", "novembro"],
            ["december", "dicembre", "dezember", "diciembre", "decembre", "dezembro"],
        ]
        var months: [String: Int] = [:]
        for (index, forms) in names.enumerated() {
            for form in forms { months[fold(form)] = index + 1 }
        }
        return months
    }()

    private static func isDigit(_ character: Character) -> Bool {
        ("0"..."9").contains(character)
    }

    /// "Present" and its translations in the six languages of the app, folded.
    private static let presentWords: Set<String> = [
        "present", "current", "currently", "now", "today", "ongoing", "to date", "to present",
        "presente", "oggi", "ad oggi", "a oggi", "attuale", "in corso",
        "heute", "bis heute", "aktuell", "jetzt", "gegenwart", "derzeit",
        "actualidad", "la actualidad", "actual", "actualmente", "hoy", "hasta hoy", "hasta la actualidad",
        "aujourd hui", "jusqu a aujourd hui", "actuel", "actuelle", "en cours", "a ce jour",
        "atual", "atualmente", "hoje", "ate hoje", "ate ao presente", "o presente",
    ]

    /// The language of a level, the skill of a level, or the job of a "current" flag.
    private static func owner(of leaf: Sheet.Leaf, in cv: CVData) -> String? {
        guard let first = leaf.steps.first, let index = first.index else { return nil }
        switch first.name {
        case "languages" where cv.languages.indices.contains(index): return cv.languages[index].name
        case "skills" where cv.skills.indices.contains(index): return cv.skills[index].name
        case "experience" where cv.experience.indices.contains(index):
            let job = cv.experience[index]
            return job.title.isEmpty ? job.company : "\(job.title) at \(job.company)"
        case "education" where cv.education.indices.contains(index):
            let study = cv.education[index]
            let degree = study.degree ?? ""
            let institution = study.institution ?? ""
            if degree.isEmpty || institution.isEmpty { return degree.isEmpty ? (institution.isEmpty ? nil : institution) : degree }
            return "\(degree) at \(institution)"
        default: return nil
        }
    }

    // MARK: - Kept and lost

    /// The fields that keep a fact: a field of its kind that holds one of its forms and is not invented. A title kept on a
    /// job counts only when a sentence of the description names that job's employer.
    private static func keptPaths(
        of fact: ExpectedFact, in leaves: [Sheet.Leaf], findings: [Finding], source: Source
    ) -> [String] {
        let fields: Set<String> = switch fact.kind {
        case .name: ["personalInfo.name"]
        case .title: ["personalInfo.title", "experience.title"]
        case .employer: ["experience.company"]
        case .school: ["education.institution"]
        case .language: ["languages.name"]
        case .skill: ["skills.name"]
        }
        let forms = fact.forms.map(words(of:))
        return zip(leaves, findings).compactMap { leaf, finding in
            let field = "\(leaf.steps.first?.name ?? "").\(leaf.steps.last?.name ?? "")"
            guard fields.contains(field), finding.kind != .invented else { return nil }
            let words = words(of: leaf.value)
            guard forms.contains(where: { holds(words, run: $0) }) else { return nil }
            if field == "experience.title", source.entry(of: leaf)?.owners.isEmpty ?? true { return nil }
            return leaf.path
        }
    }

    /// The years the sentence of a job or a school gives, that no date of that entry in the draft holds.
    private static func lostYears(of leaves: [Sheet.Leaf], source: Source) -> [LostYear] {
        source.entries.flatMap { entry -> [LostYear] in
            let own = source.ownSentences(of: entry)
            guard !own.isEmpty else { return [] }
            let given = Set(own.flatMap { yearTokens(in: source.sentences[$0]) })
            let held = Set(leaves.filter { leaf in
                source.entry(of: leaf).map { $0.kind == entry.kind && $0.index == entry.index } ?? false
                    && (leaf.steps.last?.name == "startDate" || leaf.steps.last?.name == "endDate")
            }.flatMap { yearTokens(in: words(of: $0.value)) })
            return given.subtracting(held).sorted().map { LostYear(entry: entry.label, year: $0) }
        }
    }
}

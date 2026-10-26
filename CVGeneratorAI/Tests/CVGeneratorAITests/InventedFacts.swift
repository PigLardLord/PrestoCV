import Foundation
import CVGeneratorAI

/// The counter of the drafting evaluation (#202): it puts every field of a draft in one class, against the description the
/// person wrote and the hand-written expectations of the input. It is deliberately simpler than the rules it checks
/// (ADR 0023, ADR 0028), so that it is an independent witness of them: it never calls the sanitizer or its vocabulary, and
/// it knows only words, folded for case, accents and width.
enum InventedFacts {
    enum Class: String, Codable, Sendable {
        /// Found as a contiguous phrase of the description, with case, accents and punctuation folded.
        case quote
        /// Allowed without being a quote: a date reduced from a year the description gives, "Present" and its
        /// translations, the literal "null".
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

    struct Report: Codable, Equatable, Sendable {
        /// One finding per field of the draft, in the order of the draft.
        let findings: [Finding]
        let kept: [ExpectedFact]
        let lost: [ExpectedFact]

        var invented: [Finding] { findings.filter { $0.kind == .invented } }
        var toReview: [Finding] { findings.filter { $0.kind == .review } }

        func keeps(_ kind: ExpectedFact.Kind) -> Bool { kept.contains { $0.kind == kind } }
        func finding(at path: String) -> Finding? { findings.first { $0.path == path } }
    }

    static func count(_ cv: CVData, for input: DraftingInput) -> Report {
        count(cv, description: input.description, facts: input.facts, traps: input.traps)
    }

    static func count(_ cv: CVData, description: String, facts: [ExpectedFact] = [], traps: [String] = []) -> Report {
        let source = Source(description)
        let trapWords = traps.map { (trap: $0, words: words(of: $0)) }.filter { !$0.words.isEmpty }
        let leaves = Sheet.leaves(of: cv)
        let findings = leaves.map { classify($0, of: cv, against: source, traps: trapWords) }
        let kept = facts.filter { isKept($0, in: leaves) }
        return Report(findings: findings, kept: kept, lost: facts.filter { !kept.contains($0) })
    }

    // MARK: - Words

    /// The words of a text: the runs of letters and digits, folded for case, accents and width.
    static func words(of text: String) -> [String] {
        tokens(of: text).map(fold)
    }

    private static func tokens(of text: String) -> [String] {
        var tokens: [String] = []
        var token = ""
        for character in text {
            if character.isLetter || character.isNumber {
                token.append(character)
            } else if !token.isEmpty {
                tokens.append(token)
                token = ""
            }
        }
        if !token.isEmpty { tokens.append(token) }
        return tokens
    }

    private static func fold(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Whether `run` occurs in `words` as a contiguous run.
    private static func holds(_ words: [String], run: [String]) -> Bool {
        guard !run.isEmpty, run.count <= words.count else { return false }
        return (0...(words.count - run.count)).contains { start in words[start..<(start + run.count)].elementsEqual(run) }
    }

    // MARK: - The description

    private struct Source {
        let words: [String]
        let vocabulary: Set<String>
        let emails: Set<String>
        /// The digits of every run that looks like a phone number.
        let phones: [String]
        let links: Set<String>

        init(_ description: String) {
            words = InventedFacts.words(of: description)
            vocabulary = Set(words)
            emails = Set(description.matches(of: /[\w.+-]+@[\w-]+(\.[\w-]+)+/).map { $0.output.0.lowercased() })
            phones = description.matches(of: /\+?\d[\d ()\/.-]{4,}\d/).map { String($0.output.filter(InventedFacts.isDigit)) }
            links = Set(description.split(whereSeparator: \.isWhitespace).map { InventedFacts.link(String($0)) })
        }
    }

    /// A web address without its scheme, `www.`, the punctuation around it or a closing slash.
    private static func link(_ text: String) -> String {
        var address = text.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "()<>[]\"'.,;:!?"))
        for prefix in ["https://", "http://", "www."] where address.hasPrefix(prefix) {
            address.removeFirst(prefix.count)
        }
        while address.hasSuffix("/") { address.removeLast() }
        return address
    }

    // MARK: - Classes

    private enum Field {
        case nameLike, email, phone, link, date, level, current, prose
    }

    private static func field(of leaf: Sheet.Leaf) -> Field {
        switch (leaf.steps.first?.name ?? "", leaf.steps.last?.name ?? "") {
        case ("personalInfo", "email"): .email
        case ("personalInfo", "phone"): .phone
        case ("personalInfo", "website"), ("personalInfo", "linkedin"), ("personalInfo", "github"), ("certifications", "url"): .link
        case (_, "startDate"), (_, "endDate"), ("certifications", "date"): .date
        case ("skills", "level"), ("languages", "proficiency"): .level
        case ("experience", "current"): .current
        case ("summary", _), (_, "description"), (_, "achievements"): .prose
        default: .nameLike
        }
    }

    private static func classify(
        _ leaf: Sheet.Leaf, of cv: CVData, against source: Source, traps: [(trap: String, words: [String])]
    ) -> Finding {
        let field = field(of: leaf)
        let value = leaf.value
        let words = words(of: value)
        func finding(_ kind: Class, _ reason: String, context: String? = nil) -> Finding {
            Finding(path: leaf.path, value: value, kind: kind, reason: reason, context: context)
        }

        if field != .date, let trap = traps.first(where: { holds(words, run: $0.words) }) {
            return finding(.invented, "trap: \(trap.trap)")
        }
        if words == ["null"] { return finding(.derived, "the literal null") }

        switch field {
        case .nameLike:
            guard !words.isEmpty else { return finding(.review, "no word") }
            return holds(source.words, run: words)
                ? finding(.quote, "a phrase of the description")
                : finding(.invented, "not a phrase of the description")

        case .email:
            let address = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return source.emails.contains(address)
                ? finding(.quote, "an email of the description")
                : finding(.invented, "an email the description lacks")

        case .phone:
            let digits = String(value.filter(isDigit))
            let given = digits.count >= 6 && source.phones.contains { $0.hasSuffix(digits) }
            return given ? finding(.quote, "a phone number of the description") : finding(.invented, "a phone number the description lacks")

        case .link:
            return source.links.contains(link(value))
                ? finding(.quote, "an address of the description")
                : finding(.invented, "an address the description lacks")

        case .date:
            let (kind, reason) = date(words, value: value, against: source)
            return finding(kind, reason)

        case .level:
            return finding(.review, "a level", context: owner(of: leaf, in: cv))

        case .current:
            return finding(.review, "a current job", context: owner(of: leaf, in: cv))

        case .prose:
            let originals = tokens(of: value)
            let absent = zip(originals, words).filter { !source.vocabulary.contains($0.1) }
            let numbers = absent.filter { $0.1.contains(where: \.isNumber) }.map(\.0)
            let capitals = absent.filter { !$0.1.contains(where: \.isNumber) && ($0.0.first?.isUppercase ?? false) }.map(\.0)
            guard numbers.isEmpty, capitals.isEmpty else {
                let reasons = [
                    numbers.isEmpty ? nil : "numbers the description lacks: \(numbers.joined(separator: ", "))",
                    capitals.isEmpty ? nil : "capitalised words the description lacks: \(capitals.joined(separator: ", "))",
                ]
                return finding(.invented, reasons.compactMap { $0 }.joined(separator: "; "))
            }
            return finding(.review, holds(source.words, run: words) ? "prose, a phrase of the description" : "prose")
        }
    }

    private static func date(_ words: [String], value: String, against source: Source) -> (Class, String) {
        if holds(source.words, run: words) { return (.quote, "a phrase of the description") }
        if presentWords.contains(words.joined(separator: " ")) { return (.derived, "the present") }

        let years = words.filter { $0.count == 4 && $0.allSatisfy(isDigit) && ($0.hasPrefix("19") || $0.hasPrefix("20")) }
        let missingYears = years.filter { !source.vocabulary.contains($0) }
        guard missingYears.isEmpty else { return (.invented, "a year the description lacks: \(missingYears.joined(separator: ", "))") }
        if !years.isEmpty {
            let isoDate = value.trimmingCharacters(in: .whitespacesAndNewlines).wholeMatch(of: /\d{4}(-\d{2}(-\d{2})?)?/) != nil
            return isoDate ? (.derived, "a year of the description") : (.review, "a date in another shape")
        }
        let numbers = words.filter { $0.contains(where: \.isNumber) && !source.vocabulary.contains($0) }
        guard numbers.isEmpty else { return (.invented, "numbers the description lacks: \(numbers.joined(separator: ", "))") }
        return (.review, "a date in another shape")
    }

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
        default: return nil
        }
    }

    // MARK: - Kept and lost

    private static func isKept(_ fact: ExpectedFact, in leaves: [Sheet.Leaf]) -> Bool {
        let fields: Set<String> = switch fact.kind {
        case .name: ["personalInfo.name"]
        case .title: ["personalInfo.title", "experience.title"]
        case .employer: ["experience.company"]
        case .school: ["education.institution"]
        case .language: ["languages.name"]
        case .skill: ["skills.name"]
        }
        let forms = fact.forms.map(words(of:))
        return leaves.contains { leaf in
            let field = "\(leaf.steps.first?.name ?? "").\(leaf.steps.last?.name ?? "")"
            guard fields.contains(field) else { return false }
            let words = words(of: leaf.value)
            return forms.contains { holds(words, run: $0) }
        }
    }
}

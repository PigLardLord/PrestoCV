import PrestoCVDomain

/// The final gate of an import (ADR 0027): every value must be the text of its spans, or what its closed rule reads
/// there. The readers build values that way; the gate checks it, and a value that fails it does not reach the CV: its
/// text stays visible as text not imported instead.
enum ImportGrounding {

    /// The result with only the values that pass the gate; the fields it refused are listed in `ungrounded`.
    static func enforced(_ result: ImportResult) -> ImportResult {
        var gate = Gate(document: result.document)
        var checked = result
        checked.cv = gate.verified(result.cv)
        checked.ungrounded += gate.violations
        checked.unplaced += gate.dropped.map { UnplacedText(section: .unknown, heading: nil, text: result.document.text(of: $0), span: $0) }
        checked.unplaced.sort { $0.span < $1.span }
        return checked
    }

    private struct Gate {
        let document: SourceDocument
        var violations: [String] = []
        var dropped: [SourceSpan] = []

        mutating func verified(_ cv: ImportedCV) -> ImportedCV {
            var cv = cv
            let rules = Rules(document: document)
            let quote = rules.quote, isLink = rules.isLink, isPeriod = rules.isPeriod, isLevel = rules.isLevel, isYear = rules.isYear
            cv.person.name = keep(cv.person.name, "name", quote)
            cv.person.title = keep(cv.person.title, "title", quote)
            cv.person.location = keep(cv.person.location, "location", quote)
            cv.person.summary = keep(cv.person.summary, "summary", quote)
            cv.person.email = keep(cv.person.email, "email", rules.isEmail)
            cv.person.phone = keep(cv.person.phone, "phone", rules.isPhone)
            cv.person.links = cv.person.links.filter { keep($0.address, "link", isLink) != nil }
            for index in cv.experience.indices {
                cv.experience[index].role = keep(cv.experience[index].role, "experience role", quote)
                cv.experience[index].employer = keep(cv.experience[index].employer, "experience employer", quote)
                cv.experience[index].location = keep(cv.experience[index].location, "experience location", quote)
                cv.experience[index].period = keep(cv.experience[index].period, "experience period", isPeriod)
                cv.experience[index].details = cv.experience[index].details.filter { keep($0, "experience detail", quote) != nil }
            }
            for index in cv.education.indices {
                cv.education[index].degree = keep(cv.education[index].degree, "education degree", quote)
                cv.education[index].school = keep(cv.education[index].school, "education school", quote)
                cv.education[index].location = keep(cv.education[index].location, "education location", quote)
                cv.education[index].period = keep(cv.education[index].period, "education period", isPeriod)
                cv.education[index].details = cv.education[index].details.filter { keep($0, "education detail", quote) != nil }
            }
            cv.skills = cv.skills.filter { keep($0, "skill", quote) != nil }
            cv.interests = cv.interests.filter { keep($0, "interest", quote) != nil }
            cv.languages = cv.languages.compactMap { language in
                guard var kept = keep(Optional(language.name), "language", quote).map({ ImportedLanguage(name: $0, level: language.level, levelWords: language.levelWords) }) else {
                    return nil
                }
                kept.level = keep(language.level, "language level", isLevel)
                kept.levelWords = keep(language.levelWords, "language level words", quote)
                return kept
            }
            cv.certifications = cv.certifications.compactMap { certification in
                guard let name = keep(Optional(certification.name), "certification", quote) else { return nil }
                var kept = ImportedCertification(name: name)
                kept.issuer = keep(certification.issuer, "certification issuer", quote)
                kept.year = keep(certification.year, "certification year", isYear)
                kept.link = keep(certification.link, "certification link", isLink)
                kept.description = keep(certification.description, "certification description", quote)
                return kept
            }
            return cv
        }

        private mutating func keep<Value>(_ value: Sourced<Value>?, _ field: String, _ isGrounded: (Sourced<Value>) -> Bool) -> Sourced<Value>? {
            guard let value else { return nil }
            let inText = value.spans.allSatisfy { $0.lowerBound >= 0 && $0.upperBound <= document.scalarCount && !$0.isEmpty }
            if inText && !value.spans.isEmpty && isGrounded(value) { return value }
            violations.append(field)
            dropped += value.spans.filter { $0.lowerBound >= 0 && $0.upperBound <= document.scalarCount }
            return nil
        }
    }

    /// The rules each kind of value is checked by.
    private struct Rules {
        let document: SourceDocument

        func quote(_ value: Sourced<String>) -> Bool {
            guard value.reading == nil else { return false }
            return [" ", "\n", ", "].contains { document.text(of: value.spans, joinedBy: $0) == value.value }
        }

        func isEmail(_ value: Sourced<EmailAddress>) -> Bool {
            value.reading == nil && EmailAddress(document.text(of: value.spans, joinedBy: "")) == value.value
        }

        func isPhone(_ value: Sourced<PhoneNumber>) -> Bool {
            value.reading == nil && PhoneNumber(document.text(of: value.spans, joinedBy: "")) == value.value
        }

        func isLink(_ value: Sourced<WebLink>) -> Bool {
            let text = document.text(of: value.spans, joinedBy: "")
            switch value.reading {
            case nil: return WebLink(text) == value.value
            case .webAddress?: return WebLink("https://" + text) == value.value
            default: return false
            }
        }

        func isPeriod(_ value: Sourced<ImportedPeriod>) -> Bool {
            let text = document.text(of: value.spans, joinedBy: "")
            guard value.reading == .period, let match = DateReader.periods(in: text).first else { return false }
            return match.period == value.value && text[match.range] == text[...]
        }

        func isLevel(_ value: Sourced<LanguageProficiency>) -> Bool {
            guard value.reading == .languageLevel else { return false }
            return value.spans.allSatisfy { span in
                let text = document.text(of: span)
                if value.value == .native { return LanguageReader.isNative(text) }
                return LanguageReader.cefrLevels(in: Piece(text: text, span: span)).contains { $0.1 == value.value }
            }
        }

        func isYear(_ value: Sourced<Int>) -> Bool {
            let text = document.text(of: value.spans, joinedBy: "")
            guard value.reading == .year, let match = DateReader.periods(in: text).first else { return false }
            if case .date(let end)? = match.period.end, end.year == value.value { return true }
            return match.period.start.year == value.value
        }
    }
}

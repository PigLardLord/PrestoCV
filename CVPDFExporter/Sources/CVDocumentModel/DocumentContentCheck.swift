import Foundation

/// Walks a document and checks every text, count, date and rating in it, in document order. The total size of the
/// text read so far is the walk's only state; the rules for a single value are in `DocumentValueRules`.
struct DocumentContentCheck {
    typealias Invalid = CVDocumentValidator.Invalid

    /// Bounds in UTF-8 bytes, not characters: a letter followed by any number of combining marks is one character.
    static let maxTextBytes = 16_384, maxDocumentTextBytes = 262_144
    private typealias Rules = DocumentValueRules

    private var textBytes = 0

    mutating func check(_ document: CVDocument) throws(Invalid) {
        try checkPerson(document.person, language: document.language)
        try Rules.requireCount(document.sections.count, "sections")
        for section in document.sections { try check(section) }
    }

    // MARK: Person and sections

    private mutating func checkPerson(_ person: Person, language: String) throws(Invalid) {
        guard !person.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Invalid(reason: "name is required") }
        try checkText(language, "language")
        try checkText(person.name, "name")
        try checkText(person.professionalTitle, "title")
        try checkText(person.email, "email")
        try checkText(person.phone, "phone")
        try checkText(person.location, "location")
        try checkText(person.website, "website")
    }

    private mutating func check(_ section: Section) throws(Invalid) {
        switch section {
        case .summary(let text): try checkText(text, "summary")
        case .experience(let items): try checkExperience(items)
        case .education(let items): try checkEducation(items)
        case .skills(let items): try checkSkills(items)
        case .languages(let items): try checkLanguages(items)
        case .certifications(let items): try checkCertifications(items)
        case .profiles(let items): try checkProfiles(items)
        case .interests(let items): try checkInterests(items)
        }
    }

    private mutating func checkExperience(_ items: [ExperienceItem]) throws(Invalid) {
        try Rules.requireCount(items.count, "entries")
        for item in items {
            try checkText(item.role, "role")
            try checkText(item.company, "company")
            try checkText(item.location, "location")
            try checkText(item.description, "description")
            try Rules.requirePeriod(item.period)
        }
    }

    private mutating func checkEducation(_ items: [EducationItem]) throws(Invalid) {
        try Rules.requireCount(items.count, "entries")
        for item in items {
            try checkText(item.degree, "degree")
            try checkText(item.school, "school")
            try checkText(item.description, "description")
            try Rules.requirePeriod(item.period)
        }
    }

    private mutating func checkSkills(_ items: [SkillItem]) throws(Invalid) {
        try Rules.requireCount(items.count, "skills")
        for item in items {
            try checkText(item.name, "skill")
            try Rules.requireRating(item.rating)
        }
    }

    private mutating func checkLanguages(_ items: [LanguageItem]) throws(Invalid) {
        try Rules.requireCount(items.count, "languages")
        for item in items { try checkText(item.language, "language") }
    }

    private mutating func checkCertifications(_ items: [CertificationItem]) throws(Invalid) {
        try Rules.requireCount(items.count, "certifications")
        for item in items {
            try checkText(item.name, "certification")
            try checkText(item.issuer, "issuer")
            try checkText(item.url, "url")
            try checkText(item.description, "description")
            try Rules.requireYear(item.year)
        }
    }

    private mutating func checkProfiles(_ items: [ProfileLink]) throws(Invalid) {
        try Rules.requireCount(items.count, "profiles")
        for item in items {
            try checkText(item.platform, "platform")
            try checkText(item.url, "url")
        }
    }

    private mutating func checkInterests(_ items: [String]) throws(Invalid) {
        try Rules.requireCount(items.count, "interests")
        for item in items { try checkText(item, "interest") }
    }

    // MARK: Text

    private mutating func checkText(_ text: String?, _ what: String) throws(Invalid) {
        guard let text else { return }
        textBytes += text.utf8.count
        guard text.utf8.count <= Self.maxTextBytes, textBytes <= Self.maxDocumentTextBytes, !Rules.hasForbiddenScalar(text) else {
            throw Invalid(reason: "\(what) is too long, the document is too large, or it has control characters")
        }
    }
}

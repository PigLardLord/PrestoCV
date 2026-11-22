import Foundation
import PrestoCVDomain

/// The stored form of a CV, schema 1: a DTO separate from the domain (ADR 0009, R12). Decoding is strict: required
/// fields are required, sizes are capped, and every value must be in the canonical, valid form its value object
/// produces. A file is never normalised or defaulted on read. The envelope is frozen: `schemaVersion` is a top-level
/// integer in every future version, and so is the `version` of the draft block, which every later addition to the
/// draft raises (`StoredCVFile` reads both before decoding).
struct CVFileV1: Codable, Equatable {
    static let version = 1
    static let maxText = 10_000, maxItems = 500

    let schemaVersion: Int
    let id: UUID
    let revision: Int
    let createdAt: Date, updatedAt: Date
    let title: String
    let personal: PersonalV1
    let experiences: [ExperienceV1]
    let education: [EducationV1]
    let skills: [SkillV1]
    let languages: [LanguageV1]
    let certifications: [CertificationV1]
    let profiles: [ProfileV1]
    let interests: [String]
    let design: DesignV1?
    let language: String?
    /// Absent when the CV has no draft.
    let draft: DraftV1?

    struct PersonalV1: Codable, Equatable {
        let fullName: String, professionalTitle: String, email: String?, phone: String?, location: String, website: String?, summary: String
    }
    struct DateV1: Codable, Equatable { let year: Int, month: Int? }
    struct ExperienceV1: Codable, Equatable {
        let role: String, company: String, location: String, description: String, start: DateV1?, end: DateV1?, current: Bool
    }
    struct EducationV1: Codable, Equatable {
        let degree: String, school: String, description: String, start: DateV1?, end: DateV1?, current: Bool
    }
    struct SkillV1: Codable, Equatable { let name: String, level: Int? }
    struct LanguageV1: Codable, Equatable { let language: String, proficiency: String }
    struct CertificationV1: Codable, Equatable { let name: String, issuer: String, description: String, issued: DateV1?, link: String? }
    struct ProfileV1: Codable, Equatable { let platform: String, link: String }
    struct DesignV1: Codable, Equatable { let design: String, palette: String?, fonts: String? }

    /// The draft block (`DraftBlock`). Its arrays are required; a key this version does not know is read past and not
    /// written again, so a new field needs a new version.
    struct DraftV1: Codable, Equatable {
        static let supportedVersion = 1
        let version: Int
        let origins: [OriginV1]
        let notPlaced: [NotPlacedV1]
    }
    /// A marked value: `field` names it (`personal.fullName`, `experiences.role`), `entry` is its row in a section and
    /// absent for a detail of the person.
    struct OriginV1: Codable, Equatable { let field: String, entry: Int?, origin: KindV1 }
    /// An origin, an object with a `kind` so that a later origin adds its own values beside it.
    struct KindV1: Codable, Equatable { let kind: String }
    struct NotPlacedV1: Codable, Equatable { let text: String, heading: String? }

    struct Invalid: Error, Equatable { let reason: String }

    // MARK: Coding

    static func decode(_ data: Data) throws -> CVFileV1 {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CVFileV1.self, from: data)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    // MARK: From the domain

    init(_ cv: CV, createdAt: Date, updatedAt: Date) {
        schemaVersion = Self.version; id = cv.id.raw; revision = cv.revision
        self.createdAt = createdAt; self.updatedAt = updatedAt; title = cv.title
        let p = cv.personal
        personal = PersonalV1(fullName: p.fullName, professionalTitle: p.professionalTitle, email: p.email?.value, phone: p.phone?.value,
                              location: p.location, website: p.website?.value, summary: p.summary)
        let s = cv.sections
        experiences = s.experiences.map { e in
            let (start, end, current) = Self.stored(e.period)
            return ExperienceV1(role: e.role, company: e.company, location: e.location, description: e.description, start: start, end: end, current: current)
        }
        education = s.education.map { e in
            let (start, end, current) = Self.stored(e.period)
            return EducationV1(degree: e.degree, school: e.school, description: e.description, start: start, end: end, current: current)
        }
        skills = s.skills.map { SkillV1(name: $0.name, level: $0.level?.value) }
        languages = s.languages.map { LanguageV1(language: $0.language, proficiency: $0.proficiency.rawValue) }
        certifications = s.certifications.map {
            CertificationV1(name: $0.name, issuer: $0.issuer, description: $0.description, issued: $0.issued.map(Self.stored), link: $0.link?.value)
        }
        profiles = s.profiles.map { ProfileV1(platform: $0.platform, link: $0.link.value) }
        interests = s.interests
        design = cv.design.map { DesignV1(design: $0.design, palette: $0.palette, fonts: $0.fonts) }
        language = cv.language?.tag
        draft = cv.draft.map { block in
            let origins = block.origins.map { place, origin in
                let (field, entry) = Self.stored(place)
                return OriginV1(field: field, entry: entry, origin: KindV1(kind: Self.kind(origin)))
            }
            return DraftV1(version: DraftV1.supportedVersion,
                           origins: origins.sorted { ($0.field, $0.entry ?? -1) < ($1.field, $1.entry ?? -1) },
                           notPlaced: block.notPlaced.map { NotPlacedV1(text: $0.text, heading: $0.heading) })
        }
    }

    static func stored(_ date: PartialDate) -> DateV1 { DateV1(year: date.year, month: date.month) }

    /// A period as its start, its end date and whether it is current. An ended period with no end date is stored with
    /// neither, and `current` false.
    static func stored(_ period: Period?) -> (DateV1?, DateV1?, Bool) {
        guard let period else { return (nil, nil, false) }
        switch period.end {
        case .current: return (stored(period.start), nil, true)
        case .date(let end): return (stored(period.start), stored(end), false)
        case .unknown: return (stored(period.start), nil, false)
        }
    }

    // MARK: To the domain

    func toDomain() throws(Invalid) -> CV {
        guard schemaVersion == Self.version else { throw Invalid(reason: "version") }
        guard (1...Int(Int32.max)).contains(revision) else { throw Invalid(reason: "revision") }   // no overflow on +1
        try checkSizes()
        let details = PersonalDetails(
            fullName: personal.fullName, professionalTitle: personal.professionalTitle,
            email: try Self.canonical(personal.email, EmailAddress.init, \.value, "email"),
            phone: try Self.canonical(personal.phone, PhoneNumber.init, \.value, "phone"),
            location: personal.location,
            website: try Self.canonical(personal.website, WebLink.init, \.value, "website"),
            summary: personal.summary)
        var sections = CVSections()
        for e in experiences {
            sections.experiences.append(Experience(role: e.role, company: e.company, location: e.location,
                                                   period: try Self.period(e.start, e.end, e.current, "experience"), description: e.description))
        }
        for e in education {
            sections.education.append(Education(degree: e.degree, school: e.school,
                                                 period: try Self.period(e.start, e.end, e.current, "education"), description: e.description))
        }
        for s in skills {
            var level: SkillLevel?
            if let raw = s.level {
                guard let valid = SkillLevel(raw) else { throw Invalid(reason: "skill level \(raw)") }
                level = valid
            }
            sections.skills.append(Skill(name: s.name, level: level))
        }
        for l in languages {
            guard let proficiency = LanguageProficiency(rawValue: l.proficiency) else { throw Invalid(reason: "proficiency") }
            sections.languages.append(LanguageSkill(language: l.language, proficiency: proficiency))
        }
        for c in certifications {
            var issued: PartialDate?
            if let date = c.issued {
                guard let valid = PartialDate(year: date.year, month: date.month) else { throw Invalid(reason: "certification date") }
                issued = valid
            }
            sections.certifications.append(Certification(name: c.name, issuer: c.issuer, issued: issued,
                                                         link: try Self.canonical(c.link, WebLink.init, \.value, "certification link"),
                                                         description: c.description))
        }
        for p in profiles {
            guard let link = try Self.canonical(p.link, WebLink.init, \.value, "profile link") else { throw Invalid(reason: "profile link") }
            sections.profiles.append(ProfileLink(platform: p.platform, link: link))
        }
        // A stored list must already follow the list rule; the text rule then cleans, merges or drops entries without a word.
        guard CVSections.canonicalInterests(interests, cleaningText: false) == interests else { throw Invalid(reason: "interests") }
        sections.setInterests(interests)
        var choice: DesignChoice?
        if let d = design {
            guard let valid = DesignChoice(design: d.design, palette: d.palette, fonts: d.fonts) else { throw Invalid(reason: "design") }
            choice = valid
        }
        var cv = CV(id: CVID(id), revision: revision, createdAt: createdAt, updatedAt: updatedAt, title: title, personal: details,
                    sections: sections, design: choice,
                    language: try Self.canonical(language, DocumentLanguage.init, \.tag, "language"))
        if let draft {
            let block = try draft.toDomain()
            do throws(DraftError) { try cv.setDraft(block) } catch {
                switch error {
                case .placeOutsideSections: throw Invalid(reason: "draft place")
                }
            }
        }
        return cv
    }

    /// A stored value is exactly what its value object produces from it.
    private static func canonical<T>(_ raw: String?, _ make: (String) -> T?, _ value: (T) -> String, _ field: String) throws(Invalid) -> T? {
        guard let raw else { return nil }
        guard let parsed = make(raw), value(parsed) == raw else { throw Invalid(reason: field) }
        return parsed
    }

    /// `Period.make` is the one period rule; every stored combination is a period, no period, or corrupt.
    private static func period(_ start: DateV1?, _ end: DateV1?, _ current: Bool, _ field: String) throws(Invalid) -> Period? {
        do throws(PeriodError) {
            return try Period.make(start: start.map { ($0.year, $0.month) }, end: end.map { ($0.year, $0.month) }, current: current)
        } catch {
            throw Invalid(reason: "\(field) period: \(error)")
        }
    }

    private func checkSizes() throws(Invalid) {
        var texts: [String] = [title, personal.fullName, personal.professionalTitle, personal.location, personal.summary]
        texts += [personal.email, personal.phone, personal.website, language, design?.design, design?.palette, design?.fonts].compactMap { $0 }
        texts += experiences.flatMap { [$0.role, $0.company, $0.location, $0.description] }
        texts += education.flatMap { [$0.degree, $0.school, $0.description] }
        texts += skills.map(\.name)
        texts += languages.flatMap { [$0.language, $0.proficiency] }
        texts += certifications.flatMap { [$0.name, $0.issuer, $0.description] } + certifications.compactMap(\.link)
        texts += profiles.flatMap { [$0.platform, $0.link] }
        texts += interests
        texts += (draft?.notPlaced ?? []).flatMap { [$0.text] + [$0.heading].compactMap { $0 } }
        let counts = [experiences.count, education.count, skills.count, languages.count, certifications.count, profiles.count, interests.count,
                      draft?.notPlaced.count ?? 0]
        guard texts.allSatisfy({ $0.count <= Self.maxText }), counts.allSatisfy({ $0 <= Self.maxItems }) else {
            throw Invalid(reason: "size limits")
        }
    }
}

// MARK: The draft block

extension CVFileV1 {
    /// The stored name of each place's field. A section's fields are named after the section's key in the file.
    static func stored(_ place: ValuePlace) -> (field: String, entry: Int?) {
        switch place {
        case .personal(let field): ("personal." + key(field), nil)
        case .entry(let field, let index): (key(field), index)
        }
    }

    private static func key(_ field: PersonalField) -> String {
        switch field {
        case .fullName: "fullName"
        case .professionalTitle: "professionalTitle"
        case .email: "email"
        case .phone: "phone"
        case .location: "location"
        case .website: "website"
        case .summary: "summary"
        }
    }

    private static func key(_ field: EntryField) -> String {
        switch field {
        case .experienceRole: "experiences.role"
        case .experienceCompany: "experiences.company"
        case .experienceLocation: "experiences.location"
        case .experiencePeriod: "experiences.period"
        case .experienceDescription: "experiences.description"
        case .educationDegree: "education.degree"
        case .educationSchool: "education.school"
        case .educationPeriod: "education.period"
        case .educationDescription: "education.description"
        case .skillName: "skills.name"
        case .languageName: "languages.language"
        case .languageProficiency: "languages.proficiency"
        case .certificationName: "certifications.name"
        case .certificationIssuer: "certifications.issuer"
        case .certificationIssued: "certifications.issued"
        case .profilePlatform: "profiles.platform"
        case .profileLink: "profiles.link"
        case .interest: "interests"
        }
    }

    static func kind(_ origin: ValueOrigin) -> String {
        switch origin {
        case .imported: "imported"
        }
    }

    private static let personalFields = Dictionary(uniqueKeysWithValues: PersonalField.allCases.map { ("personal." + key($0), $0) })
    private static let entryFields = Dictionary(uniqueKeysWithValues: EntryField.allCases.map { (key($0), $0) })
    private static let origins = Dictionary(uniqueKeysWithValues: [ValueOrigin.imported].map { (kind($0), $0) })
}

extension CVFileV1.DraftV1 {
    /// The block as the domain holds it, checked value by value; whether each place is inside the sections is the
    /// domain's check (`CV.setDraft`).
    func toDomain() throws(CVFileV1.Invalid) -> DraftBlock {
        guard version == Self.supportedVersion else { throw CVFileV1.Invalid(reason: "draft version") }
        guard !origins.isEmpty || !notPlaced.isEmpty else { throw CVFileV1.Invalid(reason: "draft empty") }
        var marks: [ValuePlace: ValueOrigin] = [:]
        for record in origins {
            let place = try CVFileV1.place(record.field, record.entry)
            guard let origin = CVFileV1.origin(record.origin.kind) else { throw CVFileV1.Invalid(reason: "draft origin") }
            guard marks.updateValue(origin, forKey: place) == nil else { throw CVFileV1.Invalid(reason: "draft duplicate place") }
        }
        var texts: [NotPlacedText] = []
        for stored in notPlaced {
            guard let text = NotPlacedText(text: stored.text, heading: stored.heading), text.text == stored.text, text.heading == stored.heading else {
                throw CVFileV1.Invalid(reason: "draft not-placed text")
            }
            texts.append(text)
        }
        return DraftBlock(origins: marks, notPlaced: texts)
    }
}

extension CVFileV1 {
    /// A stored field and entry as a place: a detail of the person has no entry, a value of a section has one.
    fileprivate static func place(_ field: String, _ entry: Int?) throws(Invalid) -> ValuePlace {
        if let personal = personalFields[field] {
            guard entry == nil else { throw Invalid(reason: "draft place") }
            return .personal(personal)
        }
        guard let value = entryFields[field] else { throw Invalid(reason: "draft field") }
        guard let entry else { throw Invalid(reason: "draft place") }
        return .entry(value, index: entry)
    }

    fileprivate static func origin(_ kind: String) -> ValueOrigin? { origins[kind] }
}

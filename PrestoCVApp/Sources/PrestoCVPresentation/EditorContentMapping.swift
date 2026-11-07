internal import PrestoCVApplication
internal import PrestoCVDomain

// The form's text read into a CV and back. It holds no rule: what a CV may hold, the domain's value objects, `Period` and
// `CV.saveCheck()` say.

extension EditorContent {
    static let empty = EditorContent(
        title: "", fullName: "", professionalTitle: "", email: "", phone: "", location: "", website: "", summary: "",
        experiences: [], education: [], skills: [], languages: [], certifications: [], profiles: [], interests: []
    )

    /// The form as the CV holds it, with ids from a counter of its own.
    init(_ cv: CV) {
        var ids = RowIDs()
        self.init(cv, ids: &ids)
    }

    /// The form as the CV holds it: each row has the next id of `ids`.
    init(_ cv: CV, ids: inout RowIDs) {
        let person = cv.personal
        let sections = cv.sections
        self.init(
            title: cv.title, fullName: person.fullName, professionalTitle: person.professionalTitle,
            email: person.email?.value ?? "", phone: person.phone?.value ?? "", location: person.location,
            website: person.website?.value ?? "", summary: person.summary,
            experiences: sections.experiences.map { ExperienceRow($0, id: ids.make()) },
            education: sections.education.map { EducationRow($0, id: ids.make()) },
            skills: sections.skills.map { SkillRow($0, id: ids.make()) },
            languages: sections.languages.map { LanguageRow($0, id: ids.make()) },
            certifications: sections.certifications.map { CertificationRow($0, id: ids.make()) },
            profiles: sections.profiles.map { ProfileRow($0, id: ids.make()) },
            interests: sections.interests.map { InterestRow(id: ids.make(), text: $0) }
        )
    }

    /// `base` with the form's text: its identity, look and language stay. A field that cannot be read as its kind is left
    /// out; `unreadableFields` names it.
    func applied(to base: CV) -> CV {
        var cv = base
        cv.rename(title)
        cv.setPersonalDetails(PersonalDetails(
            fullName: fullName, professionalTitle: professionalTitle, email: EmailAddress(email), phone: PhoneNumber(phone),
            location: location, website: WebLink(website), summary: summary
        ))
        cv.setSections(CVSections(
            experiences: experiences.map(\.entry), education: education.map(\.entry), skills: skills.map(\.entry),
            languages: languages.compactMap(\.entry), certifications: certifications.map(\.entry),
            profiles: profiles.compactMap(\.entry), interests: interests.map(\.text)
        ))
        return cv
    }

    /// The fields whose text is not blank and cannot be read as its kind, in the form's order.
    var unreadableFields: [EditorField] {
        let readings: [(EditorField, String, Bool)] = [
            (.email, email, EmailAddress(email) != nil),
            (.phone, phone, PhoneNumber(phone) != nil),
            (.website, website, WebLink(website) != nil),
        ]
        let personal = readings.filter { _, text, isRead in !isRead && !text.isBlank }.map(\.0)
        return personal + experiences.flatMap(\.unreadableFields) + education.flatMap(\.unreadableFields)
            + skills.flatMap(\.unreadableFields) + languages.flatMap(\.unreadableFields)
            + certifications.flatMap(\.unreadableFields) + profiles.flatMap(\.unreadableFields)
    }

    /// Whether the row of `section` with `id` has nothing in it. A row that is not there has nothing either.
    func rowIsBlank(in section: EditorSection, id: RowID) -> Bool {
        row(in: section, id: id)?.isBlank ?? true
    }

    /// Whether the section has the row with `id`.
    func hasRow(in section: EditorSection, id: RowID) -> Bool {
        row(in: section, id: id) != nil
    }

    private func row(in section: EditorSection, id: RowID) -> (any EditorRow)? {
        switch section {
        case .experiences: experiences.first { $0.id == id }
        case .education: education.first { $0.id == id }
        case .skills: skills.first { $0.id == id }
        case .languages: languages.first { $0.id == id }
        case .certifications: certifications.first { $0.id == id }
        case .profiles: profiles.first { $0.id == id }
        case .interests: interests.first { $0.id == id }
        }
    }

    mutating func addRow(to section: EditorSection, id: RowID) {
        switch section {
        case .experiences: experiences.append(ExperienceRow.blank(id: id))
        case .education: education.append(EducationRow.blank(id: id))
        case .skills: skills.append(SkillRow.blank(id: id))
        case .languages: languages.append(LanguageRow.blank(id: id))
        case .certifications: certifications.append(CertificationRow.blank(id: id))
        case .profiles: profiles.append(ProfileRow.blank(id: id))
        case .interests: interests.append(InterestRow(id: id, text: ""))
        }
    }

    mutating func removeRow(in section: EditorSection, id: RowID) {
        switch section {
        case .experiences: experiences.removeAll { $0.id == id }
        case .education: education.removeAll { $0.id == id }
        case .skills: skills.removeAll { $0.id == id }
        case .languages: languages.removeAll { $0.id == id }
        case .certifications: certifications.removeAll { $0.id == id }
        case .profiles: profiles.removeAll { $0.id == id }
        case .interests: interests.removeAll { $0.id == id }
        }
    }
}

extension String {
    var isBlank: Bool { allSatisfy(\.isWhitespace) }
}

extension InterestRow: EditorRow {
    var isBlank: Bool { text.isBlank }
}

// MARK: - Rows

extension ExperienceRow: EditorRow {
    static func blank(id: RowID) -> ExperienceRow {
        ExperienceRow(id: id, role: "", company: "", location: "", periodStart: "", periodEnd: "", isCurrent: false, description: "")
    }

    init(_ entry: Experience, id: RowID) {
        self.init(
            id: id, role: entry.role, company: entry.company, location: entry.location, periodStart: entry.period?.startText ?? "",
            periodEnd: entry.period?.endText ?? "", isCurrent: entry.period?.isCurrent ?? false, description: entry.description
        )
    }

    var entry: Experience {
        Experience(role: role, company: company, location: location,
                   period: readPeriod(periodStart, periodEnd, isCurrent), description: description)
    }

    var isBlank: Bool {
        [role, company, location, periodStart, periodEnd, description].allSatisfy(\.isBlank) && !isCurrent
    }

    var unreadableFields: [EditorField] { periodIsReadable(periodStart, periodEnd, isCurrent) ? [] : [.experiencePeriod] }
}

extension EducationRow: EditorRow {
    static func blank(id: RowID) -> EducationRow {
        EducationRow(id: id, degree: "", school: "", periodStart: "", periodEnd: "", isCurrent: false, description: "")
    }

    init(_ entry: Education, id: RowID) {
        self.init(
            id: id, degree: entry.degree, school: entry.school, periodStart: entry.period?.startText ?? "",
            periodEnd: entry.period?.endText ?? "", isCurrent: entry.period?.isCurrent ?? false, description: entry.description
        )
    }

    var entry: Education {
        Education(degree: degree, school: school, period: readPeriod(periodStart, periodEnd, isCurrent), description: description)
    }

    var isBlank: Bool { [degree, school, periodStart, periodEnd, description].allSatisfy(\.isBlank) && !isCurrent }

    var unreadableFields: [EditorField] { periodIsReadable(periodStart, periodEnd, isCurrent) ? [] : [.educationPeriod] }
}

/// The period the domain reads from the text, or nil when there is none or it cannot read it (`periodIsReadable` tells which).
private func readPeriod(_ start: String, _ end: String, _ current: Bool) -> Period? {
    do {
        return try Period.reading(start: start, end: end, current: current)
    } catch {
        return nil
    }
}

/// Whether the domain can read the period, or there is none to read.
private func periodIsReadable(_ start: String, _ end: String, _ current: Bool) -> Bool {
    readPeriod(start, end, current) != nil || (start.isBlank && end.isBlank && !current)
}

extension SkillRow: EditorRow {
    static func blank(id: RowID) -> SkillRow {
        SkillRow(id: id, name: "", level: nil)
    }

    init(_ entry: Skill, id: RowID) { self.init(id: id, name: entry.name, level: entry.level?.value) }

    var entry: Skill { Skill(name: name, level: level.flatMap(SkillLevel.init)) }

    var isBlank: Bool { name.isBlank && level == nil }

    var unreadableFields: [EditorField] { level.map { SkillLevel($0) == nil } == true ? [.skillLevel] : [] }
}

extension LanguageRow: EditorRow {
    static func blank(id: RowID) -> LanguageRow {
        LanguageRow(id: id, language: "", proficiency: "")
    }

    init(_ entry: LanguageSkill, id: RowID) { self.init(id: id, language: entry.language, proficiency: entry.proficiency.rawValue) }

    /// Nil while the level is not one the domain knows: the entry cannot exist without it.
    var entry: LanguageSkill? { LanguageProficiency(rawValue: proficiency).map { LanguageSkill(language: language, proficiency: $0) } }

    var isBlank: Bool { language.isBlank && proficiency.isBlank }

    var unreadableFields: [EditorField] { entry == nil && !isBlank ? [.languageProficiency] : [] }
}

extension CertificationRow: EditorRow {
    static func blank(id: RowID) -> CertificationRow {
        CertificationRow(id: id, name: "", issuer: "", issued: "", link: "", description: "")
    }

    init(_ entry: Certification, id: RowID) {
        self.init(
            id: id, name: entry.name, issuer: entry.issuer, issued: entry.issued?.text ?? "", link: entry.link?.value ?? "",
            description: entry.description
        )
    }

    var entry: Certification {
        Certification(name: name, issuer: issuer, issued: PartialDate(reading: issued), link: WebLink(link), description: description)
    }

    var isBlank: Bool { [name, issuer, issued, link, description].allSatisfy(\.isBlank) }

    var unreadableFields: [EditorField] {
        (PartialDate(reading: issued) == nil && !issued.isBlank ? [.certificationIssued] : [])
            + (WebLink(link) == nil && !link.isBlank ? [.certificationLink] : [])
    }
}

extension ProfileRow: EditorRow {
    static func blank(id: RowID) -> ProfileRow {
        ProfileRow(id: id, platform: "", link: "")
    }

    init(_ entry: ProfileLink, id: RowID) { self.init(id: id, platform: entry.platform, link: entry.link.value) }

    /// Nil while there is no link the domain accepts: a profile exists only with one.
    var entry: ProfileLink? { WebLink(link).map { ProfileLink(platform: platform, link: $0) } }

    var isBlank: Bool { platform.isBlank && link.isBlank }

    var unreadableFields: [EditorField] { entry == nil && !isBlank ? [.profileLink] : [] }
}

extension EditorLook {
    init(_ design: DesignChoice) {
        self.init(design: design.design, palette: design.palette, fonts: design.fonts)
    }
}

extension LookChange {
    /// Nil when an id is not one a design may have.
    init?(shown look: EditorLook, parts: Set<LookPart>) {
        guard let shown = DesignChoice(design: look.design, palette: look.palette, fonts: look.fonts) else { return nil }
        self.init(shown: shown, parts: Set(parts.map(LookChange.Part.init)))
    }
}

extension LookChange.Part {
    init(_ part: LookPart) {
        switch part {
        case .design: self = .design
        case .palette: self = .palette
        case .fonts: self = .fonts
        }
    }
}

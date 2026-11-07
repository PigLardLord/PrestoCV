internal import PrestoCVApplication
internal import PrestoCVDomain

// The form's text read into a CV and back. It holds no rule: what a CV may hold, the domain's value objects, `Period` and
// `CV.saveCheck()` say.

extension EditorContent {
    static let empty = EditorContent(
        title: "", fullName: "", professionalTitle: "", email: "", phone: "", location: "", website: "", summary: "",
        experiences: [], education: [], skills: [], languages: [], certifications: [], profiles: [], interests: []
    )

    /// The form as the CV holds it.
    init(_ cv: CV) {
        let person = cv.personal
        let sections = cv.sections
        self.init(
            title: cv.title, fullName: person.fullName, professionalTitle: person.professionalTitle,
            email: person.email?.value ?? "", phone: person.phone?.value ?? "", location: person.location,
            website: person.website?.value ?? "", summary: person.summary,
            experiences: sections.experiences.map(ExperienceRow.init), education: sections.education.map(EducationRow.init),
            skills: sections.skills.map(SkillRow.init), languages: sections.languages.map(LanguageRow.init),
            certifications: sections.certifications.map(CertificationRow.init), profiles: sections.profiles.map(ProfileRow.init),
            interests: sections.interests
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
            profiles: profiles.compactMap(\.entry), interests: interests
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

    /// Whether the row of `section` at `index` has nothing in it. A row that is not there has nothing either.
    func rowIsBlank(in section: EditorSection, at index: Int) -> Bool {
        switch section {
        case .experiences: experiences.indices.contains(index) ? experiences[index].isBlank : true
        case .education: education.indices.contains(index) ? education[index].isBlank : true
        case .skills: skills.indices.contains(index) ? skills[index].isBlank : true
        case .languages: languages.indices.contains(index) ? languages[index].isBlank : true
        case .certifications: certifications.indices.contains(index) ? certifications[index].isBlank : true
        case .profiles: profiles.indices.contains(index) ? profiles[index].isBlank : true
        case .interests: interests.indices.contains(index) ? interests[index].isBlank : true
        }
    }

    /// Whether the section has a row at `index`.
    func hasRow(in section: EditorSection, at index: Int) -> Bool {
        switch section {
        case .experiences: experiences.indices.contains(index)
        case .education: education.indices.contains(index)
        case .skills: skills.indices.contains(index)
        case .languages: languages.indices.contains(index)
        case .certifications: certifications.indices.contains(index)
        case .profiles: profiles.indices.contains(index)
        case .interests: interests.indices.contains(index)
        }
    }

    mutating func addRow(to section: EditorSection) {
        switch section {
        case .experiences: experiences.append(ExperienceRow.blank)
        case .education: education.append(EducationRow.blank)
        case .skills: skills.append(SkillRow.blank)
        case .languages: languages.append(LanguageRow.blank)
        case .certifications: certifications.append(CertificationRow.blank)
        case .profiles: profiles.append(ProfileRow.blank)
        case .interests: interests.append("")
        }
    }

    mutating func removeRow(in section: EditorSection, at index: Int) {
        guard hasRow(in: section, at: index) else { return }
        switch section {
        case .experiences: experiences.remove(at: index)
        case .education: education.remove(at: index)
        case .skills: skills.remove(at: index)
        case .languages: languages.remove(at: index)
        case .certifications: certifications.remove(at: index)
        case .profiles: profiles.remove(at: index)
        case .interests: interests.remove(at: index)
        }
    }
}

extension String {
    var isBlank: Bool { allSatisfy(\.isWhitespace) }
}

// MARK: - Rows

extension ExperienceRow {
    static let blank = ExperienceRow(role: "", company: "", location: "", periodStart: "", periodEnd: "", isCurrent: false, description: "")

    init(_ entry: Experience) {
        self.init(
            role: entry.role, company: entry.company, location: entry.location, periodStart: entry.period?.startText ?? "",
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

extension EducationRow {
    static let blank = EducationRow(degree: "", school: "", periodStart: "", periodEnd: "", isCurrent: false, description: "")

    init(_ entry: Education) {
        self.init(
            degree: entry.degree, school: entry.school, periodStart: entry.period?.startText ?? "",
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

extension SkillRow {
    static let blank = SkillRow(name: "", level: nil)

    init(_ entry: Skill) { self.init(name: entry.name, level: entry.level?.value) }

    var entry: Skill { Skill(name: name, level: level.flatMap(SkillLevel.init)) }

    var isBlank: Bool { name.isBlank && level == nil }

    var unreadableFields: [EditorField] { level.map { SkillLevel($0) == nil } == true ? [.skillLevel] : [] }
}

extension LanguageRow {
    static let blank = LanguageRow(language: "", proficiency: "")

    init(_ entry: LanguageSkill) { self.init(language: entry.language, proficiency: entry.proficiency.rawValue) }

    /// Nil while the level is not one the domain knows: the entry cannot exist without it.
    var entry: LanguageSkill? { LanguageProficiency(rawValue: proficiency).map { LanguageSkill(language: language, proficiency: $0) } }

    var isBlank: Bool { language.isBlank && proficiency.isBlank }

    var unreadableFields: [EditorField] { entry == nil && !isBlank ? [.languageProficiency] : [] }
}

extension CertificationRow {
    static let blank = CertificationRow(name: "", issuer: "", issued: "", link: "", description: "")

    init(_ entry: Certification) {
        self.init(
            name: entry.name, issuer: entry.issuer, issued: entry.issued?.text ?? "", link: entry.link?.value ?? "",
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

extension ProfileRow {
    static let blank = ProfileRow(platform: "", link: "")

    init(_ entry: ProfileLink) { self.init(platform: entry.platform, link: entry.link.value) }

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

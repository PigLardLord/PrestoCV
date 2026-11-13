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
    /// out; `unreadable` names it.
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

    /// The fields that cannot be stored, each with its row and why, in the form's order: text that is not blank and
    /// cannot be read as its kind, a period whose end comes before its start.
    var unreadable: [FieldProblem] {
        let readings: [(EditorField, String, Bool)] = [
            (.email, email, EmailAddress(email) != nil),
            (.phone, phone, PhoneNumber(phone) != nil),
            (.website, website, WebLink(website) != nil),
        ]
        let personal = readings.filter { _, text, isRead in !isRead && !text.isBlank }
            .map { field, _, _ in FieldProblem(row: nil, field: field, code: .unreadable) }
        return personal
            + problems(on: experiences, \.period, .experiencePeriod) + problems(on: education, \.period, .educationPeriod)
            + unreadable(on: skills, \.unreadableFields) + unreadable(on: languages, \.unreadableFields)
            + unreadable(on: certifications, \.unreadableFields) + unreadable(on: profiles, \.unreadableFields)
    }

    private func unreadable<Row: EditorRow>(on rows: [Row], _ fields: (Row) -> [EditorField]) -> [FieldProblem] {
        rows.flatMap { row in fields(row).map { FieldProblem(row: row.id, field: $0, code: .unreadable) } }
    }

    private func problems<Row: EditorRow>(
        on rows: [Row], _ period: (Row) -> PeriodParts, _ field: EditorField
    ) -> [FieldProblem] {
        rows.compactMap { row in period(row).problem.map { FieldProblem(row: row.id, field: field, code: $0) } }
    }

    /// Whether the row of `section` with `id` has nothing in it. A row that is not there has nothing either.
    func rowIsBlank(in section: EditorSection, id: RowID) -> Bool {
        row(in: section, id: id)?.isBlank ?? true
    }

    /// How many rows of all sections have `id`.
    func rowCount(withID id: RowID) -> Int {
        experiences.filter { $0.id == id }.count + education.filter { $0.id == id }.count
            + skills.filter { $0.id == id }.count + languages.filter { $0.id == id }.count
            + certifications.filter { $0.id == id }.count + profiles.filter { $0.id == id }.count
            + interests.filter { $0.id == id }.count
    }

    /// The name of the row of `section` with `id`, or nil if the section has no such row.
    func rowName(in section: EditorSection, id: RowID) -> RowName? {
        row(in: section, id: id)?.rowName
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

    /// Adds an empty row with `id`: a job, a study or a certification first, as a CV lists the newest first (#32); any
    /// other row last.
    mutating func addRow(to section: EditorSection, id: RowID) {
        switch section {
        case .experiences: experiences.insert(ExperienceRow.blank(id: id), at: 0)
        case .education: education.insert(EducationRow.blank(id: id), at: 0)
        case .skills: skills.append(SkillRow.blank(id: id))
        case .languages: languages.append(LanguageRow.blank(id: id))
        case .certifications: certifications.insert(CertificationRow.blank(id: id), at: 0)
        case .profiles: profiles.append(ProfileRow.blank(id: id))
        case .interests: interests.append(InterestRow(id: id, text: ""))
        }
    }

    /// Removes the first row with `id` only, so that a duplicate that slipped through never takes another row with it.
    private func remove<Row: EditorRow>(from rows: inout [Row], id: RowID) {
        if let index = rows.firstIndex(where: { $0.id == id }) { rows.remove(at: index) }
    }

    mutating func removeRow(in section: EditorSection, id: RowID) {
        switch section {
        case .experiences: remove(from: &experiences, id: id)
        case .education: remove(from: &education, id: id)
        case .skills: remove(from: &skills, id: id)
        case .languages: remove(from: &languages, id: id)
        case .certifications: remove(from: &certifications, id: id)
        case .profiles: remove(from: &profiles, id: id)
        case .interests: remove(from: &interests, id: id)
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
        ExperienceRow(id: id, role: "", company: "", location: "", period: .none, description: "")
    }

    init(_ entry: Experience, id: RowID) {
        self.init(
            id: id, role: entry.role, company: entry.company, location: entry.location, period: PeriodParts(entry.period),
            description: entry.description
        )
    }

    var entry: Experience {
        Experience(role: role, company: company, location: location, period: period.stored, description: description)
    }

    var isBlank: Bool { [role, company, location, description].allSatisfy(\.isBlank) && period.isBlank }
}

extension EducationRow: EditorRow {
    static func blank(id: RowID) -> EducationRow {
        EducationRow(id: id, degree: "", school: "", period: .none, description: "")
    }

    init(_ entry: Education, id: RowID) {
        self.init(
            id: id, degree: entry.degree, school: entry.school, period: PeriodParts(entry.period), description: entry.description
        )
    }

    var entry: Education {
        Education(degree: degree, school: school, period: period.stored, description: description)
    }

    var isBlank: Bool { [degree, school, description].allSatisfy(\.isBlank) && period.isBlank }
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
        CertificationRow(id: id, name: "", issuer: "", issued: .none, link: "", description: "")
    }

    init(_ entry: Certification, id: RowID) {
        self.init(
            id: id, name: entry.name, issuer: entry.issuer, issued: DateParts(text: entry.issued?.text ?? ""),
            link: entry.link?.value ?? "", description: entry.description
        )
    }

    var entry: Certification {
        Certification(
            name: name, issuer: issuer, issued: issued.text.flatMap(PartialDate.init(reading:)), link: WebLink(link),
            description: description
        )
    }

    var isBlank: Bool { [name, issuer, link, description].allSatisfy(\.isBlank) && issued.isBlank }

    var unreadableFields: [EditorField] {
        (issued.text == nil ? [.certificationIssued] : [])
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

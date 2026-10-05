import Foundation
import PrestoCVDomain

extension CVFileV1 {
    init(_ cv: CV, createdAt: Date, updatedAt: Date) {
        let sections = cv.sections
        let experiences: [ExperienceV1] = sections.experiences.map(ExperienceV1.init)
        let education: [EducationV1] = sections.education.map(EducationV1.init)
        let skills: [SkillV1] = sections.skills.map(SkillV1.init)
        let languages: [LanguageV1] = sections.languages.map(LanguageV1.init)
        let certifications: [CertificationV1] = sections.certifications.map(CertificationV1.init)
        let profiles: [ProfileV1] = sections.profiles.map(ProfileV1.init)
        self.init(schemaVersion: Self.version, id: cv.id.raw, revision: cv.revision, createdAt: createdAt, updatedAt: updatedAt,
                  title: cv.title, personal: PersonalV1(cv.personal), experiences: experiences, education: education, skills: skills,
                  languages: languages, certifications: certifications, profiles: profiles, interests: sections.interests.values,
                  design: cv.design.map(DesignV1.init), language: cv.language?.tag)
    }
}

extension CVFileV1.PersonalV1 {
    init(_ details: PersonalDetails) {
        self.init(fullName: details.fullName, professionalTitle: details.professionalTitle, email: details.email?.value,
                  phone: details.phone?.value, location: details.location, website: details.website?.value, summary: details.summary)
    }
}

extension CVFileV1.DateV1 {
    init(_ date: PartialDate) { self.init(year: date.year, month: date.month) }
}

extension CVFileV1.PeriodFieldsV1 {
    /// An ended period with no end date is stored with neither an end nor `current`.
    init(_ period: Period?) {
        guard let period else { self.init(start: nil, end: nil, current: false); return }
        let start = CVFileV1.DateV1(period.start)
        switch period.end {
        case .current: self.init(start: start, end: nil, current: true)
        case .date(let end): self.init(start: start, end: CVFileV1.DateV1(end), current: false)
        case .unknown: self.init(start: start, end: nil, current: false)
        }
    }
}

extension CVFileV1.ExperienceV1 {
    init(_ experience: Experience) {
        let period = CVFileV1.PeriodFieldsV1(experience.period)
        self.init(role: experience.role, company: experience.company, location: experience.location, description: experience.description,
                  start: period.start, end: period.end, current: period.current)
    }
}

extension CVFileV1.EducationV1 {
    init(_ education: Education) {
        let period = CVFileV1.PeriodFieldsV1(education.period)
        self.init(degree: education.degree, school: education.school, description: education.description,
                  start: period.start, end: period.end, current: period.current)
    }
}

extension CVFileV1.SkillV1 {
    init(_ skill: Skill) { self.init(name: skill.name, level: skill.level?.value) }
}

extension CVFileV1.LanguageV1 {
    init(_ skill: LanguageSkill) { self.init(language: skill.language, proficiency: skill.proficiency.rawValue) }
}

extension CVFileV1.CertificationV1 {
    init(_ certification: Certification) {
        self.init(name: certification.name, issuer: certification.issuer, description: certification.description,
                  issued: certification.issued.map(CVFileV1.DateV1.init), link: certification.link?.value)
    }
}

extension CVFileV1.ProfileV1 {
    init(_ profile: ProfileLink) { self.init(platform: profile.platform, link: profile.link.value) }
}

extension CVFileV1.DesignV1 {
    init(_ choice: DesignChoice) { self.init(design: choice.design, palette: choice.palette, fonts: choice.fonts) }
}

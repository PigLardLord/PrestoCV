extension CVFileV1 {
    /// Texts and lists within the caps of schema 1. A file over them is corrupt, not truncated.
    func checkSizes() throws(Invalid) {
        guard allTexts.allSatisfy({ $0.count <= Self.maxText }), itemCounts.allSatisfy({ $0 <= Self.maxItems }) else {
            throw Invalid(reason: "size limits")
        }
    }

    private var allTexts: [String] {
        var texts = [title]
        texts += personal.texts
        texts += design?.texts ?? []
        texts += present(language)
        texts += experiences.flatMap(\.texts)
        texts += education.flatMap(\.texts)
        texts += skills.flatMap(\.texts)
        texts += languages.flatMap(\.texts)
        texts += certifications.flatMap(\.texts)
        texts += profiles.flatMap(\.texts)
        texts += interests
        return texts
    }

    private var itemCounts: [Int] {
        [experiences.count, education.count, skills.count, languages.count, certifications.count, profiles.count, interests.count]
    }
}

extension CVFileV1.PersonalV1 {
    var texts: [String] { [fullName, professionalTitle, location, summary] + present(email, phone, website) }
}

extension CVFileV1.ExperienceV1 {
    var texts: [String] { [role, company, location, description] }
}

extension CVFileV1.EducationV1 {
    var texts: [String] { [degree, school, description] }
}

extension CVFileV1.SkillV1 {
    var texts: [String] { [name] }
}

extension CVFileV1.LanguageV1 {
    var texts: [String] { [language, proficiency] }
}

extension CVFileV1.CertificationV1 {
    var texts: [String] { [name, issuer, description] + present(link) }
}

extension CVFileV1.ProfileV1 {
    var texts: [String] { [platform, link] }
}

extension CVFileV1.DesignV1 {
    var texts: [String] { [design] + present(palette, fonts) }
}

/// The texts among `values` that are there.
private func present(_ values: String?...) -> [String] { values.compactMap { $0 } }

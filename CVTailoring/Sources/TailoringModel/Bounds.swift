/// The checks the initialisers of the model share, so a bound is written once (R8).
enum Bounds {
    static func text(_ value: String, _ field: TailoringModelError.Field) throws(TailoringModelError) {
        guard value.utf8.count <= TailoringLimits.maxTextBytes else { throw .tooLarge(field) }
    }

    static func optionalText(_ value: String?, _ field: TailoringModelError.Field) throws(TailoringModelError) {
        if let value { try text(value, field) }
    }

    /// Text that must say something: not empty once its whitespace is trimmed. The value itself is kept as written.
    static func requiredText(_ value: String, _ field: TailoringModelError.Field) throws(TailoringModelError) {
        guard value.contains(where: { !$0.isWhitespace }) else { throw .emptyField(field) }
        try text(value, field)
    }

    static func texts(_ values: [String], _ field: TailoringModelError.Field, atMost limit: Int,
                      _ collection: TailoringModelError.Collection) throws(TailoringModelError) {
        try count(values.count, atMost: limit, collection)
        for value in values { try text(value, field) }
    }

    static func count(_ count: Int, atMost limit: Int, _ collection: TailoringModelError.Collection) throws(TailoringModelError) {
        guard count <= limit else { throw .tooMany(collection) }
    }

    /// What a source CV and a tailored CV hold alike: the summary, and the sections an experience is not part of.
    static func cvSections(summary: String, education: [SourceEducation], skills: [SourceSkill], languages: [SourceLanguage],
                           certifications: [SourceCertification], profiles: [SourceProfile],
                           interests: [String]) throws(TailoringModelError) {
        try text(summary, .summary)
        try count(education.count, atMost: TailoringLimits.maxEntriesPerSection, .education)
        try count(skills.count, atMost: TailoringLimits.maxEntriesPerSection, .skills)
        try count(languages.count, atMost: TailoringLimits.maxEntriesPerSection, .languages)
        try count(certifications.count, atMost: TailoringLimits.maxEntriesPerSection, .certifications)
        try count(profiles.count, atMost: TailoringLimits.maxEntriesPerSection, .profiles)
        try count(interests.count, atMost: TailoringLimits.maxEntriesPerSection, .interests)
        for interest in interests { try text(interest, .interest) }
    }
}

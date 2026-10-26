import PrestoCVCore
import enum PrestoCVDomain.SaveRule

extension CVModel {
    /// Whether the CV has enough content to be saved, by `SaveRule`: every detail of its person, and the size of every
    /// section, without the name of the CV itself.
    var allowsSaving: Bool {
        let info = personalInfo
        return SaveRule.allowsSaving(
            personalDetails: [info.name, info.title, info.email, info.phone, info.location, info.portfolio, info.profile],
            sectionSizes: [relevant_experience.count, education.count, skills.count, languages.count, certifications.count,
                           social.count, interests.count]
        )
    }
}

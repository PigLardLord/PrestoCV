import Foundation

/// "Has enough content to be saved", the one definition (R6). A CV can be saved once a detail of its person is written,
/// or one of its sections has an entry, even one the person has only just added. The CV's own title, which only names it
/// in the list, does not count.
///
/// It reads plain values, so that a CV kept in another shape, such as the app's stored CVs before the migration, is
/// judged by the same rule.
public enum SaveRule {
    /// - Parameters:
    ///   - personalDetails: The text of each detail of the person. White space does not count.
    ///   - sectionSizes: How many entries each section has.
    public static func allowsSaving(personalDetails: [String], sectionSizes: [Int]) -> Bool {
        personalDetails.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } || sectionSizes.contains { $0 > 0 }
    }
}

/// Whether a CV can be saved, and if not, why (R6, R7).
public enum SaveVerdict: Hashable, Sendable {
    case ok
    /// Nothing is written yet, by `SaveRule`.
    case notEnoughContent
    /// A text is above `CVLimits.maxTextBytes` or `CVLimits.maxTextCharacters`.
    case textTooLong(CVTextField)
    /// A section has more than `CVLimits.maxEntriesPerSection` entries.
    case tooManyEntries(CVSection)
    /// All the texts together are above `CVLimits.maxTotalTextBytes`, or the draft's not-placed texts are above the
    /// limits of one text or of one section (`CVLimits`): they are not printed, so no field is named for them.
    case cvTooLarge
}

extension CV {
    /// The save rule and the size limits, in this order: enough content, each text, each section, the draft's not-placed
    /// texts, the whole CV. The first that fails is the reason. Text is never cut to fit. The draft is not content: it
    /// never makes a CV savable, but its texts count in the limits.
    public func saveCheck() -> SaveVerdict {
        guard hasEnoughContent else { return .notEnoughContent }
        let p = personal, s = sections
        var texts: [(field: CVTextField, text: String)] = [
            (.title, title), (.fullName, p.fullName), (.professionalTitle, p.professionalTitle), (.location, p.location), (.summary, p.summary),
        ]
        texts += s.experiences.flatMap { [(CVTextField.experienceRole, $0.role), (.experienceCompany, $0.company),
                                          (.experienceLocation, $0.location), (.experienceDescription, $0.description)] }
        texts += s.education.flatMap { [(CVTextField.educationDegree, $0.degree), (.educationSchool, $0.school), (.educationDescription, $0.description)] }
        texts += s.skills.map { (CVTextField.skillName, $0.name) }
        texts += s.languages.map { (CVTextField.language, $0.language) }
        texts += s.certifications.flatMap { [(CVTextField.certificationName, $0.name), (.certificationIssuer, $0.issuer),
                                             (.certificationDescription, $0.description)] }
        texts += s.profiles.map { (CVTextField.profilePlatform, $0.platform) }
        texts += s.interests.map { (CVTextField.interest, $0) }
        for (field, text) in texts where text.utf8.count > CVLimits.maxTextBytes || text.count > CVLimits.maxTextCharacters {
            return .textTooLong(field)
        }
        let sizes: [(CVSection, Int)] = [(.experiences, s.experiences.count), (.education, s.education.count), (.skills, s.skills.count),
                                         (.languages, s.languages.count), (.certifications, s.certifications.count),
                                         (.profiles, s.profiles.count), (.interests, s.interests.count)]
        if let (section, _) = sizes.first(where: { $0.1 > CVLimits.maxEntriesPerSection }) { return .tooManyEntries(section) }
        let notPlaced = draft?.notPlaced ?? []
        let draftTexts = notPlaced.map(\.text) + notPlaced.compactMap(\.heading)
        if notPlaced.count > CVLimits.maxEntriesPerSection
            || draftTexts.contains(where: { $0.utf8.count > CVLimits.maxTextBytes || $0.count > CVLimits.maxTextCharacters }) {
            return .cvTooLarge
        }
        // The addresses and the language tag count too: they are printed. Each has its own bound, so no field is named for them.
        // The draft's texts count as well: they are stored with the CV.
        let others = [p.email?.value, p.phone?.value, p.website?.value, language?.tag].compactMap { $0 }
            + s.certifications.compactMap { $0.link?.value } + s.profiles.map { $0.link.value } + draftTexts
        let total = texts.reduce(0) { $0 + $1.text.utf8.count } + others.reduce(0) { $0 + $1.utf8.count }
        return total > CVLimits.maxTotalTextBytes ? .cvTooLarge : .ok
    }
}

import Foundation

/// The personal items of a grounded draft that the claim check judges (ADR 0028), in a fixed order: the headline title, the place,
/// the skills, the languages and the interests. A blank value is no candidate, and an item that repeats another of its kind is
/// judged once. A skill is one only when the description names it: one it does not name, the model wrote for the person's role, and
/// no clause of the description can claim or deny it (ADR 0031).
enum ClaimCandidates {
    static func of(_ cvData: CVData, in description: String) -> [ClaimCandidate] {
        let source = DescriptionText(description)
        var candidates: [ClaimCandidate] = []
        var seen = Set<ClaimCandidate>()
        func add(_ kind: ClaimCandidate.Kind, _ value: String?) {
            guard let candidate = candidate(kind, value), seen.insert(candidate).inserted else { return }
            candidates.append(candidate)
        }
        add(.title, cvData.personalInfo.title)
        add(.place, cvData.personalInfo.location)
        cvData.skills.filter { source.named($0.name) != nil }.forEach { add(.skill, $0.name) }
        cvData.languages.forEach { add(.language, $0.name) }
        cvData.interests.forEach { add(.interest, $0) }
        return candidates
    }

    /// The candidate an item of `kind` gives, or nil when its value is blank.
    static func candidate(_ kind: ClaimCandidate.Kind, _ value: String?) -> ClaimCandidate? {
        value.presentValue.map { ClaimCandidate(kind: kind, value: $0) }
    }
}

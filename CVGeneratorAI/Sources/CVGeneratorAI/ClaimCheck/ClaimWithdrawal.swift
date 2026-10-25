import Foundation

/// Applies the claim check to a grounded draft (ADR 0028). It only ever removes: a personal item stays when the check judged it a
/// fact about the writer, and everything the check does not judge (the name, the contacts, the summary, the jobs, the schools,
/// their dates and the certifications) stays as the rules left it.
enum ClaimWithdrawal {
    /// The grounded draft with only the personal items `checker` calls facts. When the check gives no answer (a failed call or a
    /// refusal), every personal item it would have judged is withdrawn and the draft says so: never a retry, and never the rules
    /// alone. Cancellation passes through.
    static func checking(_ grounded: CVData, in description: String, with checker: any ClaimChecking) async throws -> GeneratedDraft {
        let candidates = ClaimCandidates.of(grounded)
        guard !candidates.isEmpty else { return GeneratedDraft(cvData: grounded, personalItemsUnchecked: false) }

        do {
            let judgements = try await checker.judgements(of: candidates, in: description)
            return GeneratedDraft(cvData: keepingFacts(of: grounded, candidates: candidates, judgements: judgements),
                                  personalItemsUnchecked: false)
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            // A check stopped by a cancellation may report it with an error of its own.
            try Task.checkCancellation()
            return GeneratedDraft(cvData: withdrawingAll(from: grounded), personalItemsUnchecked: true)
        }
    }

    /// The draft without the personal items that the judgements do not call a fact. `judgements` answer `candidates` in order; a
    /// candidate with no judgement, as when the answer is short, is withdrawn. A language goes with its level.
    static func keepingFacts(of cvData: CVData, candidates: [ClaimCandidate], judgements: [ClaimJudgement]) -> CVData {
        let facts = Set(zip(candidates, judgements).filter { $0.1.stance == .fact }.map(\.0))
        func isFact(_ kind: ClaimCandidate.Kind, _ value: String?) -> Bool {
            ClaimCandidates.candidate(kind, value).map(facts.contains) ?? false
        }
        let info = cvData.personalInfo
        return CVData(
            personalInfo: PersonalInfo(
                name: info.name, email: info.email, phone: info.phone,
                location: isFact(.place, info.location) ? info.location : nil,
                website: info.website, linkedin: info.linkedin, github: info.github,
                title: isFact(.title, info.title) ? info.title : nil
            ),
            summary: cvData.summary, experience: cvData.experience, education: cvData.education,
            skills: cvData.skills.filter { isFact(.skill, $0.name) },
            languages: cvData.languages.filter { isFact(.language, $0.name) },
            certifications: cvData.certifications,
            interests: cvData.interests.filter { isFact(.interest, $0) }
        )
    }

    /// The draft without any of the personal items the check judges, for when it gave no answer: the person adds them by hand.
    static func withdrawingAll(from cvData: CVData) -> CVData {
        keepingFacts(of: cvData, candidates: [], judgements: [])
    }
}

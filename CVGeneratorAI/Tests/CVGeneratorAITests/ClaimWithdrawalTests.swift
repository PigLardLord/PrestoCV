import Testing
import Foundation
@testable import CVGeneratorAI

/// Which personal items the claim check judges, and what its judgements leave of a draft (ADR 0028).
@Suite("Claim check: candidates and withdrawal")
struct ClaimWithdrawalTests {
    private let draft = CVData(
        personalInfo: PersonalInfo(
            name: "Maria Rossi", email: "maria.rossi@example.com", phone: "+39 051 123456", location: "Bologna",
            website: "mariarossi.example", linkedin: "linkedin.com/in/mariarossi", github: "github.com/mariarossi", title: "teacher"
        ),
        summary: "Primary school teacher.",
        experience: [Experience(title: "teacher", company: "Don Milani school", startDate: "2016", current: true)],
        education: [Education(degree: "Education Sciences", institution: "University of Bologna", endDate: "2012")],
        skills: [Skill(name: "Excel", level: .advanced), Skill(name: "Swift")],
        languages: [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .b2)],
        certifications: [Certification(name: "TEFL")],
        interests: ["chess", "hiking"]
    )

    private func judged(_ stances: [String: ClaimStance], count: Int? = nil) -> [ClaimJudgement] {
        let candidates = ClaimCandidates.of(draft)
        let judgements = candidates.map { ClaimJudgement(stance: stances[$0.value] ?? .fact, quote: "") }
        return count.map { Array(judgements.prefix($0)) } ?? judgements
    }

    // MARK: - Candidates

    @Test("The candidates are the headline title, the place, the skills, the languages and the interests, in that order")
    func candidatesInOrder() {
        #expect(ClaimCandidates.of(draft) == [
            ClaimCandidate(kind: .title, value: "teacher"), ClaimCandidate(kind: .place, value: "Bologna"),
            ClaimCandidate(kind: .skill, value: "Excel"), ClaimCandidate(kind: .skill, value: "Swift"),
            ClaimCandidate(kind: .language, value: "Italian"), ClaimCandidate(kind: .language, value: "English"),
            ClaimCandidate(kind: .interest, value: "chess"), ClaimCandidate(kind: .interest, value: "hiking"),
        ])
    }

    @Test("Jobs, schools, the name, the contacts, the summary and the certifications are not candidates")
    func onlyThePersonalKinds() {
        let values = Set(ClaimCandidates.of(draft).map(\.value))
        for value in ["Maria Rossi", "maria.rossi@example.com", "Don Milani school", "University of Bologna", "Education Sciences",
                      "Primary school teacher.", "TEFL", "2016"] {
            #expect(!values.contains(value), "\(value) is not for the claim check")
        }
    }

    @Test("A blank value or the word null is no candidate, and a repeated item is judged once")
    func blanksAndRepeats() {
        let cvData = CVData(
            personalInfo: PersonalInfo(location: "  ", title: "null"),
            skills: [Skill(name: "Excel"), Skill(name: " Excel "), Skill(name: "")],
            interests: ["Excel"]
        )

        #expect(ClaimCandidates.of(cvData) == [ClaimCandidate(kind: .skill, value: "Excel"), ClaimCandidate(kind: .interest, value: "Excel")])
    }

    // MARK: - Withdrawal

    @Test("Every item judged a fact stays as it is")
    func factsStay() {
        #expect(ClaimWithdrawal.keepingFacts(of: draft, candidates: ClaimCandidates.of(draft), judgements: judged([:])) == draft)
    }

    @Test("An item read as a wish, a denial, another person's or not mentioned is withdrawn",
          arguments: [ClaimStance.wish, .denied, .otherPerson, .notMentioned])
    func nonFactsGo(stance: ClaimStance) {
        let stances: [String: ClaimStance] = ["teacher": stance, "Bologna": stance, "Swift": stance, "English": stance, "chess": stance]
        let result = ClaimWithdrawal.keepingFacts(of: draft, candidates: ClaimCandidates.of(draft), judgements: judged(stances))

        #expect(result.personalInfo.title == nil)
        #expect(result.personalInfo.location == nil)
        #expect(result.skills == [Skill(name: "Excel", level: .advanced)], "A kept skill keeps its level")
        #expect(result.languages == [Language(name: "Italian", proficiency: .native)], "The level of English goes with it")
        #expect(result.interests == ["hiking"])
    }

    @Test("An item the answer does not judge is withdrawn")
    func missingVerdictWithdraws() {
        let result = ClaimWithdrawal.keepingFacts(of: draft, candidates: ClaimCandidates.of(draft), judgements: judged([:], count: 5))

        #expect(result.personalInfo.title == "teacher")
        #expect(result.skills.map(\.name) == ["Excel", "Swift"])
        #expect(result.languages.map(\.name) == ["Italian"])
        #expect(result.interests.isEmpty)
    }

    @Test("A repeated item follows its one judgement")
    func repeatsFollowTheirJudgement() {
        let cvData = CVData(skills: [Skill(name: "Excel"), Skill(name: "Excel", level: .expert), Skill(name: "Word")])
        let candidates = ClaimCandidates.of(cvData)
        let judgements = [ClaimJudgement(stance: .wish, quote: ""), ClaimJudgement(stance: .fact, quote: "")]

        #expect(ClaimWithdrawal.keepingFacts(of: cvData, candidates: candidates, judgements: judgements).skills == [Skill(name: "Word")])
    }

    @Test("Withdrawing all removes every personal item, and keeps the name, the contacts, the summary, jobs, schools and certifications")
    func withdrawingAll() {
        let info = draft.personalInfo
        #expect(ClaimWithdrawal.withdrawingAll(from: draft) == CVData(
            personalInfo: PersonalInfo(
                name: info.name, email: info.email, phone: info.phone, website: info.website, linkedin: info.linkedin, github: info.github
            ),
            summary: draft.summary,
            experience: draft.experience,
            education: draft.education,
            certifications: draft.certifications
        ))
    }
}

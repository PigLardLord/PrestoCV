import Testing
import Foundation
@testable import CVGeneratorAI

/// Which personal items the claim check judges, and what its judgements leave of a draft (ADR 0028, and ADR 0031 for the skills the
/// description does not name).
@Suite("Claim check: candidates and withdrawal")
struct ClaimWithdrawalTests {
    /// A description that names every personal item of `draft`, and the skills `Skill1` to `Skill20` of `skills(_:)`.
    private let description = """
        I am Maria Rossi, a teacher in Bologna. I use Excel and Swift. I speak Italian and English. I like chess and hiking.
        Skills: \((1...20).map { "Skill\($0)" }.joined(separator: ", ")).
        """

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

    private func judged(_ stances: [String: ClaimStance]) -> [ClaimJudgement] {
        ClaimCandidates.of(draft, in: description).map { ClaimJudgement(stance: stances[$0.value] ?? .fact, quote: "") }
    }

    // MARK: - Candidates

    @Test("The candidates are the headline title, the place, the skills, the languages and the interests, in that order")
    func candidatesInOrder() {
        #expect(ClaimCandidates.of(draft, in: description) == [
            ClaimCandidate(kind: .title, value: "teacher"), ClaimCandidate(kind: .place, value: "Bologna"),
            ClaimCandidate(kind: .skill, value: "Excel"), ClaimCandidate(kind: .skill, value: "Swift"),
            ClaimCandidate(kind: .language, value: "Italian"), ClaimCandidate(kind: .language, value: "English"),
            ClaimCandidate(kind: .interest, value: "chess"), ClaimCandidate(kind: .interest, value: "hiking"),
        ])
    }

    @Test("Jobs, schools, the name, the contacts, the summary and the certifications are not candidates")
    func onlyThePersonalKinds() {
        let values = Set(ClaimCandidates.of(draft, in: description).map(\.value))
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

        #expect(ClaimCandidates.of(cvData, in: "Excel") == [
            ClaimCandidate(kind: .skill, value: "Excel"), ClaimCandidate(kind: .interest, value: "Excel"),
        ])
    }

    @Test("A skill the description does not name is no candidate: the model wrote it for the role, and no clause can claim it (ADR 0031)")
    func onlyNamedSkillsAreCandidates() {
        let cvData = CVData(skills: [Skill(name: "Kubernetes"), Skill(name: "Excel"), Skill(name: "Teamwork", kind: .softSkill)])

        #expect(ClaimCandidates.of(cvData, in: "I use Excel every day.") == [ClaimCandidate(kind: .skill, value: "Excel")])
    }

    // MARK: - Withdrawal

    @Test("Every item judged a fact stays as it is")
    func factsStay() {
        #expect(ClaimWithdrawal.keepingFacts(of: draft, candidates: ClaimCandidates.of(draft, in: description), judgements: judged([:])) == draft)
    }

    @Test("An item read as a wish, a denial, another person's or not mentioned is withdrawn",
          arguments: [ClaimStance.wish, .denied, .otherPerson, .notMentioned])
    func nonFactsGo(stance: ClaimStance) {
        let stances: [String: ClaimStance] = ["teacher": stance, "Bologna": stance, "Swift": stance, "English": stance, "chess": stance]
        let result = ClaimWithdrawal.keepingFacts(of: draft, candidates: ClaimCandidates.of(draft, in: description), judgements: judged(stances))

        #expect(result.personalInfo.title == nil)
        #expect(result.personalInfo.location == nil)
        #expect(result.skills == [Skill(name: "Excel", level: .advanced)], "A kept skill keeps its level")
        #expect(result.languages == [Language(name: "Italian", proficiency: .native)], "The level of English goes with it")
        #expect(result.interests == ["hiking"])
    }

    @Test("A repeated item follows its one judgement")
    func repeatsFollowTheirJudgement() {
        let cvData = CVData(skills: [Skill(name: "Excel"), Skill(name: "Excel", level: .expert), Skill(name: "Word")])
        let candidates = ClaimCandidates.of(cvData, in: "Excel and Word")
        let judgements = [ClaimJudgement(stance: .wish, quote: ""), ClaimJudgement(stance: .fact, quote: "")]

        #expect(ClaimWithdrawal.keepingFacts(of: cvData, candidates: candidates, judgements: judgements).skills == [Skill(name: "Word")])
    }

    @Test("A skill the check did not judge stays as the rules left it, and a blank one goes (ADR 0031)")
    func unjudgedSkillsStay() {
        let cvData = CVData(skills: [Skill(name: "Excel"), Skill(name: "Kubernetes"), Skill(name: "Teamwork", kind: .softSkill), Skill(name: " ")])
        let candidates = ClaimCandidates.of(cvData, in: "I used Excel once.")
        let judgements = [ClaimJudgement(stance: .wish, quote: "")]

        #expect(ClaimWithdrawal.keepingFacts(of: cvData, candidates: candidates, judgements: judgements).skills == [
            Skill(name: "Kubernetes"), Skill(name: "Teamwork", kind: .softSkill),
        ])
    }

    @Test("Withdrawing all removes every skill, those the description names and those the model wrote (ADR 0028 (ii), ADR 0031)")
    func withdrawingAllRemovesEverySkill() {
        let cvData = CVData(skills: [Skill(name: "Excel"), Skill(name: "Kubernetes"), Skill(name: "Teamwork", kind: .softSkill)])

        #expect(ClaimWithdrawal.withdrawingAll(from: cvData).skills.isEmpty)
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

    @Test("The fixture fills every field of the draft and of its personal information")
    func fixtureFillsEveryField() {
        #expect(emptyFields(of: draft) == [])
        #expect(emptyFields(of: draft.personalInfo) == [])
    }

    @Test("Withdrawing all clears the five personal kinds and leaves every other field as it was, whatever fields the models have")
    func withdrawingAllLeavesTheRest() {
        let withdrawn = ClaimWithdrawal.withdrawingAll(from: draft)

        let lists: Set = ["skills", "languages", "interests"]
        let personalInfo: Set = ["title", "location"]
        #expect(changedFields(from: draft, to: withdrawn) == lists.union(["personalInfo"]))
        #expect(changedFields(from: draft.personalInfo, to: withdrawn.personalInfo) == personalInfo)
        #expect(emptyFields(of: withdrawn) == lists)
        #expect(emptyFields(of: withdrawn.personalInfo) == personalInfo)
    }

    /// The labels of the stored properties of `value` that hold nothing: no value, an empty text or an empty list.
    private func emptyFields(of value: Any) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap { child -> String? in
            let inner = Mirror(reflecting: child.value)
            let isEmpty = switch inner.displayStyle {
            case .optional, .collection: inner.children.isEmpty
            default: (child.value as? String)?.isEmpty == true
            }
            return isEmpty ? child.label : nil
        })
    }

    /// The labels of the stored properties of `before` that `after` holds differently.
    private func changedFields<T>(from before: T, to after: T) -> Set<String> {
        func described(_ value: T) -> [String: String] {
            Dictionary(uniqueKeysWithValues: Mirror(reflecting: value).children.compactMap { child in
                child.label.map { ($0, String(describing: child.value)) }
            })
        }
        let (was, now) = (described(before), described(after))
        return Set(was.keys.filter { was[$0] != now[$0] })
    }

    // MARK: - A title the person writes of themselves (D5)

    @Test("d5: a headline the person writes word for word as what they are stays when the check judges it no fact (#354, D5)",
          arguments: [
              ("Mi chiamo Chiara e sono impiegata amministrativa a Verona.", "impiegata amministrativa"),
              ("Lavoro come magazziniere, di notte.", "magazziniere"), ("I am a nurse.", "nurse"), ("I'm a nurse in Leeds.", "nurse"),
              ("I work as a plumber and I fix pipes.", "plumber"), ("Ich bin Bäckerin bei Müller.", "Bäckerin"),
              ("Je suis comptable.", "comptable"), ("Soy camarero en Sevilla.", "camarero"), ("Sou motorista de caminhão.", "motorista de caminhão"),
          ])
    func selfTitleStays(description: String, title: String) async throws {
        let grounded = CVData(personalInfo: PersonalInfo(title: title))
        let checker = FakeClaimChecker(stances: [title: .wish])

        let draft = try await ClaimWithdrawal.checking(grounded, in: description, with: checker)

        #expect(draft.cvData.personalInfo.title == title)
    }

    @Test("d5: a wish, another person's title, a denial, a limit, a title after a word that opens no clause of the person, or one not written word for word goes when the check judges it no fact (#354, D5)",
          arguments: [
              ("Vorrei essere impiegata amministrativa.", "impiegata amministrativa"),
              ("Mia sorella è impiegata amministrativa.", "impiegata amministrativa"),
              ("Sono impiegata a Verona.", "impiegata amministrativa"), ("Non sono infermiere.", "infermiere"),
              ("I am not a nurse.", "nurse"), ("I am a nurse, but only in a video game.", "nurse"),
              ("I am a doctor in a video game.", "doctor"), ("My sister says that I am a nurse.", "nurse"),
              ("I want to work as a plumber.", "plumber"), ("Il mio lavoro come magazziniere è finito.", "magazziniere"),
              ("No soy camarero.", "camarero"), ("Ich bin kein Bäcker.", "Bäcker"),
          ])
    func otherTitlesGo(description: String, title: String) async throws {
        let grounded = CVData(personalInfo: PersonalInfo(title: title))
        let checker = FakeClaimChecker(stances: [title: .wish])

        let draft = try await ClaimWithdrawal.checking(grounded, in: description, with: checker)

        #expect(draft.cvData.personalInfo.title == nil)
    }

    @Test("d5: no title of the hand-written claim sets that the writer does not claim is one the person writes of themselves (#354, D5)")
    func adversarialTitlesAreNotSelfTitles() {
        let sets = AdversarialSet.sentences + AdversarialSet.heldOut + AdversarialSet.frozenHeldOut
        let said = sets.flatMap { sentence in
            sentence.items.filter { $0.candidate.kind == .title && !$0.claimed }
                .filter { StatedTitle.isSaidOfItself($0.candidate.value, in: sentence.description) }.map { "\(sentence.id): \($0.candidate.value)" }
        }

        #expect(said.isEmpty)
    }

    // MARK: - Checking

    /// A draft of `count` skills, `Skill1`, `Skill2`, and so on, and nothing else.
    private func skills(_ count: Int) -> CVData {
        CVData(skills: (1...count).map { Skill(name: "Skill\($0)") })
    }

    private func names(_ cvData: CVData) -> [String] {
        cvData.skills.map(\.name)
    }

    @Test("The candidates go to the checker in batches of the size given, in order, one call each")
    func batches() async throws {
        let checker = FakeClaimChecker()
        let limits = ClaimCheckLimits(batchSize: 8, time: .seconds(60))

        let draft = try await ClaimWithdrawal.checking(skills(20), in: description, with: checker, within: limits)

        #expect(await checker.calls.map(\.candidates.count) == [8, 8, 4])
        #expect(await checker.calls.flatMap(\.candidates).map(\.value) == (1...20).map { "Skill\($0)" })
        #expect(await Set(checker.calls.map(\.description)) == [description])
        #expect(draft == GeneratedDraft(cvData: skills(20), personalItemsUnchecked: false))
    }

    @Test("A draft as long as a batch, or shorter, takes one call")
    func oneBatch() async throws {
        for count in [1, 8] {
            let checker = FakeClaimChecker()
            let limits = ClaimCheckLimits(batchSize: 8, time: .seconds(60))

            _ = try await ClaimWithdrawal.checking(skills(count), in: description, with: checker, within: limits)

            #expect(await checker.calls.map(\.candidates.count) == [count])
        }
    }

    @Test("A batch size below one is one")
    func smallestBatch() async throws {
        let checker = FakeClaimChecker()

        _ = try await ClaimWithdrawal.checking(skills(3), in: description, with: checker, within: ClaimCheckLimits(batchSize: 0, time: .seconds(60)))

        #expect(await checker.calls.map(\.candidates.count) == [1, 1, 1])
    }

    @Test("Each batch is judged for itself: a non-fact withdraws only its own item, in any batch")
    func judgementsFollowTheirBatch() async throws {
        let checker = FakeClaimChecker(stances: ["Skill3": .wish, "Skill9": .denied, "Skill20": .otherPerson])
        let limits = ClaimCheckLimits(batchSize: 8, time: .seconds(60))

        let draft = try await ClaimWithdrawal.checking(skills(20), in: description, with: checker, within: limits)

        #expect(names(draft.cvData) == (1...20).filter { ![3, 9, 20].contains($0) }.map { "Skill\($0)" })
        #expect(draft.personalItemsUnchecked == false)
    }

    @Test("A batch that fails gives no answer: no item stays, the later batches are not asked and nothing is retried",
          arguments: [CVGenerationError.generationFailed, .busy])
    func failedBatch(failure: CVGenerationError) async throws {
        let checker = FakeClaimChecker(failure: failure, afterCalls: 1)
        let limits = ClaimCheckLimits(batchSize: 8, time: .seconds(60))

        let draft = try await ClaimWithdrawal.checking(skills(20), in: description, with: checker, within: limits)

        #expect(draft == GeneratedDraft(cvData: CVData(), personalItemsUnchecked: true))
        #expect(await checker.calls.map(\.candidates.count) == [8, 8])
    }

    @Test("An answer that judges fewer items than its batch asked is no answer, whichever the batch",
          arguments: [(0, 0), (0, 3), (1, 0), (1, 7), (2, 3)])
    func shortAnswer(afterCalls: Int, judged: Int) async throws {
        let checker = FakeClaimChecker(verdictLimit: judged, afterCalls: afterCalls)
        let limits = ClaimCheckLimits(batchSize: 8, time: .seconds(60))

        let draft = try await ClaimWithdrawal.checking(skills(20), in: description, with: checker, within: limits)

        #expect(draft == GeneratedDraft(cvData: CVData(), personalItemsUnchecked: true))
    }

    @Test("A check that does not finish in its time gives no answer, and the kept items of the batches before are not kept",
          .timeLimit(.minutes(1)), arguments: [0, 1])
    func timedOut(answeredBefore: Int) async throws {
        let checker = FakeClaimChecker(hangs: true, afterCalls: answeredBefore)
        let limits = ClaimCheckLimits(batchSize: 8, time: .milliseconds(100))

        let draft = try await ClaimWithdrawal.checking(skills(20), in: description, with: checker, within: limits)

        #expect(draft == GeneratedDraft(cvData: CVData(), personalItemsUnchecked: true))
        #expect(await checker.calls.count == answeredBefore + 1)
    }

    @Test("A task cancelled while the check runs gets the cancellation, not a draft", .timeLimit(.minutes(1)))
    func cancelledWhileChecking() async {
        let (asked, signal) = AsyncStream.makeStream(of: Void.self)
        let checker = FakeClaimChecker(hangs: true, whenAsked: { signal.yield() })
        let cvData = skills(3)
        let description = description

        let checking = Task { try await ClaimWithdrawal.checking(cvData, in: description, with: checker) }
        for await _ in asked { break }
        checking.cancel()

        await #expect(throws: CancellationError.self) {
            try await checking.value
        }
    }
}

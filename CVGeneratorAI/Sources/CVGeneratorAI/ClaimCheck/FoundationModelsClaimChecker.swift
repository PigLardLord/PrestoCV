#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// The claim check on Apple's on-device model (ADR 0028): one call per draft judges every candidate, with a fixed instruction, greedy
/// decoding and structured output. For each candidate the model quotes its sentence and says whose it is and how the sentence states
/// it; only the writer's item stated as true is a fact. A candidate the answer leaves out counts as not mentioned: the check fails
/// closed.
@available(iOS 26, macOS 26, *)
public struct FoundationModelsClaimChecker: ClaimChecking {
    public init() {}

    public func judgements(of candidates: [ClaimCandidate], in description: String) async throws -> [ClaimJudgement] {
        guard !candidates.isEmpty else { return [] }
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(
            to: Self.prompt(for: candidates, in: description),
            generating: ClaimVerdicts.self,
            includeSchemaInPrompt: true,
            options: GenerationOptions(samplingMode: .greedy)
        )
        var judgements: [Int: ClaimJudgement] = [:]
        for verdict in response.content.verdicts where judgements[verdict.item] == nil {
            judgements[verdict.item] = ClaimJudgement(stance: verdict.stance, quote: verdict.quote)
        }
        return candidates.indices.map { judgements[$0 + 1] ?? ClaimJudgement(stance: .notMentioned, quote: "") }
    }

    static let instructions = """
        You check the items of a CV draft against the description that a person wrote about themselves. For each numbered item, \
        copy the sentence of the description that names it, then answer two questions about that sentence.
        Owner: whose is the item in that sentence?
        - writer: the person who wrote it ("I", "me", "my", or no subject, as a CV writes: "Nurse in Turin", "Skills: Excel"). \
        A list under a heading such as "Competenze:", "Kenntnisse:", "Habilidades:", "Compétences :" or "Idiomas:" is the \
        writer's, unless the heading names someone else or a wish.
        - someoneElse: another person, such as a sister or a colleague, or "he" or "she". In "My sister is a nurse and speaks \
        French", the nurse, the place and French are all the sister's. The same holds when the verb belongs to someone the \
        writer names: in "I work with a nurse", "The team that I lead uses Kotlin" and "a company where everyone speaks \
        French", the nurse, Kotlin and French are not the writer's.
        - notMentioned: no sentence names the item. A question ("Do you speak German?") states nothing about the writer, and \
        it does not change whose the next sentence is.
        Mood: how does that sentence state it?
        - statedAsTrue: the writer has, knows, likes, loves, enjoys, uses, does, did or is it, or had to do it, now or in the \
        past. "I like chess", "I love hiking", "mi piace", "ich mag", "me gusta", "j'aime", "gosto de", "I had to speak English", \
        "tuve que", "tive que", "I can", "mostly", "partly", "not an expert", "not fluent", "basic knowledge" still state it as \
        true. A wish to do it better does not take it back: in "I speak Italian and French, which I'd like to improve", the \
        writer speaks both.
        - wished: the writer only wants, would like, would love, would prefer, hopes, dreams of, plans, looks for, will do or \
        will have to do it: "I'd like", "I will", "I am going to", "looking for a job at", "würde gern", "vorrei", \
        "mi piacerebbe", "lavorerò", "me gustaría", "j'aimerais", "gostaria", "sogno di", "träume davon". "I like" is a fact; \
        only "I'd like" and "I would like" are wishes.
        - conditional: it depends on a condition or is imagined: "would", "if I had", "würde", "sarei", "sería", "serais", "seria".
        - denied: the writer says they do not have it, never did it, cannot do it, or have no knowledge of it, not even basic.
        A job title or a place inside a wish or a conditional is wished or conditional too: "I would work as a teacher in \
        Berlin" does not state that the writer is a teacher or lives in Berlin. A wish or a condition in another sentence \
        does not change this one: in "I play chess. If I had time, I would play more", chess is statedAsTrue. \
        People often type without accents or umlauts: \
        "seria" can be "sería" (would be), "wurde" can be "würde" (would), "gerne wurde ich" is "gerne würde ich". \
        Read the description in its own language, and answer every item, in order.
        """

    static func prompt(for candidates: [ClaimCandidate], in description: String) -> String {
        let items = candidates.enumerated().map { index, candidate in
            "\(index + 1). \(label(of: candidate.kind)): \(candidate.value)"
        }
        return "Description:\n\"\"\"\n\(description)\n\"\"\"\n\nItems:\n" + items.joined(separator: "\n")
    }

    private static func label(of kind: ClaimCandidate.Kind) -> String {
        switch kind {
        case .skill: return "skill"
        case .language: return "language the writer speaks"
        case .interest: return "hobby or interest"
        case .title: return "the writer's job title"
        case .place: return "the place where the writer lives or works"
        }
    }
}

@Generable
struct ClaimVerdicts {
    @Guide(description: "One verdict for each numbered item, in the order of the items")
    let verdicts: [ClaimVerdict]
}

@Generable
struct ClaimVerdict {
    @Guide(description: "The number of the item")
    let item: Int

    @Guide(description: "The sentence of the description that mentions the item, copied exactly; empty if none does")
    let quote: String

    @Guide(description: "Whose the item is in that sentence")
    let owner: ClaimOwner

    @Guide(description: "How that sentence states the item")
    let mood: ClaimMood

    /// Only the writer's item, stated as true, is a fact.
    var stance: ClaimStance {
        switch owner {
        case .notMentioned: return .notMentioned
        case .someoneElse: return .otherPerson
        case .writer:
            switch mood {
            case .statedAsTrue: return .fact
            case .wished, .conditional: return .wish
            case .denied: return .denied
            }
        }
    }
}

@Generable
enum ClaimOwner {
    case writer, someoneElse, notMentioned
}

@Generable
enum ClaimMood {
    case statedAsTrue, wished, conditional, denied
}
#endif

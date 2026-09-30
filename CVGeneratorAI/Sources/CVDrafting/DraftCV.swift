import Foundation

// MARK: - Ports

/// Whether a model can draft now, and if not, why: the app says so instead of offering the feature.
public enum DraftAvailability: Hashable, Sendable {
    public enum Reason: Hashable, Sendable, CaseIterable { case appleIntelligenceDisabled, deviceNotEligible, modelNotReady }
    case available
    case unavailable(Reason)
}

/// A model that drafts a CV from a description. Implementations throw what the model throws: the use case maps it.
/// Cancelling the calling task, or ending the stream, stops the model.
public protocol DraftGenerating: Sendable {
    func availability() async -> DraftAvailability
    func draft(from description: String, language: String) async throws -> CVDraft
    /// Snapshots of the draft as it grows; the last one is the result.
    func stream(from description: String, language: String) -> AsyncThrowingStream<CVDraft, any Error>
}

// MARK: - Errors

/// Why no draft came back. Cancellation is not one of them: it ends in `CancellationError`.
public enum DraftingError: Error, Hashable, Sendable {
    // The request
    case descriptionTooShort, descriptionTooLong
    /// The language is not a BCP 47 tag, or the model does not support it.
    case unsupportedLanguage
    case unavailable(DraftAvailability.Reason)

    // The model, one case per failure it reports
    case contextWindowExceeded, assetsUnavailable, guardrailViolation, refusal, decodingFailure, rateLimited, concurrentRequests
    /// Any other failure of the model or of its adapter.
    case generationFailed

    // The draft
    /// The draft holds no text: it is never handed on as a CV.
    case emptyDraft
    /// A text or a list in the draft is over its limit.
    case oversizedDraft
}

// MARK: - Use case

/// Drafts a CV from the user's description: checks the request and the model's availability before asking the model,
/// then checks what comes back. Streaming follows the same path, snapshot by snapshot (ADR 0007).
public struct DraftCV: Sendable {
    /// Limits on the description, in characters after trimming; the upper one counts Unicode scalars, so combining
    /// marks cannot stretch it.
    public static let minDescriptionCharacters = 10, maxDescriptionCharacters = 4000
    /// Limits on the draft: each text, in Unicode scalars, and each list.
    public static let maxTextCharacters = 2000, maxItems = 50

    private let generator: any DraftGenerating

    public init(generator: any DraftGenerating) { self.generator = generator }

    public func callAsFunction(_ description: String, language: String) async throws -> CVDraft {
        let request = try await prepare(description, language)
        let draft: CVDraft
        do { draft = try await generator.draft(from: request.description, language: request.language) }
        catch { throw Self.mapped(error) }
        try Task.checkCancellation()
        try Self.checkLimits(draft)
        guard !draft.isBlank else { throw DraftingError.emptyDraft }
        return draft
    }

    /// Snapshots within the limits, as the model produces them; blank ones are skipped. The stream ends with an error
    /// when a snapshot is over the limits, or when the last one is blank.
    public func stream(_ description: String, language: String) -> AsyncThrowingStream<CVDraft, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try await prepare(description, language)
                    var snapshots = generator.stream(from: request.description, language: request.language).makeAsyncIterator()
                    var last: CVDraft?
                    while true {
                        let next: CVDraft?
                        do { next = try await snapshots.next() } catch { throw Self.mapped(error) }
                        guard let snapshot = next else { break }
                        try Self.checkLimits(snapshot)
                        last = snapshot
                        if !snapshot.isBlank { continuation.yield(snapshot) }
                    }
                    try Task.checkCancellation()
                    guard let last, !last.isBlank else { throw DraftingError.emptyDraft }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Checks

    /// The trimmed description and the canonical language tag, once the model is known to be available.
    private func prepare(_ description: String, _ language: String) async throws -> (description: String, language: String) {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.unicodeScalars.count <= Self.maxDescriptionCharacters else { throw DraftingError.descriptionTooLong }
        guard text.count >= Self.minDescriptionCharacters else { throw DraftingError.descriptionTooShort }
        guard let tag = Self.languageTag(language) else { throw DraftingError.unsupportedLanguage }
        if case .unavailable(let reason) = await generator.availability() { throw DraftingError.unavailable(reason) }
        try Task.checkCancellation()
        return (text, tag)
    }

    private static func checkLimits(_ draft: CVDraft) throws {
        guard draft.listLengths.allSatisfy({ $0 <= maxItems }),
              draft.texts.allSatisfy({ ($0 ?? "").unicodeScalars.count <= maxTextCharacters })
        else { throw DraftingError.oversizedDraft }
    }

    /// What the model threw, as the use case reports it: a cancelled task ends in a cancellation, whatever the model
    /// threw on the way out; a drafting error keeps its case; anything else is a generation failure.
    private static func mapped(_ error: any Error) -> any Error {
        if Task.isCancelled || error is CancellationError { return CancellationError() }
        if let drafting = error as? DraftingError { return drafting }
        return DraftingError.generationFailed
    }

    /// A BCP 47 tag of a language, an optional script and an optional region ("it", "pt-BR", "zh-Hant-TW"), in
    /// canonical case; nil for anything else. The same grammar as the CV's document language.
    static func languageTag(_ raw: String) -> String? {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "-", omittingEmptySubsequences: false)
        guard let first = parts.first, (2...3).contains(first.count), first.allSatisfy(\.isASCIILetter), parts.count <= 3 else { return nil }
        var canonical = [first.lowercased()]
        var rest = parts.dropFirst()
        if let script = rest.first, script.count == 4, script.allSatisfy(\.isASCIILetter) {
            canonical.append(script.prefix(1).uppercased() + script.dropFirst().lowercased()); rest = rest.dropFirst()
        }
        if let region = rest.first {
            if region.count == 2, region.allSatisfy(\.isASCIILetter) { canonical.append(region.uppercased()) }
            else if region.count == 3, region.allSatisfy(\.isASCIIDigit) { canonical.append(String(region)) }
            else { return nil }
            rest = rest.dropFirst()
        }
        guard rest.isEmpty else { return nil }
        return canonical.joined(separator: "-")
    }
}

private extension Character {
    var isASCIILetter: Bool { isASCII && isLetter }
    var isASCIIDigit: Bool { isASCII && isNumber }
}

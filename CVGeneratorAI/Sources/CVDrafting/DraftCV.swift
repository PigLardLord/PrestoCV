import Foundation

// MARK: - Use case

/// Drafts a CV from the user's description: checks the request and the model's availability before asking the model,
/// then checks what comes back. Streaming follows the same path, snapshot by snapshot (ADR 0007).
public struct DraftCV: Sendable {
    /// Limits on the description, after trimming: at least `minDescriptionCharacters` characters and at most
    /// `maxDescriptionScalars` Unicode scalars, so combining marks cannot stretch the upper one.
    public static let minDescriptionCharacters = 10, maxDescriptionScalars = 4000
    /// Limits on the draft: each text holds at most `maxTextScalars` Unicode scalars, each list at most `maxItems` items.
    public static let maxTextScalars = 2000, maxItems = 50

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

    /// Snapshots within the limits, as the model produces them; blank ones are skipped.
    /// - The model is asked as soon as the stream is created, not when it is first read.
    /// - Snapshots supersede each other: a consumer that falls behind receives the newest one only.
    /// - The stream ends with an error when a snapshot is over the limits, or when the last one is blank.
    /// - A cancelled consumer sees the stream end without an error, so it checks for cancellation after its loop.
    public func stream(_ description: String, language: String) -> AsyncThrowingStream<CVDraft, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                do {
                    let request = try await prepare(description, language)
                    var last: CVDraft?
                    do {
                        for try await snapshot in generator.stream(from: request.description, language: request.language) {
                            try Self.checkLimits(snapshot)
                            last = snapshot
                            if !snapshot.isBlank { continuation.yield(snapshot) }
                        }
                    } catch { throw Self.mapped(error) }
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
        try Task.checkCancellation()
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.unicodeScalars.count <= Self.maxDescriptionScalars else { throw DraftingError.descriptionTooLong }
        guard text.count >= Self.minDescriptionCharacters else { throw DraftingError.descriptionTooShort }
        guard let tag = Self.languageTag(language) else { throw DraftingError.unsupportedLanguage }
        let availability = await generator.availability()
        try Task.checkCancellation()
        if case .unavailable(let reason) = availability { throw DraftingError.unavailable(reason) }
        return (text, tag)
    }

    private static func checkLimits(_ draft: CVDraft) throws {
        guard draft.listLengths.allSatisfy({ $0 <= maxItems }),
              draft.texts.allSatisfy({ ($0 ?? "").unicodeScalars.count <= maxTextScalars })
        else { throw DraftingError.oversizedDraft }
    }

    /// What the model threw, as the use case reports it: a cancelled task ends in a cancellation, whatever the model
    /// threw on the way out; a drafting error keeps its case; anything else is a generation failure, a
    /// `CancellationError` from a model nobody cancelled included.
    private static func mapped(_ error: any Error) -> any Error {
        if Task.isCancelled { return CancellationError() }
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

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
    /// - The model is asked when the stream is first read, in the reader's task, and each reading is a new request.
    /// - The model is stopped when the reader stops reading, is cancelled, or a snapshot is refused.
    /// - The stream ends with an error when a snapshot is over the limits, or when the last one is blank.
    /// - A cancelled reader gets `CancellationError`, as it does from `callAsFunction`.
    public func stream(_ description: String, language: String) -> Snapshots {
        Snapshots(useCase: self, description: description, language: language)
    }

    /// The snapshots of one request, read in the reader's task: the iterator asks the model on its first `next()` and
    /// holds the model's stream until it ends, fails or is dropped, and dropping it stops the model.
    public struct Snapshots: AsyncSequence, Sendable {
        public typealias Element = CVDraft

        fileprivate let useCase: DraftCV
        fileprivate let description: String, language: String

        public func makeAsyncIterator() -> Iterator {
            Iterator(useCase: useCase, description: description, language: language)
        }

        public struct Iterator: AsyncIteratorProtocol {
            private enum State {
                case notAsked
                case asked(AsyncThrowingStream<CVDraft, any Error>.Iterator, last: CVDraft?)
                case ended
            }

            private let useCase: DraftCV
            private let description: String, language: String
            private var state = State.notAsked

            fileprivate init(useCase: DraftCV, description: String, language: String) {
                self.useCase = useCase; self.description = description; self.language = language
            }

            public mutating func next() async throws -> CVDraft? {
                do {
                    return try await read()
                } catch {
                    state = .ended
                    throw error
                }
            }

            private mutating func read() async throws -> CVDraft? {
                if case .notAsked = state {
                    let request = try await useCase.prepare(description, language)
                    let models = useCase.generator.stream(from: request.description, language: request.language)
                    state = .asked(models.makeAsyncIterator(), last: nil)
                }
                guard case .asked(var models, var last) = state else { return nil }
                while true {
                    try Task.checkCancellation()
                    let next: CVDraft?
                    do { next = try await models.next() } catch { throw DraftCV.mapped(error) }
                    try Task.checkCancellation()
                    guard let snapshot = next else {
                        guard let last, !last.isBlank else { throw DraftingError.emptyDraft }
                        state = .ended
                        return nil
                    }
                    try DraftCV.checkLimits(snapshot)
                    last = snapshot
                    if !snapshot.isBlank {
                        state = .asked(models, last: last)
                        return snapshot
                    }
                }
            }
        }
    }

    // MARK: Checks

    /// The trimmed description and the canonical language tag, once the model is known to be available.
    private func prepare(_ description: String, _ language: String) async throws -> (description: String, language: String) {
        try Task.checkCancellation()
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.unicodeScalars.count <= Self.maxDescriptionScalars else { throw DraftingError.descriptionTooLong }
        guard text.count >= Self.minDescriptionCharacters else { throw DraftingError.descriptionTooShort }
        guard let tag = Self.languageTag(language) else { throw DraftingError.invalidLanguage }
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

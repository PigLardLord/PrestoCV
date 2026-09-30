// MARK: - Port

/// Whether a model can draft now, and if not, why: the app says so instead of offering the feature.
public enum DraftAvailability: Hashable, Sendable {
    public enum Reason: Hashable, Sendable, CaseIterable { case appleIntelligenceDisabled, deviceNotEligible, modelNotReady }
    case available
    case unavailable(Reason)
}

/// A model that drafts a CV from a description. An implementation:
/// - translates the failures it recognises into `DraftingError`; the use case reports any other error as `.generationFailed`;
/// - throws `CancellationError` only when the calling task is cancelled;
/// - stops the model when the calling task is cancelled or the stream ends;
/// - gives the same answer to the same request in `draft` and in the last snapshot of `stream`;
/// - bounds what the model generates, because the use case can only bound what it hands on;
/// - treats snapshots as superseding each other, so an implementation that buffers keeps the newest one only.
public protocol DraftGenerating: Sendable {
    func availability() async -> DraftAvailability
    func draft(from description: String, language: String) async throws -> CVDraft
    /// Snapshots of the draft as it grows; the last one is the result.
    func stream(from description: String, language: String) -> AsyncThrowingStream<CVDraft, any Error>
}

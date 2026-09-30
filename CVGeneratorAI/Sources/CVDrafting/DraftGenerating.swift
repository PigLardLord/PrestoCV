// MARK: - Port

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

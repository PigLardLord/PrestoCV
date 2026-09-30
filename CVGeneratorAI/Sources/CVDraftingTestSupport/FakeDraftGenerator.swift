import Foundation
import CVDrafting

/// A scripted `DraftGenerating` for tests: it answers with the draft, the stream of snapshots or the error it was given,
/// records every request and tells when it was asked and when it was stopped.
public actor FakeDraftGenerator: DraftGenerating {
    public enum Answer: Sendable {
        case draft(CVDraft), failure(DraftingError), unrecognisedError, snapshots([CVDraft])
        /// Throws `CancellationError` although nobody cancelled, as an adapter's own timeout may.
        case strayCancellation
        /// The stream yields the snapshots, then fails; `draft` fails with the error.
        case snapshotsThenFailure([CVDraft], DraftingError)
        /// Yields the snapshots, then waits until the task is cancelled, then throws `CancellationError`.
        case waitForCancellation(after: [CVDraft] = [])
        /// Waits until the task is cancelled, then throws the given error, as a model may on its way out.
        case failWhenCancelled(DraftingError)
        /// Waits until the task is cancelled, then answers with the draft all the same.
        case draftWhenCancelled(CVDraft)
    }

    public enum Event: Hashable, Sendable {
        /// `availability()` was called.
        case availabilityAsked
        /// `draft` or `stream` was called.
        case asked
        /// The stream was ended from outside before it finished: the model was stopped.
        case stopped
    }

    public struct Request: Hashable, Sendable {
        public let description: String, language: String
        public init(description: String, language: String) { self.description = description; self.language = language }
    }

    /// How long the fake waits for a cancellation that never comes, so that a test waiting on it fails instead of hanging.
    private static let patience: Duration = .seconds(5)

    private let scriptedAvailability: DraftAvailability
    private let availabilityWaitsForCancellation: Bool
    private let answer: Answer
    public private(set) var requests: [Request] = []
    private var seen: Set<Event> = []
    private var waiters: [UUID: (event: Event, continuation: CheckedContinuation<Bool, Never>)] = [:]

    public init(availability: DraftAvailability = .available, availabilityWaitsForCancellation: Bool = false, answer: Answer) {
        self.scriptedAvailability = availability
        self.availabilityWaitsForCancellation = availabilityWaitsForCancellation
        self.answer = answer
    }

    /// True once the event has happened; false when it has not within the limit.
    public func happened(_ event: Event, within limit: Duration = .seconds(5)) async -> Bool {
        if seen.contains(event) { return true }
        let id = UUID()
        var timer: Task<Void, Never>?
        let happened = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            waiters[id] = (event, continuation)
            timer = Task {
                do { try await Task.sleep(for: limit) } catch { return }
                expire(id)
            }
        }
        timer?.cancel()
        return happened
    }

    public func availability() async -> DraftAvailability {
        signal(.availabilityAsked)
        if availabilityWaitsForCancellation { try? await Task.sleep(for: Self.patience) }
        return scriptedAvailability
    }

    public func draft(from description: String, language: String) async throws -> CVDraft {
        record(description, language)
        switch answer {
        case .draft(let draft): return draft
        case .failure(let error), .snapshotsThenFailure(_, let error): throw error
        case .unrecognisedError: throw CocoaError(.featureUnsupported)
        case .strayCancellation: throw CancellationError()
        case .snapshots(let snapshots): return snapshots.last ?? CVDraft()
        case .waitForCancellation:
            try await Task.sleep(for: Self.patience)
            return CVDraft()
        case .failWhenCancelled(let error):
            try? await Task.sleep(for: Self.patience)
            throw error
        case .draftWhenCancelled(let draft):
            try? await Task.sleep(for: Self.patience)
            return draft
        }
    }

    public nonisolated func stream(from description: String, language: String) -> AsyncThrowingStream<CVDraft, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.record(description, language)
                switch self.answer {
                case .snapshots(let snapshots):
                    for snapshot in snapshots { continuation.yield(snapshot) }
                    continuation.finish()
                case .draft(let draft):
                    continuation.yield(draft)
                    continuation.finish()
                case .failure(let error): continuation.finish(throwing: error)
                case .unrecognisedError: continuation.finish(throwing: CocoaError(.featureUnsupported))
                case .strayCancellation: continuation.finish(throwing: CancellationError())
                case .snapshotsThenFailure(let snapshots, let error):
                    for snapshot in snapshots { continuation.yield(snapshot) }
                    continuation.finish(throwing: error)
                case .waitForCancellation(let snapshots):
                    for snapshot in snapshots { continuation.yield(snapshot) }
                    do { try await Task.sleep(for: Self.patience) } catch { continuation.finish(throwing: error); return }
                    continuation.finish()
                case .failWhenCancelled(let error):
                    try? await Task.sleep(for: Self.patience)
                    continuation.finish(throwing: error)
                case .draftWhenCancelled(let draft):
                    try? await Task.sleep(for: Self.patience)
                    continuation.yield(draft)
                    continuation.finish()
                }
            }
            continuation.onTermination = { termination in
                task.cancel()
                if case .cancelled = termination { Task { await self.signal(.stopped) } }
            }
        }
    }

    private func record(_ description: String, _ language: String) {
        requests.append(Request(description: description, language: language))
        signal(.asked)
    }

    private func signal(_ event: Event) {
        seen.insert(event)
        let ready = waiters.filter { $0.value.event == event }
        for id in ready.keys { waiters[id] = nil }
        for waiter in ready.values { waiter.continuation.resume(returning: true) }
    }

    private func expire(_ id: UUID) {
        waiters.removeValue(forKey: id)?.continuation.resume(returning: false)
    }
}

/// Drafts for tests.
public enum DraftFixtures {
    /// A draft with every field filled, as a model could return it.
    public static let full = CVDraft(
        person: .init(fullName: "Ada Lovelace", professionalTitle: "iOS Engineer", email: "ada@example.com", phone: "+39 06 1234567",
                      location: "Roma", website: "https://ada.example", summary: "Builds careful software."),
        jobs: [.init(role: "Engineer", company: "Analytical", location: "London", description: "Engines",
                     start: .init(year: 2019, month: 3), end: nil, isCurrent: true),
               .init(role: "Clerk", company: "Old Firm", location: nil, description: nil,
                     start: .init(year: 2015, month: nil), end: .init(year: 2018, month: 6), isCurrent: false)],
        education: [.init(degree: "Mathematics", school: "Home", description: "Tutored", start: .init(year: 2010, month: 9),
                          end: .init(year: 2014, month: 7), isCurrent: false)],
        skills: [.init(name: "Swift", proficiency: .expert), .init(name: "Git", proficiency: nil)],
        languages: [.init(name: "Italian", level: .native), .init(name: "English", level: .c1)],
        certifications: [.init(name: "Swift Certified", issuer: "Apple", year: 2021)],
        interests: ["Chess"])
}

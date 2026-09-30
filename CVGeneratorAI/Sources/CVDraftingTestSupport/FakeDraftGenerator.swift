import Foundation
import CVDrafting

/// A scripted `DraftGenerating` for tests: it answers with the draft, the stream of snapshots or the error it was given,
/// and records every request.
public actor FakeDraftGenerator: DraftGenerating {
    public enum Answer: Sendable {
        case draft(CVDraft), failure(DraftingError), otherFailure, snapshots([CVDraft])
        /// Waits until the task is cancelled, then throws `CancellationError`.
        case waitForCancellation
        /// Waits until the task is cancelled, then throws the given error, as a model may on its way out.
        case failWhenCancelled(DraftingError)
    }

    public struct Request: Hashable, Sendable {
        public let description: String, language: String
        public init(description: String, language: String) { self.description = description; self.language = language }
    }

    private let state: DraftAvailability
    private let answer: Answer
    public private(set) var requests: [Request] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(availability: DraftAvailability = .available, answer: Answer) {
        self.state = availability; self.answer = answer
    }

    public func availability() async -> DraftAvailability { state }

    /// Returns once the generator has been asked at least once.
    public func firstRequest() async {
        if !requests.isEmpty { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    public func draft(from description: String, language: String) async throws -> CVDraft {
        record(description, language)
        switch answer {
        case .draft(let draft): return draft
        case .failure(let error): throw error
        case .otherFailure: throw CocoaError(.featureUnsupported)
        case .snapshots(let snapshots):
            guard let last = snapshots.last else { throw DraftingError.emptyDraft }
            return last
        case .waitForCancellation:
            try await Task.sleep(for: .seconds(60))
            return CVDraft()
        case .failWhenCancelled(let error):
            try? await Task.sleep(for: .seconds(60))
            throw error
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
                case .otherFailure: continuation.finish(throwing: CocoaError(.featureUnsupported))
                case .waitForCancellation:
                    do { try await Task.sleep(for: .seconds(60)) } catch { continuation.finish(throwing: error); return }
                    continuation.finish()
                case .failWhenCancelled(let error):
                    try? await Task.sleep(for: .seconds(60))
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func record(_ description: String, _ language: String) {
        requests.append(Request(description: description, language: language))
        let ready = waiters
        waiters = []
        for waiter in ready { waiter.resume() }
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

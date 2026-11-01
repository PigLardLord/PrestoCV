import Testing
@testable import CVGeneratorAI

/// The depth of the draft (`DraftDepth`) a test or a suite reads, whatever the OS that runs it: the Mac of iOS 27's model reads a
/// rich draft, one of iOS 26 a plain one. A test's `arguments:` are read outside it, so they never read the depth.
struct PinnedDepth: TestTrait, SuiteTrait, TestScoping {
    let isRich: Bool

    var isRecursive: Bool { true }

    func provideScope(
        for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void
    ) async throws {
        try await DraftDepth.$pinned.withValue(isRich) { try await function() }
    }
}

extension Trait where Self == PinnedDepth {
    /// The draft of iOS 26's model.
    static var plainDraft: Self { PinnedDepth(isRich: false) }

    /// The draft of iOS 27's model.
    static var richDraft: Self { PinnedDepth(isRich: true) }
}

#if DEBUG
import Foundation
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVDomain
import PrestoCVIntegration
import PrestoCVWorkflowPorts
import Testing
@testable import PrestoCVComposition

/// The editing the UI test of two pending failures lists through: renames fail two at a time, the rest goes through.
@Suite("The renames of the fixture that fails them in pairs")
struct PairedRenameFailuresTests {
    private func editing() -> PairedRenameFailures {
        PairedRenameFailures(inner: EditCVWorkflow(repository: InMemoryCVRepository(), ids: SequentialIDGenerator()))
    }

    @Test("A rename waits for a second one; then both fail with the store unavailable")
    func bothFailTogether() async throws {
        let editing = editing()
        let cv = editing.new()
        let first = Task { () -> EditFailure? in
            do throws(EditFailure) { _ = try await editing.rename(cv, to: "One"); return nil } catch { return error }
        }
        let second = await Task { () -> EditFailure? in
            do throws(EditFailure) { _ = try await editing.rename(cv, to: "Two"); return nil } catch { return error }
        }.value
        let firstFailure = await first.value

        #expect(second == .unavailable, "The second rename fails once it has met the first")
        #expect(firstFailure == .unavailable, "The first rename is let go by the second, and fails")
    }

    @Test("Everything but a rename goes through to the editing it wraps")
    func otherCallsPassThrough() async throws {
        let editing = editing()
        let cv = editing.new()

        var named = cv
        named.rename("Backend")
        named.setPersonalDetails(PersonalDetails(fullName: "Mara Ellison"))
        let saved = try await editing.save(named)
        let loaded = try await editing.load(saved.id)

        #expect(loaded.title == "Backend")
    }
}
#endif

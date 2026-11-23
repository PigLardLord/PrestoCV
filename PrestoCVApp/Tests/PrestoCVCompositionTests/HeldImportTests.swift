#if DEBUG
import Foundation
import PrestoCVWorkflowPorts
import Testing
@testable import PrestoCVComposition

/// The import the UI test of a cancelled read reads through: a read never ends by itself, and ends as cancelled.
@Suite("The import of the fixture that holds its reads")
struct HeldImportTests {
    @Test("A read of a text or a PDF waits until its task is cancelled, then ends as cancelled", arguments: [false, true])
    func readEndsOnlyWhenCancelled(pdf: Bool) async {
        let read = Task { () -> (any Error)? in
            do {
                _ = pdf ? try await HeldImport().importCV(fromPDF: Data()) : try await HeldImport().importCV(fromText: "Ada")
                return nil
            } catch {
                return error
            }
        }

        read.cancel()

        #expect(await read.value is CancellationError)
    }

    @Test("The fixture reads through the held import only when its argument is given")
    func fixtureChoosesTheHeldImport() throws {
        let held = try LaunchFixtures.parse(["PrestoCVNext", LaunchFixtures.holdImportArgument])
        let plain = try LaunchFixtures.parse(["PrestoCVNext"])

        #expect(held.holdsImport)
        #expect(held.storage == .device, "It writes nothing, so it needs no folder")
        #expect(held.unknownArguments.isEmpty)
        #expect(!plain.holdsImport)
        #expect(held.importing(NoImport()) is HeldImport)
        #expect(plain.importing(NoImport()) is NoImport)
    }
}

/// An import that is never asked to read.
private struct NoImport: CVImporting {
    func importCV(fromText text: String) async throws -> ImportOutcome { throw CancellationError() }
    func importCV(fromPDF data: Data) async throws -> ImportOutcome { throw CancellationError() }
}
#endif

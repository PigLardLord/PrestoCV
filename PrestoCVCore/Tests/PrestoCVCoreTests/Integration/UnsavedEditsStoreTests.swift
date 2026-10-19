import Testing
import Foundation
@testable import PrestoCVCore

/// The unsaved edits over the real file storage, as the app wires them: what one run of the app keeps, the next
/// one finds, and within a run each set of edits has one holder at a time.
@Suite("Unsaved Edits Store Tests")
struct UnsavedEditsStoreTests {

    /// The folders of one installation of the app, which outlive its runs.
    private struct Installation {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("test_unsaved_edits_\(UUID().uuidString)")
        var cvs: URL { root.appendingPathComponent("CVs", isDirectory: true) }
        var unsavedEdits: URL { root.appendingPathComponent("UnsavedEdits", isDirectory: true) }

        /// One run of the app: its unsaved edits, and its CVs as the container makes them.
        func launch(clock: ManualClock = ManualClock()) throws -> (edits: UnsavedEditsUseCase, cvs: CVManagementUseCaseProtocol) {
            let cvs = self.cvs
            let edits = UnsavedEditsUseCase(
                repository: UnsavedEditsRepository(storageService: try FileStorageService(baseDirectory: unsavedEdits)),
                now: { clock.now() }
            )
            return (edits, try DependencyContainer(storageDirectory: { cvs }).makeCVManagementUseCase())
        }

        func keptFiles() throws -> [String] {
            try FileManager.default.contentsOfDirectory(atPath: unsavedEdits.path).filter { $0.hasSuffix(".json") }
        }

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }

    /// Keeps `cv` as the edits of a new editing, as an editor does at its first write.
    @discardableResult
    private func keep(_ cv: CVModel, over base: CVModel? = nil, in edits: UnsavedEditsUseCase) async throws -> UnsavedEditsClaim {
        let claim = try #require(await edits.claimEditing(UUID()))
        try await edits.keep(cv, over: base, as: claim)
        return claim
    }

    @Test("Edits kept by one run are offered to the next run, as they were")
    func editsKeptByOneRunAreOfferedToTheNext() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cv = CVTestDataBuilder.minimalCV().withName("Ward nurse").build()

        let claim = try await keep(cv, in: try installation.launch().edits)
        let offered = try #require(try await installation.launch().edits.editsToRestore())

        #expect(offered.id == claim.editing)
        #expect(offered.cv == cv)
        #expect(offered.base == nil)
    }

    @Test("Edits an editor holds are not offered; once it lets go, they are")
    func heldEditsAreNotOffered() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let run = try installation.launch().edits

        let claim = try await keep(CVTestDataBuilder.minimalCV().build(), in: run)
        #expect(try await run.editsToRestore() == nil)

        await run.release(claim)
        #expect(try await run.editsToRestore()?.id == claim.editing)
    }

    @Test("An editing keeps one set of edits, the last one")
    func keepingAgainReplacesTheEdits() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let base = CVTestDataBuilder.minimalCV().withName("Stored").build()
        let run = try installation.launch().edits

        let claim = try await keep(CVTestDataBuilder.minimalCV().withName("First").build(), over: base, in: run)
        try await run.keep(CVTestDataBuilder.minimalCV().withName("Second").build(), over: base, as: claim)

        #expect(try installation.keptFiles().count == 1)
        let offered = try #require(try await installation.launch().edits.editsToRestore())
        #expect(offered.cv.name == "Second")
        #expect(offered.base == base)
    }

    @Test("Discarded edits are gone for the next run, and discarding edits that are not kept is not an error")
    func discardedEditsAreGone() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let run = try installation.launch().edits
        let claim = try await keep(CVTestDataBuilder.minimalCV().build(), in: run)

        try await run.discard(as: claim)
        try await run.discard(as: claim)

        #expect(try installation.keptFiles().isEmpty)
        #expect(try await installation.launch().edits.editsToRestore() == nil)
    }

    @Test("The latest edits left by earlier runs are offered first")
    func theLatestEditsAreOfferedFirst() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let clock = ManualClock()
        try await keep(CVTestDataBuilder.minimalCV().withName("Older").build(), in: try installation.launch(clock: clock).edits)
        clock.advance(by: 60)
        try await keep(CVTestDataBuilder.minimalCV().withName("Newer").build(), in: try installation.launch(clock: clock).edits)

        let offered = try #require(try await installation.launch().edits.editsToRestore())

        #expect(offered.cv.name == "Newer")
    }

    @Test("Edits are dated in whole seconds, as the CVs are")
    func editsAreDatedInWholeSeconds() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let clock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000.75))
        try await keep(CVTestDataBuilder.minimalCV().build(), in: try installation.launch(clock: clock).edits)

        let offered = try #require(try await installation.launch().edits.editsToRestore())

        #expect(offered.keptAt == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("Kept edits are no CV: the list of CVs neither shows them nor sets them aside as unreadable")
    func keptEditsAreNotCVs() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let run = try installation.launch()
        let stored = try await run.cvs.createCV(from: CVTestDataBuilder.minimalCV().withName("Stored").build())
        var edited = stored
        edited.name = "Stored, edited"

        try await keep(edited, over: stored, in: run.edits)
        let listing = try await installation.launch().cvs.getCVListing()

        #expect(listing.cvs == [stored])
        #expect(listing.unreadableCount == 0)
        #expect(try installation.keptFiles().count == 1, "The edits must stay where they were kept")
    }

    // MARK: - One use case for the whole app, one holder for each set of edits

    @Test("The use case of the app keeps the edits in its folder, for the next launch")
    func theAppsUseCaseKeepsTheEditsInItsFolder() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cv = CVTestDataBuilder.minimalCV().build()

        let claim = try await keep(cv, in: try DependencyContainer.makeUnsavedEditsUseCase(in: installation.unsavedEdits))
        let offered = try await DependencyContainer.makeUnsavedEditsUseCase(in: installation.unsavedEdits).editsToRestore()

        #expect(FileManager.default.fileExists(atPath: installation.unsavedEdits.appendingPathComponent("edits_\(claim.editing.uuidString).json").path))
        #expect(offered?.cv == cv)
    }

    @Test("Offered edits are claimed by one window only, however many choose them at once")
    func editsAreClaimedOnce() async throws {
        let installation = Installation()
        defer { installation.remove() }
        try await keep(CVTestDataBuilder.minimalCV().build(), in: try installation.launch().edits)
        let app = try installation.launch().edits
        let offered = try #require(try await app.editsToRestore())

        let claims = try await withThrowingTaskGroup(of: UnsavedEditsClaim?.self) { group in
            for _ in 0..<5 {
                group.addTask { try await app.claim(offered) }
            }
            return try await group.reduce(into: [UnsavedEditsClaim?]()) { $0.append($1) }
        }

        #expect(claims.compactMap { $0 }.count == 1)
        #expect(try await app.editsToRestore() == nil, "Claimed edits are not offered to another window")
    }

    @Test("Only the claim that holds the edits changes them: a released claim does nothing")
    func onlyTheHolderChangesTheEdits() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let run = try installation.launch().edits
        let cv = CVTestDataBuilder.minimalCV().withName("Kept").build()
        let released = try await keep(cv, in: run)
        await run.release(released)
        let offered = try #require(try await run.editsToRestore())
        let holder = try #require(try await run.claim(offered))

        await #expect(throws: UnsavedEditsError.notHeld) { try await run.discard(as: released) }
        await #expect(throws: UnsavedEditsError.notHeld) {
            try await run.keep(CVTestDataBuilder.minimalCV().build(), over: nil, as: released)
        }

        #expect(try installation.keptFiles().count == 1)
        try await run.discard(as: holder)
        #expect(try installation.keptFiles().isEmpty)
    }

    @Test("An offer that is no longer what is kept is refused, and holds nothing")
    func staleOffersAreRefusedAndReleased() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let earlier = try installation.launch().edits
        let earlierClaim = try await keep(CVTestDataBuilder.minimalCV().withName("First").build(), in: earlier)
        let app = try installation.launch().edits
        let offered = try #require(try await app.editsToRestore())

        try await earlier.keep(CVTestDataBuilder.minimalCV().withName("Second").build(), over: nil, as: earlierClaim)

        #expect(try await app.claim(offered) == nil, "Edits that changed cannot be taken as they were offered")
        let current = try #require(try await app.editsToRestore(), "The refused claim must not hide the edits")
        #expect(current.cv.name == "Second")
        #expect(try await app.claim(current) != nil)
    }
}

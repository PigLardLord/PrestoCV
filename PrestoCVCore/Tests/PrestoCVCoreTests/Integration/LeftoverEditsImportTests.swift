import Testing
import Foundation
@testable import PrestoCVCore

/// What earlier versions of the app kept of editor work nobody saved is stored at the next launch, once, without a
/// question, and removed: over the real file storage, as the app wires it.
@Suite("Leftover Edits Import Tests")
struct LeftoverEditsImportTests {

    /// The folders of one installation of the app, which outlive its runs.
    private struct Installation {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("test_leftover_edits_\(UUID().uuidString)")
        var cvs: URL { root.appendingPathComponent("CVs", isDirectory: true) }
        var unsavedEdits: URL { root.appendingPathComponent("UnsavedEdits", isDirectory: true) }

        /// The CVs of one run of the app, as the container makes them.
        func cvManagement() throws -> CVManagementUseCaseProtocol {
            let cvs = self.cvs
            return try DependencyContainer(storageDirectory: { cvs }).makeCVManagementUseCase()
        }

        /// The import of one run, into `cvs` when given.
        func leftoverImport(into cvs: CVManagementUseCaseProtocol? = nil) throws -> LeftoverEditsImport {
            try DependencyContainer.makeLeftoverEditsImport(
                in: unsavedEdits,
                cvs: cvs ?? cvManagement(),
                recoveredName: { "\($0.name) (recovered)" }
            )
        }

        /// Leaves `cv` as an earlier version kept it: the edits of an editing, made on `base`.
        @discardableResult
        func leave(_ cv: CVModel, over base: CVModel? = nil, keptAt seconds: TimeInterval = 1_700_000_000) async throws -> UnsavedEdits {
            let edits = UnsavedEdits(id: UUID(), cv: cv, base: base, keptAt: Date(timeIntervalSince1970: seconds))
            try await FileStorageService(baseDirectory: unsavedEdits).save(edits, to: UnsavedEditsRepository.identifier(for: edits.id))
            return edits
        }

        func leftoverFiles() throws -> [String] {
            guard FileManager.default.fileExists(atPath: unsavedEdits.path) else { return [] }
            return try FileManager.default.contentsOfDirectory(atPath: unsavedEdits.path).filter { $0.hasSuffix(".json") }
        }

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }

    private func edited(_ cv: CVModel, title: String = "Senior nurse") -> CVModel {
        var edited = cv
        edited.personalInfo.title = title
        return edited
    }

    @Test("A new CV an earlier version kept is stored at the next launch, and the leftover goes")
    func newCVIsStored() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cv = CVTestDataBuilder.minimalCV().withName("Ward nurse").build()
        try await installation.leave(cv)

        let report = try await installation.leftoverImport().importLeftovers()

        #expect(report == LeftoverEditsImportReport(imported: 1))
        #expect(try await installation.cvManagement().getAllCVs() == [cv])
        #expect(try installation.leftoverFiles().isEmpty)
    }

    @Test("Edits made on the stored CV as it is replace it")
    func editsOnTheStoredCVUpdateIt() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let stored = try await installation.cvManagement().storeNewCV(CVTestDataBuilder.minimalCV().withName("Ward nurse").build())
        try await installation.leave(edited(stored), over: stored)

        _ = try await installation.leftoverImport().importLeftovers()

        #expect(try await installation.cvManagement().getAllCVs() == [edited(stored)])
    }

    @Test("Edits the stored CV already holds store nothing, so its edit time stays, and the leftover goes")
    func editsAlreadySavedStoreNothing() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let stored = try await installation.cvManagement().storeNewCV(CVTestDataBuilder.minimalCV().withName("Ward nurse").build())
        let before = try await installation.cvManagement().getCVListing()
        try await installation.leave(stored, over: stored)

        let report = try await installation.leftoverImport().importLeftovers()

        #expect(report == LeftoverEditsImportReport(imported: 1))
        #expect(try await installation.cvManagement().getCVListing() == before)
        #expect(try installation.leftoverFiles().isEmpty)
    }

    @Test("Edits made on a version that was saved over since become a recovered copy, so nothing newer is replaced")
    func editsOnAnOlderVersionBecomeACopy() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cvs = try installation.cvManagement()
        let older = try await cvs.storeNewCV(CVTestDataBuilder.minimalCV().withName("Ward nurse").build())
        let leftover = try await installation.leave(edited(older), over: older)
        let newer = try await cvs.updateCV(edited(older, title: "Charge nurse"))

        _ = try await installation.leftoverImport(into: cvs).importLeftovers()

        #expect(try await cvs.getCV(by: older.id) == newer)
        let copy = try #require(try await cvs.getCV(by: leftover.copyID))
        #expect(copy.name == "Ward nurse (recovered)")
        #expect(copy.personalInfo.title == "Senior nurse")
    }

    @Test("Edits whose recovered copy is stored already store nothing, and the copy stays as the person left it")
    func editsWithAStoredCopyStoreNothing() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cvs = try installation.cvManagement()
        let older = try await cvs.storeNewCV(CVTestDataBuilder.minimalCV().withName("Ward nurse").build())
        let leftover = try await installation.leave(edited(older), over: older)
        _ = try await cvs.updateCV(edited(older, title: "Charge nurse"))
        var copy = leftover.cv.copy(newId: leftover.copyID)
        copy.personalInfo.location = "Bristol"
        _ = try await cvs.storeNewCV(copy)

        let report = try await installation.leftoverImport(into: cvs).importLeftovers()

        #expect(report == LeftoverEditsImportReport(imported: 1))
        #expect(try await cvs.getCV(by: leftover.copyID) == copy)
        #expect(try installation.leftoverFiles().isEmpty)
    }

    @Test("Two leftovers of one CV are stored oldest first: the later edits are not replaced by the earlier ones")
    func leftoversAreStoredOldestFirst() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cv = CVTestDataBuilder.minimalCV().withName("Ward nurse").build()
        try await installation.leave(edited(cv, title: "Later"), keptAt: 1_700_000_060)
        try await installation.leave(edited(cv, title: "Earlier"), keptAt: 1_700_000_000)

        let report = try await installation.leftoverImport().importLeftovers()

        #expect(report == LeftoverEditsImportReport(imported: 2))
        let titles = try await installation.cvManagement().getAllCVs().map(\.personalInfo.title)
        #expect(titles.contains("Earlier"), "The earlier edits are stored first")
        #expect(titles.contains("Later"), "The later edits, made on no stored CV, become a copy and replace nothing")
    }

    @Test("A leftover that cannot be stored stays for the next launch, and the next launch stores it")
    func leftoverThatCannotBeStoredStays() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cv = CVTestDataBuilder.minimalCV().withName("Ward nurse").build()
        try await installation.leave(cv)

        let failed = try await installation.leftoverImport(into: RefusingCVs(cvs: try installation.cvManagement())).importLeftovers()
        #expect(failed == LeftoverEditsImportReport(kept: 1))
        #expect(try installation.leftoverFiles().count == 1)

        let next = try await installation.leftoverImport().importLeftovers()
        #expect(next == LeftoverEditsImportReport(imported: 1))
        #expect(try await installation.cvManagement().getAllCVs() == [cv])
    }

    @Test("With nothing left, the import stores nothing and finds nothing wrong")
    func nothingLeftStoresNothing() async throws {
        let installation = Installation()
        defer { installation.remove() }

        let report = try await installation.leftoverImport().importLeftovers()

        #expect(report == LeftoverEditsImportReport())
        #expect(try await installation.cvManagement().getAllCVs().isEmpty)
    }

    @Test("Leftovers are no CV: the list of CVs neither shows them nor sets them aside as unreadable")
    func leftoversAreNotCVs() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let stored = try await installation.cvManagement().storeNewCV(CVTestDataBuilder.minimalCV().withName("Stored").build())
        try await installation.leave(edited(stored), over: stored)

        let listing = try await installation.cvManagement().getCVListing()

        #expect(listing.cvs == [stored])
        #expect(listing.unreadableCount == 0)
        #expect(try installation.leftoverFiles().count == 1, "The leftover stays where it was kept until the import")
    }
}

/// The CVs of the app, with a store that refuses every write.
private struct RefusingCVs: CVManagementUseCaseProtocol {
    struct Refused: Error {}
    let cvs: CVManagementUseCaseProtocol

    func getAllCVs() async throws -> [CVModel] { try await cvs.getAllCVs() }
    func getCVListing() async throws -> CVListing { try await cvs.getCVListing() }
    func acknowledgeUnreadableCVs() async throws { try await cvs.acknowledgeUnreadableCVs() }
    func createCV(from template: CVModel) async throws -> CVModel { throw Refused() }
    func storeNewCV(_ cv: CVModel) async throws -> CVModel { throw Refused() }
    func updateCV(_ cv: CVModel) async throws -> CVModel { throw Refused() }
    func deleteCV(id: UUID) async throws { throw Refused() }
    func duplicateCV(id: UUID, named name: String) async throws -> CVModel { throw Refused() }
    func getCV(by id: UUID) async throws -> CVModel? { try await cvs.getCV(by: id) }
}

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

        /// The leftovers of one run, as the container makes them.
        func leftoverRepository() throws -> UnsavedEditsRepository {
            try DependencyContainer.makeUnsavedEditsRepository(in: unsavedEdits)
        }

        /// Leaves `cv` as an earlier version kept it: the edits of an editing, made on `base`.
        @discardableResult
        func leave(_ cv: CVModel, over base: CVModel? = nil, keptAt seconds: TimeInterval = 1_700_000_000) async throws -> UnsavedEdits {
            let edits = UnsavedEdits(id: UUID(), cv: cv, base: base, keptAt: Date(timeIntervalSince1970: seconds))
            try await FileStorageService(baseDirectory: unsavedEdits).save(edits, to: UnsavedEditsRepository.identifier(for: edits.id))
            return edits
        }

        /// Puts a file in the folder of the leftovers as a failing disk or an interrupted write could leave it.
        func plant(_ data: Data, named name: String) throws {
            try FileManager.default.createDirectory(at: unsavedEdits, withIntermediateDirectories: true)
            try data.write(to: unsavedEdits.appendingPathComponent(name))
        }

        /// The contents of every file the folder set aside, whether or not the person was told.
        func setAsideContents() throws -> [Data] {
            let quarantine = unsavedEdits.appendingPathComponent("Quarantine", isDirectory: true)
            guard let files = FileManager.default.enumerator(at: quarantine, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
            return try files.compactMap { $0 as? URL }.filter { try $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true }
                .map { try Data(contentsOf: $0) }
        }

        func leftoverFiles() throws -> [String] {
            guard FileManager.default.fileExists(atPath: unsavedEdits.path) else { return [] }
            return try FileManager.default.contentsOfDirectory(atPath: unsavedEdits.path).filter { $0.hasSuffix(".json") }
        }

        /// Makes the folder of the leftovers one whose files cannot be removed, as a locked folder is, until `unlock()`.
        func lock() throws {
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: unsavedEdits.path)
        }

        func unlock() throws {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: unsavedEdits.path)
        }

        func remove() {
            try? unlock()
            try? FileManager.default.removeItem(at: root)
        }
    }

    /// The ways a leftover goes into the CVs, by its restore plan.
    enum Plan: CaseIterable, Sendable {
        case create
        case update
        case copy
        case alreadySaved
        case restoredAsCopy
    }

    /// Leaves edits that the import stores by `plan`, over the CVs it makes in `cvs`.
    private func leaveEdits(storedBy plan: Plan, in installation: Installation, cvs: CVManagementUseCaseProtocol) async throws {
        let cv = CVTestDataBuilder.minimalCV().withName("Ward nurse").build()
        switch plan {
        case .create:
            try await installation.leave(cv)
        case .update:
            let stored = try await cvs.storeNewCV(cv)
            try await installation.leave(edited(stored), over: stored)
        case .copy:
            let older = try await cvs.storeNewCV(cv)
            try await installation.leave(edited(older), over: older)
            _ = try await cvs.updateCV(edited(older, title: "Charge nurse"))
        case .alreadySaved:
            let stored = try await cvs.storeNewCV(cv)
            try await installation.leave(stored, over: stored)
        case .restoredAsCopy:
            let older = try await cvs.storeNewCV(cv)
            let leftover = try await installation.leave(edited(older), over: older)
            _ = try await cvs.updateCV(edited(older, title: "Charge nurse"))
            _ = try await cvs.storeNewCV(leftover.cv.copy(newId: leftover.copyID))
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
        #expect(failed.imported == 0)
        #expect(failed.failures.map(\.step) == [.storing])
        #expect(try installation.leftoverFiles().count == 1)

        let next = try await installation.leftoverImport().importLeftovers()
        #expect(next == LeftoverEditsImportReport(imported: 1))
        #expect(try await installation.cvManagement().getAllCVs() == [cv])
    }

    // MARK: - What went wrong, and what was not looked at

    @Test("A leftover that cannot be stored is reported with the step that failed and its cause")
    func failureNamesTheStepAndTheCause() async throws {
        let installation = Installation()
        defer { installation.remove() }
        try await installation.leave(CVTestDataBuilder.minimalCV().withName("Ward nurse").build())
        let refusing = RefusingCVs(cvs: try installation.cvManagement(), refusal: AppError.fileSystemError("disk full"))

        let report = try await installation.leftoverImport(into: refusing).importLeftovers()

        #expect(report.failures == [.init(step: .storing, cause: .fileSystemError("disk full"))])
        #expect(report.imported == 0)
        #expect(report.keptCount == 1)
    }

    @Test("A leftover that is stored but cannot be removed is reported as a removal, and the next launch stores nothing twice")
    func removalFailureIsNamedAndNothingIsStoredTwice() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cv = CVTestDataBuilder.minimalCV().withName("Ward nurse").build()
        try await installation.leave(cv)
        let cvs = try installation.cvManagement()
        let locked = LeftoverEditsImport(
            leftovers: LockedLeftovers(leftovers: try installation.leftoverRepository()),
            cvs: cvs,
            recoveredName: { "\($0.name) (recovered)" }
        )

        let first = try await locked.importLeftovers()

        #expect(first.failures == [.init(step: .removing, cause: .fileSystemError("locked"))])
        #expect(try await cvs.getAllCVs() == [cv], "The edits are stored; only their removal failed")
        let second = try await installation.leftoverImport(into: cvs).importLeftovers()
        #expect(second == LeftoverEditsImportReport(imported: 1))
        #expect(try await cvs.getAllCVs() == [cv], "The leftover that stayed is not stored a second time")
        #expect(try installation.leftoverFiles().isEmpty)
    }

    // MARK: - Edits stored once, whatever the person does next

    @Test("Edits stored and not removed are not stored again after the person edited the CVs, at any launch", arguments: Plan.allCases)
    func storedLeftoverIsNotStoredAgainAfterAnEdit(_ plan: Plan) async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cvs = try installation.cvManagement()
        try await leaveEdits(storedBy: plan, in: installation, cvs: cvs)
        let firstLaunch = try installation.leftoverImport(into: cvs)
        try installation.lock()

        let first = try await firstLaunch.importLeftovers()
        #expect(first.failures.map(\.step) == [.removing], "The edits are stored, and the locked folder keeps them")
        for cv in try await cvs.getAllCVs() {
            _ = try await cvs.updateCV(edited(cv, title: "Head nurse"))
        }
        let asLeft = try await cvs.getAllCVs()

        let second = try await installation.leftoverImport(into: cvs).importLeftovers()
        #expect(second.failures.map(\.step) == [.removing])
        #expect(try await cvs.getAllCVs() == asLeft, "The CVs are as the person left them: no copy, nothing replaced")

        try installation.unlock()
        let third = try await installation.leftoverImport(into: cvs).importLeftovers()
        #expect(third == LeftoverEditsImportReport(imported: 1))
        #expect(try await cvs.getAllCVs() == asLeft)
        #expect(try installation.leftoverFiles().isEmpty)
    }

    @Test("Edits stored and not removed do not bring back the CVs the person deleted, at any launch", arguments: Plan.allCases)
    func storedLeftoverDoesNotBringBackADeletedCV(_ plan: Plan) async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cvs = try installation.cvManagement()
        try await leaveEdits(storedBy: plan, in: installation, cvs: cvs)
        let firstLaunch = try installation.leftoverImport(into: cvs)
        try installation.lock()

        let first = try await firstLaunch.importLeftovers()
        #expect(first.failures.map(\.step) == [.removing])
        for cv in try await cvs.getAllCVs() {
            try await cvs.deleteCV(id: cv.id)
        }

        let second = try await installation.leftoverImport(into: cvs).importLeftovers()
        #expect(second.failures.map(\.step) == [.removing])
        #expect(try await cvs.getAllCVs().isEmpty, "Nothing the person deleted comes back")

        try installation.unlock()
        let third = try await installation.leftoverImport(into: cvs).importLeftovers()
        #expect(third == LeftoverEditsImportReport(imported: 1))
        #expect(try await cvs.getAllCVs().isEmpty)
        #expect(try installation.leftoverFiles().isEmpty)
    }

    @Test("The edits are marked as stored before they are removed, so a launch that ends between the two stores nothing again")
    func markComesBeforeTheRemoval() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cv = CVTestDataBuilder.minimalCV().withName("Ward nurse").build()
        let leftover = try await installation.leave(cv)
        let steps = RecordedLeftovers(leftovers: try installation.leftoverRepository())

        let report = try await LeftoverEditsImport(leftovers: steps, cvs: try installation.cvManagement(), recoveredName: { $0.name })
            .importLeftovers()

        #expect(report == LeftoverEditsImportReport(imported: 1))
        #expect(await steps.changes == [.markStored(leftover.id), .discard(leftover.id)])
    }

    @Test("A mark that cannot be written is reported with its cause, and the edits are still removed")
    func markFailureIsReportedAndTheRemovalGoesOn() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cv = CVTestDataBuilder.minimalCV().withName("Ward nurse").build()
        try await installation.leave(cv)
        let steps = RecordedLeftovers(leftovers: try installation.leftoverRepository(), markError: AppError.fileSystemError("disk full"))

        let report = try await LeftoverEditsImport(leftovers: steps, cvs: try installation.cvManagement(), recoveredName: { $0.name })
            .importLeftovers()

        #expect(report == LeftoverEditsImportReport(imported: 1, failures: [.init(step: .marking, cause: .fileSystemError("disk full"))]))
        #expect(report.keptCount == 0, "The edits are stored and removed: nothing stays")
        #expect(try installation.leftoverFiles().isEmpty)
    }

    @Test("A folder of leftovers that cannot be listed is reported with its cause, and nothing is stored")
    func listingFailureIsReported() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cvs = try installation.cvManagement()
        let unlistable = LeftoverEditsImport(
            leftovers: LockedLeftovers(leftovers: nil, listingError: AppError.fileSystemError("denied")),
            cvs: cvs,
            recoveredName: { $0.name }
        )

        let report = try await unlistable.importLeftovers()

        #expect(report.failures == [.init(step: .listing, cause: .fileSystemError("denied"))])
        #expect(try await cvs.getAllCVs().isEmpty)
    }

    @Test("A cancellation ends the import and is passed on unchanged: it is no failure, and the leftover stays")
    func cancellationIsPassedOn() async throws {
        let installation = Installation()
        defer { installation.remove() }
        try await installation.leave(CVTestDataBuilder.minimalCV().withName("Ward nurse").build())
        let cancelling = RefusingCVs(cvs: try installation.cvManagement(), refusal: CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await installation.leftoverImport(into: cancelling).importLeftovers()
        }

        #expect(try installation.leftoverFiles().count == 1)
        let next = try await installation.leftoverImport().importLeftovers()
        #expect(next == LeftoverEditsImportReport(imported: 1), "The next launch stores it")
    }

    @Test("A leftover file that cannot be read is set aside, reported once, and its bytes are kept")
    func unreadableLeftoverIsReportedOnceAndKept() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let cv = CVTestDataBuilder.minimalCV().withName("Ward nurse").build()
        try await installation.leave(cv)
        let corrupt = Data("{ \"cv\": not a recovery copy".utf8)
        try installation.plant(corrupt, named: "edits_\(UUID().uuidString).json")

        let first = try await installation.leftoverImport().importLeftovers()

        #expect(first.imported == 1, "The readable leftover is stored")
        #expect(first.unreadableFiles == 1, "The one that cannot be read is not lost without a trace")
        #expect(try installation.setAsideContents() == [corrupt], "Its bytes are kept")
        let second = try await installation.leftoverImport().importLeftovers()
        #expect(second.unreadableFiles == 0, "It is reported once, not at every launch")
        #expect(try installation.setAsideContents() == [corrupt], "and kept")
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
    var refusal: any Error = Refused()

    func getAllCVs() async throws -> [CVModel] { try await cvs.getAllCVs() }
    func getCVListing() async throws -> CVListing { try await cvs.getCVListing() }
    func acknowledgeUnreadableCVs() async throws { try await cvs.acknowledgeUnreadableCVs() }
    func createCV(from template: CVModel) async throws -> CVModel { throw refusal }
    func storeNewCV(_ cv: CVModel) async throws -> CVModel { throw refusal }
    func updateCV(_ cv: CVModel) async throws -> CVModel { throw refusal }
    func deleteCV(id: UUID) async throws { throw refusal }
    func duplicateCV(id: UUID, named name: String) async throws -> CVModel { throw refusal }
    func getCV(by id: UUID) async throws -> CVModel? { try await cvs.getCV(by: id) }
}

/// The leftovers, whose removal fails as when the file is locked, or which cannot be listed at all.
private struct LockedLeftovers: UnsavedEditsRepositoryProtocol {
    let leftovers: UnsavedEditsRepositoryProtocol?
    var listingError: AppError?

    func allKept() async throws -> StorageLoadReport<UnsavedEdits> {
        if let listingError { throw listingError }
        return try await leftovers?.allKept() ?? StorageLoadReport(items: [], unreadableCount: 0)
    }

    func acknowledgeUnreadable() async throws { try await leftovers?.acknowledgeUnreadable() }
    func discard(editing id: UUID) async throws { throw AppError.fileSystemError("locked") }
    func markStored(editing id: UUID) async throws { try await leftovers?.markStored(editing: id) }
    func isMarkedStored(editing id: UUID) async -> Bool { await leftovers?.isMarkedStored(editing: id) ?? false }
}

/// The leftovers, recording each change the import makes to them, in order. A mark can be made to fail.
private actor RecordedLeftovers: UnsavedEditsRepositoryProtocol {
    enum Change: Equatable {
        case markStored(UUID)
        case discard(UUID)
    }

    private let leftovers: UnsavedEditsRepositoryProtocol
    private let markError: AppError?
    private(set) var changes: [Change] = []

    init(leftovers: UnsavedEditsRepositoryProtocol, markError: AppError? = nil) {
        self.leftovers = leftovers
        self.markError = markError
    }

    func allKept() async throws -> StorageLoadReport<UnsavedEdits> { try await leftovers.allKept() }
    func acknowledgeUnreadable() async throws { try await leftovers.acknowledgeUnreadable() }
    func isMarkedStored(editing id: UUID) async -> Bool { await leftovers.isMarkedStored(editing: id) }

    func markStored(editing id: UUID) async throws {
        changes.append(.markStored(id))
        if let markError { throw markError }
        try await leftovers.markStored(editing: id)
    }

    func discard(editing id: UUID) async throws {
        changes.append(.discard(id))
        try await leftovers.discard(editing: id)
    }
}

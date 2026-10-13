import Testing
import Foundation
@testable import PrestoCVCore

/// The CV repository over the real file storage, as the app wires them
@Suite("CV Store Tests")
struct CVStoreTests {
    
    private func makeStore(clock: ManualClock = ManualClock()) throws -> (repository: CVRepository, directory: URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("test_cv_store_\(UUID().uuidString)")
        let storage = try FileStorageService(baseDirectory: directory)
        return (CVRepository(storageService: storage, now: { clock.now() }), directory)
    }
    
    private func fileURL(of cv: CVModel, in directory: URL) -> URL {
        directory.appendingPathComponent("cv_\(cv.id.uuidString).json")
    }
    
    private func storedTimes(of cv: CVModel, in directory: URL) throws -> (createdAt: Date?, updatedAt: Date?) {
        let data = try Data(contentsOf: fileURL(of: cv, in: directory))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let formatter = ISO8601DateFormatter()
        return (
            (object["createdAt"] as? String).flatMap(formatter.date(from:)),
            (object["updatedAt"] as? String).flatMap(formatter.date(from:))
        )
    }
    
    @Test("A saved CV is stored in its own file and read back")
    func savedCVIsReadBack() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cv = CVTestDataBuilder.completeCV().build()
        
        _ = try await repository.saveCV(cv)
        
        #expect(FileManager.default.fileExists(atPath: fileURL(of: cv, in: directory).path))
        #expect(try await repository.getCV(by: cv.id) == cv)
        #expect(try await repository.getAllCVs() == [cv])
    }
    
    @Test("Files without an id are quarantined and the other CVs are listed")
    func filesWithoutIdAreQuarantined() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cv = CVTestDataBuilder.minimalCV().withName("Healthy").build()
        _ = try await repository.saveCV(cv)
        try Data("{}".utf8).write(to: directory.appendingPathComponent("cv_\(UUID().uuidString).json"))
        try Data(#"{"name": "Ghost"}"#.utf8).write(to: directory.appendingPathComponent("cv_\(UUID().uuidString).json"))
        
        let listed = try await repository.getAllCVs()
        
        #expect(listed.map(\.name) == ["Healthy"])
        let quarantined = try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("Quarantine").path)
        #expect(quarantined.count == 2)
        #expect(try await repository.getCVsCount() == 1)
    }
    
    // MARK: - Startup Tests
    
    /// The sequence the app runs at launch: the onboarding check first, then the list
    private func launch(_ repository: CVRepository) async throws -> (state: OnboardingState, listing: CVListing) {
        let state = await OnboardingRepository(cvRepository: repository).getOnboardingState()
        let listing = try await repository.getCVListing()
        return (state, listing)
    }
    
    @Test("At launch the list reports the corrupt file that the onboarding check set aside")
    func launchReportsCorruptFileInMixedStore() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let healthy = CVTestDataBuilder.minimalCV().withName("Healthy").build()
        _ = try await repository.saveCV(healthy)
        try Data("{}".utf8).write(to: directory.appendingPathComponent("cv_\(UUID().uuidString).json"))
        
        let launched = try await launch(repository)
        
        #expect(launched.state == .returning)
        #expect(launched.listing.cvs == [healthy])
        #expect(launched.listing.unreadableCount == 1)
    }
    
    @Test("At launch a store with only unusable files is not a first run and the list reports them")
    func launchOfAnEntirelyBadStoreIsNotAFirstRun() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("{}".utf8).write(to: directory.appendingPathComponent("cv_\(UUID().uuidString).json"))
        try Data("not json".utf8).write(to: directory.appendingPathComponent("cv_\(UUID().uuidString).json"))
        
        let launched = try await launch(repository)
        
        #expect(launched.state == .returning)
        #expect(launched.listing.cvs.isEmpty)
        #expect(launched.listing.unreadableCount == 2)
    }
    
    @Test("The unreadable files are reported until they are acknowledged, and kept afterwards")
    func unreadableFilesAreReportedUntilAcknowledged() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let corruptName = "cv_\(UUID().uuidString).json"
        try Data("{}".utf8).write(to: directory.appendingPathComponent(corruptName))
        
        _ = try await launch(repository)
        #expect(try await repository.getCVListing().unreadableCount == 1)
        #expect(try await repository.getCVListing().unreadableCount == 1)
        
        try await repository.acknowledgeUnreadableCVs()
        
        let afterwards = try await launch(repository)
        #expect(afterwards.listing.unreadableCount == 0)
        #expect(afterwards.state == .firstTime)
        let kept = directory.appendingPathComponent("Quarantine/acknowledged/\(corruptName)")
        #expect(try String(contentsOf: kept, encoding: .utf8) == "{}")
    }
    
    @Test("A file set aside after an acknowledgement is reported again")
    func fileSetAsideAfterAcknowledgementIsReported() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("{}".utf8).write(to: directory.appendingPathComponent("cv_\(UUID().uuidString).json"))
        _ = try await repository.getCVListing()
        try await repository.acknowledgeUnreadableCVs()
        
        try Data("{}".utf8).write(to: directory.appendingPathComponent("cv_\(UUID().uuidString).json"))
        
        #expect(try await repository.getCVListing().unreadableCount == 1)
    }
    
    @Test("Every listed CV can be deleted")
    func everyListedCVIsDeletable() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["One", "Two", "Three"] {
            _ = try await repository.saveCV(CVTestDataBuilder.minimalCV().withName(name).build())
        }
        try Data("{}".utf8).write(to: directory.appendingPathComponent("cv_\(UUID().uuidString).json"))
        
        for listed in try await repository.getAllCVs() {
            try await repository.deleteCV(id: listed.id)
        }
        
        #expect(try await repository.getAllCVs().isEmpty)
        // The file that was set aside still counts as stored until the user has been told about it
        #expect(try await repository.cvExists() == true)
        try await repository.acknowledgeUnreadableCVs()
        #expect(try await repository.cvExists() == false)
    }
    
    @Test("A save replaces a stored file that cannot be decoded")
    func saveReplacesCorruptFile() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cv = CVTestDataBuilder.minimalCV().withName("Recovered").build()
        try Data("not json".utf8).write(to: fileURL(of: cv, in: directory))
        
        _ = try await repository.saveCV(cv)
        
        #expect(try await repository.getCV(by: cv.id)?.name == "Recovered")
    }
    
    @Test("The list is ordered by last change, whatever order the files are in")
    func listIsOrderedByLastChange() async throws {
        let clock = ManualClock()
        let (repository, directory) = try makeStore(clock: clock)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["C", "A", "B"] {
            _ = try await repository.saveCV(CVTestDataBuilder.minimalCV().withName(name).build())
            clock.advance(by: 5)
        }
        
        let listed = try await repository.getAllCVs()
        
        #expect(listed.map(\.name) == ["B", "A", "C"])
        #expect(try await repository.getAllCVs().map(\.id) == listed.map(\.id))
    }
    
    @Test("A CV keeps its creation time across saves and repository instances")
    func creationTimeSurvivesNewRepositoryInstance() async throws {
        let clock = ManualClock()
        let (repository, directory) = try makeStore(clock: clock)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cv = CVTestDataBuilder.minimalCV().build()
        let created = clock.now()
        _ = try await repository.saveCV(cv)
        
        clock.advance(by: 3600)
        let reopened = CVRepository(storageService: try FileStorageService(baseDirectory: directory), now: { clock.now() })
        _ = try await reopened.saveCV(cv)
        
        let times = try storedTimes(of: cv, in: directory)
        #expect(times.createdAt == created)
        #expect(times.updatedAt == created.addingTimeInterval(3600))
    }
    
    @Test("Overlapping saves of one CV keep the first creation time and never date an update before it")
    func overlappingSavesKeepTheFirstCreationTime() async throws {
        let clock = TickingClock()
        let start = clock.now()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("test_cv_store_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CVRepository(storageService: try FileStorageService(baseDirectory: directory), now: { clock.now() })
        let cv = CVTestDataBuilder.minimalCV().build()
        let saves = 20
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<saves {
                group.addTask { _ = try await repository.saveCV(cv) }
            }
            try await group.waitForAll()
        }
        
        // The clock is read inside the storage's critical section: the first save read `start + 1`, the last read `start + saves`
        let times = try storedTimes(of: cv, in: directory)
        #expect(times.createdAt == start.addingTimeInterval(1))
        #expect(times.updatedAt == start.addingTimeInterval(TimeInterval(saves)))
    }
    
    @Test("An update is never dated before the creation when the clock moves backwards")
    func updateIsNeverDatedBeforeCreation() async throws {
        let clock = ManualClock()
        let (repository, directory) = try makeStore(clock: clock)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cv = CVTestDataBuilder.minimalCV().build()
        let created = clock.now()
        _ = try await repository.saveCV(cv)
        
        clock.advance(by: -3600)
        _ = try await repository.saveCV(cv)
        
        let times = try storedTimes(of: cv, in: directory)
        #expect(times.createdAt == created)
        #expect(times.updatedAt == created)
    }
    
    // MARK: - Identity Tests
    
    private static let low = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private static let middle = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
    private static let high = UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!
    
    private func cv(_ id: UUID, _ name: String) -> CVModel {
        CVTestDataBuilder.minimalCV().withName(name).build(id: id)
    }
    
    /// Writes the CV as a file named for another CV, or for itself
    private func writeCVFile(_ cv: CVModel, named id: UUID, in directory: URL) throws {
        try JSONEncoder().encode(cv).write(to: directory.appendingPathComponent("\(StoredCV.identifier(for: id)).json"))
    }
    
    private func writeRaw(_ text: String, named id: UUID, in directory: URL) throws {
        try Data(text.utf8).write(to: directory.appendingPathComponent("\(StoredCV.identifier(for: id)).json"))
    }
    
    private func fileExists(named id: UUID, in directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent("\(StoredCV.identifier(for: id)).json").path)
    }
    
    /// The name and the content of every file in the store, to tell that nothing was touched
    private func snapshot(of directory: URL) throws -> [String: Data] {
        var files: [String: Data] = [:]
        for name in try FileManager.default.contentsOfDirectory(atPath: directory.path) {
            var isDirectory: ObjCBool = false
            let path = directory.appendingPathComponent(name).path
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue {
                files[name] = try Data(contentsOf: URL(fileURLWithPath: path))
            }
        }
        return files
    }
    
    private func quarantined(in directory: URL) throws -> [String] {
        let url = directory.appendingPathComponent("Quarantine")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
    }
    
    @Test("A listed CV stored under another CV's file name is renamed to its own name")
    func listingRenamesAMisnamedFileWhenItsNameIsFree() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let misnamed = cv(Self.middle, "Misnamed")
        try writeCVFile(misnamed, named: Self.low, in: directory)
        
        let listing = try await repository.getCVListing()
        
        #expect(listing.cvs == [misnamed])
        #expect(listing.unreadableCount == 0)
        #expect(fileExists(named: Self.middle, in: directory))
        #expect(!fileExists(named: Self.low, in: directory))
        #expect(try await repository.getCV(by: Self.middle) == misnamed)
        try await repository.deleteCV(id: Self.middle)
        #expect(try await repository.getAllCVs().isEmpty)
    }
    
    @Test("An interrupted rename that left only the old name is finished by the next listing")
    func interruptedRenameWithOnlyTheOldNameIsFinished() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let misnamed = cv(Self.high, "Interrupted")
        try writeCVFile(misnamed, named: Self.low, in: directory)
        
        let first = try await repository.getCVListing()
        let second = try await repository.getCVListing()
        
        #expect(first.cvs == [misnamed])
        #expect(second == first)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["\(StoredCV.identifier(for: Self.high)).json"])
    }
    
    @Test("An interrupted rename that left only the new name needs nothing from the next listing")
    func interruptedRenameWithOnlyTheNewNameNeedsNothing() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let renamed = cv(Self.high, "Renamed")
        try writeCVFile(renamed, named: Self.high, in: directory)
        let before = try snapshot(of: directory)
        
        let listing = try await repository.getCVListing()
        
        #expect(listing == CVListing(cvs: [renamed], unreadableCount: 0))
        #expect(try snapshot(of: directory) == before)
    }
    
    @Test("A misnamed file whose name is taken stays untouched and is counted, whatever the order of the names",
          arguments: [true, false])
    func occupiedNameLeavesEveryFileIntact(strayNamedFirst: Bool) async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (strayName, ownerId) = strayNamedFirst ? (Self.low, Self.high) : (Self.high, Self.low)
        let owner = cv(ownerId, "Owner")
        var stray = owner
        stray.name = "Stray copy"
        try writeCVFile(stray, named: strayName, in: directory)
        try writeCVFile(owner, named: ownerId, in: directory)
        let before = try snapshot(of: directory)
        
        let listing = try await repository.getCVListing()
        
        #expect(listing == CVListing(cvs: [owner], unreadableCount: 1))
        #expect(try snapshot(of: directory) == before)
        #expect(try quarantined(in: directory).isEmpty)
        #expect(try await repository.getCV(by: ownerId) == owner)
        #expect(try await repository.getCV(by: strayName) == nil)
        #expect(try snapshot(of: directory) == before)
    }
    
    @Test("Looking up a file that holds another CV renames it when that name is free")
    func lookupRenamesAMisnamedFileWhenItsNameIsFree() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let held = cv(Self.high, "Held")
        try writeCVFile(held, named: Self.low, in: directory)
        
        #expect(try await repository.getCV(by: Self.low) == nil)
        
        #expect(!fileExists(named: Self.low, in: directory))
        #expect(try await repository.getCV(by: Self.high) == held)
    }
    
    @Test("Looking up a file that holds another CV leaves it untouched when that name is taken")
    func lookupLeavesAMisnamedFileWhenItsNameIsTaken() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let owner = cv(Self.high, "Owner")
        try writeCVFile(owner, named: Self.high, in: directory)
        try writeCVFile(owner, named: Self.low, in: directory)
        let before = try snapshot(of: directory)
        
        #expect(try await repository.getCV(by: Self.low) == nil)
        
        #expect(try snapshot(of: directory) == before)
        #expect(try quarantined(in: directory).isEmpty)
    }
    
    @Test("Two files that hold each other's CV stay as they are and are both counted")
    func filesThatHoldEachOthersCVsStayIntact() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeCVFile(cv(Self.high, "Second"), named: Self.low, in: directory)
        try writeCVFile(cv(Self.low, "First"), named: Self.high, in: directory)
        let before = try snapshot(of: directory)
        
        let listing = try await repository.getCVListing()
        
        #expect(listing == CVListing(cvs: [], unreadableCount: 2))
        #expect(try snapshot(of: directory) == before)
        #expect(try await repository.cvExists() == true)
    }
    
    @Test("A chain of misnamed files is renamed one file per listing, from the free end")
    func chainOfMisnamedFilesConvergesOverListings() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let second = cv(Self.middle, "Second")
        let third = cv(Self.high, "Third")
        try writeCVFile(second, named: Self.low, in: directory)
        try writeCVFile(third, named: Self.middle, in: directory)
        
        let first = try await repository.getCVListing()
        
        #expect(first == CVListing(cvs: [third], unreadableCount: 1))
        
        let next = try await repository.getCVListing()
        
        #expect(Set(next.cvs.map(\.id)) == [Self.middle, Self.high])
        #expect(next.unreadableCount == 0)
        #expect(try await repository.getCV(by: Self.middle) == second)
        #expect(try await repository.getCV(by: Self.high) == third)
    }
    
    @Test("A misnamed file takes the name of a corrupt file that is set aside, whatever the order of the names",
          arguments: [true, false])
    func corruptFileAtTheTargetFreesItsName(strayNamedFirst: Bool) async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (strayName, ownerId) = strayNamedFirst ? (Self.low, Self.high) : (Self.high, Self.low)
        let valid = cv(ownerId, "Valid")
        try writeCVFile(valid, named: strayName, in: directory)
        try writeRaw("not json", named: ownerId, in: directory)
        
        let listing = try await repository.getCVListing()
        
        #expect(listing == CVListing(cvs: [valid], unreadableCount: 1))
        #expect(!fileExists(named: strayName, in: directory))
        #expect(try await repository.getCV(by: ownerId) == valid)
        #expect(try quarantined(in: directory) == ["\(StoredCV.identifier(for: ownerId)).json"])
        let setAside = directory.appendingPathComponent("Quarantine/\(StoredCV.identifier(for: ownerId)).json")
        #expect(try String(contentsOf: setAside, encoding: .utf8) == "not json")
    }
    
    @Test("A misnamed file stays when the file at its name cannot be read, and is counted",
          .enabled(if: geteuid() != 0))
    func lockedTargetLeavesBothFilesIntact() async throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let valid = cv(Self.high, "Valid")
        try writeCVFile(valid, named: Self.low, in: directory)
        try writeCVFile(valid, named: Self.high, in: directory)
        let locked = directory.appendingPathComponent("\(StoredCV.identifier(for: Self.high)).json")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path) }
        
        let whileLocked = try await repository.getCVListing()
        
        #expect(whileLocked == CVListing(cvs: [], unreadableCount: 2))
        #expect(fileExists(named: Self.low, in: directory))
        #expect(try quarantined(in: directory).isEmpty)
        
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path)
        let afterwards = try await repository.getCVListing()
        
        #expect(afterwards == CVListing(cvs: [valid], unreadableCount: 1))
        #expect(fileExists(named: Self.low, in: directory))
    }
    
    @Test("Listing fails when the storage directory is gone")
    func listingFailsWhenDirectoryIsGone() async throws {
        let (repository, directory) = try makeStore()
        try FileManager.default.removeItem(at: directory)
        
        await #expect {
            _ = try await repository.getAllCVs()
        } throws: { error in
            guard case AppError.fileSystemError = error else { return false }
            return true
        }
        await #expect {
            _ = try await repository.cvExists()
        } throws: { error in
            guard case AppError.fileSystemError = error else { return false }
            return true
        }
    }
}

import Foundation
@testable import PrestoCVCore

/// A CV repository that keeps its CVs in memory, listed by name and then id.
///
/// A test can make an operation fail, and can hold listings until it releases them one by one, in the order they
/// were started. A held listing sees the store as it was when it started, whatever happens before it is released,
/// and the test chooses at its release whether it returns that or fails. A held save, like a slow write, stores its
/// CV only when it is released.
actor InMemoryCVRepository: CVRepositoryProtocol {
    enum Operation: Hashable {
        case listing
        case get
        case save
        case delete
    }
    
    private(set) var saveCount = 0
    /// How many times the listing, the CVs with their times, was asked for.
    private(set) var listingCount = 0
    
    private var storedCVs: [UUID: CVModel] = [:]
    private var lastSavedAt: [UUID: Date] = [:]
    private var failures: [Operation: Error] = [:]
    private var unreadableCount = 0
    private var listingsToHold = 0
    private var heldListings: [CheckedContinuation<Error?, Never>] = []
    private var heldListingWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var savesToHold = 0
    private var heldSaves: [CheckedContinuation<Void, Never>] = []
    private var heldSaveWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    
    init(cvs: [CVModel] = []) {
        for cv in cvs {
            storedCVs[cv.id] = cv
        }
    }
    
    // MARK: - Test Controls
    
    func fail(_ operation: Operation, with error: Error?) {
        failures[operation] = error
    }
    
    func setUnreadableCount(_ count: Int) {
        unreadableCount = count
    }
    
    /// What the listing reports as the time the CV was last saved.
    func setLastSaved(_ date: Date, for id: UUID) {
        lastSavedAt[id] = date
    }
    
    /// The next `count` listings wait until `releaseOldestListing` lets them go.
    func holdNextListings(_ count: Int = 1) {
        listingsToHold = count
    }
    
    func waitUntilListingsAreHeld(_ count: Int) async {
        guard heldListings.count < count else { return }
        await withCheckedContinuation { heldListingWaiters.append((count, $0)) }
    }
    
    /// Lets the listing that started first go on: it returns the store as it was when it started, or fails.
    func releaseOldestListing(failingWith error: Error? = nil) {
        guard !heldListings.isEmpty else { return }
        heldListings.removeFirst().resume(returning: error)
    }
    
    /// Lets the listing that started last go on, while the ones that started earlier still wait.
    func releaseNewestListing(failingWith error: Error? = nil) {
        guard !heldListings.isEmpty else { return }
        heldListings.removeLast().resume(returning: error)
    }
    
    /// The next `count` saves wait until `releaseOldestSave` lets them go.
    func holdNextSaves(_ count: Int = 1) {
        savesToHold = count
    }

    func waitUntilSavesAreHeld(_ count: Int) async {
        guard heldSaves.count < count else { return }
        await withCheckedContinuation { heldSaveWaiters.append((count, $0)) }
    }

    /// Lets the save that started first go on and store its CV.
    func releaseOldestSave() {
        guard !heldSaves.isEmpty else { return }
        heldSaves.removeFirst().resume()
    }

    var storedNames: [String] {
        sorted(Array(storedCVs.values)).map(\.name)
    }
    
    // MARK: - CVRepositoryProtocol
    
    func getAllCVs() async throws -> [CVModel] {
        try await listing().cvs
    }
    
    func getCVListing() async throws -> CVListing {
        listingCount += 1
        return try await listing()
    }
    
    func acknowledgeUnreadableCVs() async throws {
        unreadableCount = 0
    }
    
    func getCV(by id: UUID) async throws -> CVModel? {
        try failIfNeeded(.get)
        return storedCVs[id]
    }
    
    func saveCV(_ cv: CVModel) async throws -> CVModel {
        try failIfNeeded(.save)
        if savesToHold > 0 {
            savesToHold -= 1
            await withCheckedContinuation { continuation in
                heldSaves.append(continuation)
                let ready = heldSaveWaiters.filter { $0.count <= heldSaves.count }
                heldSaveWaiters.removeAll { $0.count <= heldSaves.count }
                ready.forEach { $0.continuation.resume() }
            }
        }
        saveCount += 1
        storedCVs[cv.id] = cv
        return cv
    }
    
    func deleteCV(id: UUID) async throws {
        try failIfNeeded(.delete)
        storedCVs.removeValue(forKey: id)
        lastSavedAt.removeValue(forKey: id)
    }
    
    func cvExists() async throws -> Bool {
        !storedCVs.isEmpty
    }
    
    func getCVsCount() async throws -> Int {
        storedCVs.count
    }
    
    // MARK: - Private
    
    private func listing() async throws -> CVListing {
        try failIfNeeded(.listing)
        let seen = CVListing(cvs: sorted(Array(storedCVs.values)), lastSavedAt: lastSavedAt, unreadableCount: unreadableCount)
        guard listingsToHold > 0 else { return seen }
        
        listingsToHold -= 1
        let failure = await withCheckedContinuation { (continuation: CheckedContinuation<Error?, Never>) in
            heldListings.append(continuation)
            let ready = heldListingWaiters.filter { $0.count <= heldListings.count }
            heldListingWaiters.removeAll { $0.count <= heldListings.count }
            ready.forEach { $0.continuation.resume() }
        }
        if let failure {
            throw failure
        }
        return seen
    }
    
    private func failIfNeeded(_ operation: Operation) throws {
        if let error = failures[operation] {
            throw error
        }
    }
    
    private func sorted(_ cvs: [CVModel]) -> [CVModel] {
        cvs.sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }
}

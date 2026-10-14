import Foundation

// MARK: - CV Repository Implementation

public final class CVRepository: CVRepositoryProtocol, Sendable {
    private let storageService: StorageServiceProtocol
    private let now: @Sendable () -> Date

    // MARK: - Initialization

    /// - Parameter now: The clock that stamps the CVs when they are saved.
    public init(
        storageService: StorageServiceProtocol,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.storageService = storageService
        self.now = now
    }

    // MARK: - Public Protocol Implementation

    public func getAllCVs() async throws -> [CVModel] {
        return try await getCVListing().cvs
    }

    public func getCVListing() async throws -> CVListing {
        let report = try await storageService.loadAllReporting(StoredCV.self)
        return CVListing(
            cvs: report.items.sorted(by: StoredCV.isListedBefore).map(\.cv),
            lastSavedAt: Dictionary(uniqueKeysWithValues: report.items.compactMap { stored in
                stored.updatedAt.map { (stored.cv.id, $0) }
            }),
            unreadableCount: report.unreadableCount
        )
    }

    public func getCV(by id: UUID) async throws -> CVModel? {
        return try await storageService.loadIdentified(StoredCV.self, from: StoredCV.identifier(for: id))?.cv
    }

    public func saveCV(_ cv: CVModel) async throws -> CVModel {
        let now = self.now
        // The storage runs this between reading the stored CV and writing the new one, so the clock is read in
        // the order the saves are applied, and a creation time is never replaced by a later save.
        try await storageService.save(to: StoredCV.identifier(for: cv.id), updating: { (stored: StoredCV?) in
            let savedAt = Self.wholeSeconds(now())
            let createdAt = stored?.createdAt ?? savedAt
            // The wall clock can move backwards; an update is never dated before the creation.
            return StoredCV(cv: cv, createdAt: createdAt, updatedAt: max(savedAt, createdAt))
        })
        return cv
    }

    public func deleteCV(id: UUID) async throws {
        try await storageService.delete(identifier: StoredCV.identifier(for: id))
    }

    public func acknowledgeUnreadableCVs() async throws {
        try await storageService.acknowledgeQuarantined()
    }
    
    public func cvExists() async throws -> Bool {
        // A store whose every file is unusable still holds the user's CVs: it is not a first run.
        let listing = try await getCVListing()
        return !listing.cvs.isEmpty || listing.unreadableCount > 0
    }

    public func getCVsCount() async throws -> Int {
        return try await getAllCVs().count
    }
}

// MARK: - Private Helper Methods

extension CVRepository {

    /// A time in whole seconds, which is what the file keeps: the value saved is the value read back.
    private static func wholeSeconds(_ date: Date) -> Date {
        return Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }
}

import Foundation

/// Export history entry
public struct ExportHistoryEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    public let cvId: String
    public let cvName: String
    public let templateId: String
    public let exportDate: Date
    public let fileSize: Int64
    public let pageCount: Int

    public init(
        id: UUID = UUID(),
        cvId: String,
        cvName: String,
        templateId: String,
        exportDate: Date = Date(),
        fileSize: Int64 = 0,
        pageCount: Int = 1
    ) {
        self.id = id
        self.cvId = cvId
        self.cvName = cvName
        self.templateId = templateId
        self.exportDate = exportDate
        self.fileSize = fileSize
        self.pageCount = pageCount
    }
}

/// Protocol for managing export history and cached PDFs
public protocol ExportRepositoryProtocol: Sendable {
    /// Saves export history entry
    func saveExportHistory(_ entry: ExportHistoryEntry) async throws

    /// Retrieves export history
    /// - Parameter limit: Maximum number of entries to return
    /// - Returns: Array of export history entries, newest first
    func getExportHistory(limit: Int) async throws -> [ExportHistoryEntry]

    /// Caches generated PDF data
    /// - Parameters:
    ///   - data: PDF data to cache
    ///   - key: Unique cache key
    ///   - ttl: Time to live in seconds
    func cachePDF(data: Data, key: String, ttl: TimeInterval) async throws

    /// Retrieves cached PDF data
    /// - Parameter key: Cache key
    /// - Returns: Cached PDF data if exists and not expired
    func getCachedPDF(key: String) async -> Data?

    /// Clears expired cache entries
    func clearExpiredCache() async throws

    /// Clears all cache and history
    func clearAll() async throws
}
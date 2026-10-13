import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Null Export Repository Tests

@Suite("Null Export Repository")
struct NullExportRepositoryTests {

    @Test("keeps no export history")
    func keepsNoHistory() async throws {
        // Given
        let repository = NullExportRepository()

        // When
        try await repository.saveExportHistory(
            ExportHistoryEntry(cvId: "cv", cvName: "CV", templateId: "modern", fileSize: 10, pageCount: 1)
        )

        // Then
        #expect(try await repository.getExportHistory(limit: 10).isEmpty)
    }

    @Test("never returns a cached PDF")
    func neverReturnsCachedPDF() async throws {
        // Given
        let repository = NullExportRepository()

        // When
        try await repository.cachePDF(data: Data([1, 2, 3]), key: "key", ttl: 3600)

        // Then
        #expect(await repository.getCachedPDF(key: "key") == nil)
    }

    @Test("clearing is harmless")
    func clearingIsHarmless() async throws {
        let repository = NullExportRepository()

        try await repository.clearExpiredCache()
        try await repository.clearAll()

        #expect(try await repository.getExportHistory(limit: 1).isEmpty)
    }
}

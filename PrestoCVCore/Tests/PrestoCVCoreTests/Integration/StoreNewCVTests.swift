import Testing
import Foundation
@testable import PrestoCVCore

/// A new CV the editor saves is stored under the id it got when its editing began, so storing it again never makes
/// a second CV.
@Suite("Store new CV Tests")
struct StoreNewCVTests {

    private func makeUseCase(clock: ManualClock = ManualClock()) throws -> (useCase: CVManagementUseCase, directory: URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_new_cv_\(UUID().uuidString)")
        let storage = try FileStorageService(baseDirectory: directory)
        let useCase = CVManagementUseCase(
            cvRepository: CVRepository(storageService: storage, now: { clock.now() }),
            sampleRepository: SampleCVRepository(
                storageService: storage,
                categoryService: TemplateCategoryService(),
                bundleResourceService: MockBundleResourceService(),
                templateLoader: MockJSONTemplateLoader(),
                parallelSearchService: MockParallelSearchService()
            )
        )
        return (useCase, directory)
    }

    @Test("A new CV is stored under its own id")
    func newCVKeepsItsID() async throws {
        let (useCase, directory) = try makeUseCase()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cv = CVTestDataBuilder.minimalCV().withName("Ward nurse").build()

        let stored = try await useCase.storeNewCV(cv)

        #expect(stored.id == cv.id)
        #expect(try await useCase.getCV(by: cv.id) == cv)
    }

    @Test("Storing the same new CV again updates it: there is never a second CV")
    func storingAgainUpdates() async throws {
        let (useCase, directory) = try makeUseCase()
        defer { try? FileManager.default.removeItem(at: directory) }
        var cv = CVTestDataBuilder.minimalCV().withName("Ward nurse").build()
        _ = try await useCase.storeNewCV(cv)

        cv.personalInfo.title = "Senior nurse"
        _ = try await useCase.storeNewCV(cv)

        let all = try await useCase.getAllCVs()
        #expect(all.map(\.id) == [cv.id])
        #expect(all.first?.personalInfo.title == "Senior nurse")
    }
}

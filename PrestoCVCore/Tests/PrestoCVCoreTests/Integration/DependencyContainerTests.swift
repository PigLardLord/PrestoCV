import Testing
import Foundation
@testable import PrestoCVCore

@Suite("DependencyContainer Tests")
struct DependencyContainerTests {
    
    private func makeTemporaryStorageDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("test_container_\(UUID().uuidString)")
    }
    
    private func makeIsolatedContainer() -> DependencyContainer {
        let directory = makeTemporaryStorageDirectory()
        return DependencyContainer(storageDirectory: { directory })
    }
    
    // MARK: - Container Initialization Tests
    
    @Test("DependencyContainer initializes without errors")
    func containerInitialization() {
        let container = makeIsolatedContainer()
        #expect(type(of: container) == DependencyContainer.self)
    }
    
    @Test("TestDependencyContainer initializes without errors")
    func testContainerInitialization() {
        let container = TestDependencyContainer()
        #expect(type(of: container) == TestDependencyContainer.self)
    }
    
    // MARK: - Factory Method Tests
    
    @Test("makeOnboardingUseCase returns OnboardingUseCase instance")
    func makeOnboardingUseCaseReturnsCorrectType() throws {
        let container = TestDependencyContainer()
        let useCase = try container.makeOnboardingUseCase()
        
        #expect(useCase is OnboardingUseCase)
        #expect(type(of: useCase) == OnboardingUseCase.self)
    }
    
    @Test("makeCVManagementUseCase returns CVManagementUseCase instance")
    func makeCVManagementUseCaseReturnsCorrectType() throws {
        let container = TestDependencyContainer()
        let useCase = try container.makeCVManagementUseCase()
        
        #expect(useCase is CVManagementUseCase)
        #expect(type(of: useCase) == CVManagementUseCase.self)
    }
    
    // MARK: - Protocol Conformance Tests
    
    @Test("DependencyContainer conforms to DependencyContainerProtocol")
    func containerConformsToProtocol() throws {
        let container: DependencyContainerProtocol = TestDependencyContainer()
        
        // Test that protocol methods are accessible and return valid instances
        let onboardingUseCase = try container.makeOnboardingUseCase()
        let cvManagementUseCase = try container.makeCVManagementUseCase()
        
        // Verify the factory methods return concrete instances by checking they're not nil
        let onboardingUseCaseName = String(describing: type(of: onboardingUseCase))
        let cvManagementUseCaseName = String(describing: type(of: cvManagementUseCase))
        
        #expect(onboardingUseCaseName.contains("OnboardingUseCase"))
        #expect(cvManagementUseCaseName.contains("CVManagementUseCase"))
    }
    
    // MARK: - Real DependencyContainer Tests
    
    @Test("Real DependencyContainer creates OnboardingUseCase successfully")
    func realContainerCreatesOnboardingUseCase() throws {
        let container = makeIsolatedContainer()
        let useCase = try container.makeOnboardingUseCase()
        
        #expect(useCase is OnboardingUseCase)
    }
    
    @Test("Real DependencyContainer creates CVManagementUseCase successfully")  
    func realContainerCreatesCVManagementUseCase() throws {
        let container = makeIsolatedContainer()
        let useCase = try container.makeCVManagementUseCase()
        
        #expect(useCase is CVManagementUseCase)
    }
    
    @Test("Real DependencyContainer creates SampleCVRepository successfully")
    func realContainerCreatesSampleCVRepository() throws {
        let container = makeIsolatedContainer()
        let repository = try container.makeSampleCVRepository()
        
        #expect(repository is SampleCVRepository)
    }
    
    @Test("Real DependencyContainer creates TemplateCategoryService successfully")
    func realContainerCreatesTemplateCategoryService() throws {
        let container = makeIsolatedContainer()
        let service = try container.makeTemplateCategoryService()
        
        #expect(service is TemplateCategoryService)
    }
    
    @Test("Real DependencyContainer maintains service consistency")
    func realContainerMaintainsServiceConsistency() throws {
        let container = makeIsolatedContainer()
        
        // Create multiple instances to verify they work consistently
        let useCase1 = try container.makeOnboardingUseCase()
        let useCase2 = try container.makeCVManagementUseCase()
        let repository = try container.makeSampleCVRepository()
        let service = try container.makeTemplateCategoryService()
        
        // Verify all instances are created successfully
        #expect(useCase1 is OnboardingUseCase)
        #expect(useCase2 is CVManagementUseCase)
        #expect(repository is SampleCVRepository)
        #expect(service is TemplateCategoryService)
    }
    
    // MARK: - Storage Location Tests
    
    @Test("Default storage directory is PrestoCV/CVs under Application Support")
    func defaultStorageDirectoryIsInApplicationSupport() throws {
        let directory = try DependencyContainer.defaultStorageDirectory()
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        
        #expect(directory == applicationSupport.appendingPathComponent("PrestoCV/CVs", isDirectory: true))
    }
    
    @Test("Container stores CVs in the directory it was given")
    func containerStoresCVsInGivenDirectory() async throws {
        let directory = makeTemporaryStorageDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = DependencyContainer(storageDirectory: { directory })
        
        let useCase = try container.makeCVManagementUseCase()
        let created = try await useCase.createCV(from: CVTestDataBuilder.minimalCV().build())
        
        let fileURL = directory.appendingPathComponent("cv_\(created.id.uuidString).json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    @Test("Default unsaved edits directory is PrestoCV/UnsavedEdits under Application Support, beside the CVs")
    func defaultUnsavedEditsDirectoryIsInApplicationSupport() throws {
        let directory = try DependencyContainer.defaultUnsavedEditsDirectory()
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        
        #expect(directory == applicationSupport.appendingPathComponent("PrestoCV/UnsavedEdits", isDirectory: true))
    }
    
    @Test("A storage directory that cannot be resolved fails with serviceCreationFailed")
    func unresolvableStorageDirectoryFailsServiceCreation() {
        struct NoStorageDirectory: Error {}
        let container = DependencyContainer(storageDirectory: { throw NoStorageDirectory() })
        
        #expect {
            try container.makeCVManagementUseCase()
        } throws: { error in
            guard case DependencyError.serviceCreationFailed(let service, let underlying) = error else { return false }
            return service == "StorageService" && underlying is NoStorageDirectory
        }
    }
}

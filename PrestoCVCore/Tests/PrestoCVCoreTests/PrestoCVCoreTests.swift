import Testing
import Foundation
@testable import PrestoCVCore

// MARK: - Test Doubles

/// A mock storage service that operates entirely in memory for isolated testing
final class MockStorageService: StorageServiceProtocol {
    private var storage: [String: Data] = [:]
    
    func save<T: Codable>(_ object: T, to identifier: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(object)
        storage[identifier] = data
    }
    
    func load<T: Codable>(_ type: T.Type, from identifier: String) async throws -> T? {
        guard let data = storage[identifier] else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    
    func loadAll<T: Codable>(_ type: T.Type) async throws -> [T] {
        var objects: [T] = []
        for data in storage.values {
            if let object = try? JSONDecoder().decode(type, from: data) {
                objects.append(object)
            }
        }
        return objects
    }
    
    func delete(identifier: String) async throws {
        storage.removeValue(forKey: identifier)
    }
    
    func exists(identifier: String) async -> Bool {
        return storage[identifier] != nil
    }
    
    func getAllIdentifiers() async throws -> [String] {
        return Array(storage.keys)
    }
    
    // Test helper methods
    func clear() {
        storage.removeAll()
    }
    
    func isEmpty() -> Bool {
        return storage.isEmpty
    }
}

/// A test dependency container that uses mocked services
final class TestDependencyContainer: DependencyContainerProtocol {
    private let mockStorageService = MockStorageService()
    
    private lazy var cvRepository: CVRepositoryProtocol = {
        return CVRepository(storageService: mockStorageService)
    }()
    
    private lazy var templateRepository: TemplateRepositoryProtocol = {
        return TemplateRepository(storageService: mockStorageService)
    }()
    
    private lazy var onboardingRepository: OnboardingRepositoryProtocol = {
        return OnboardingRepository(cvRepository: cvRepository)
    }()
    
    func makeOnboardingUseCase() -> OnboardingUseCaseProtocol {
        return OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            templateRepository: templateRepository,
            cvRepository: cvRepository
        )
    }
    
    func makeCVManagementUseCase() -> CVManagementUseCaseProtocol {
        return CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
    }
    
    // Test helper method to reset state
    func reset() {
        mockStorageService.clear()
    }
}

// MARK: - DependencyContainer Tests

@Suite("DependencyContainer Tests")
struct DependencyContainerTests {
    
    // MARK: - Container Initialization Tests
    
    @Test("DependencyContainer initializes without errors")
    func containerInitialization() {
        let container = DependencyContainer()
        #expect(type(of: container) == DependencyContainer.self)
    }
    
    @Test("TestDependencyContainer initializes without errors")
    func testContainerInitialization() {
        let container = TestDependencyContainer()
        #expect(type(of: container) == TestDependencyContainer.self)
    }
    
    // MARK: - Factory Method Tests
    
    @Test("makeOnboardingUseCase returns OnboardingUseCase instance")
    func makeOnboardingUseCaseReturnsCorrectType() {
        let container = TestDependencyContainer()
        let useCase = container.makeOnboardingUseCase()
        
        #expect(useCase is OnboardingUseCase)
        #expect(type(of: useCase) == OnboardingUseCase.self)
    }
    
    @Test("makeCVManagementUseCase returns CVManagementUseCase instance")
    func makeCVManagementUseCaseReturnsCorrectType() {
        let container = TestDependencyContainer()
        let useCase = container.makeCVManagementUseCase()
        
        #expect(useCase is CVManagementUseCase)
        #expect(type(of: useCase) == CVManagementUseCase.self)
    }
    
    // MARK: - Protocol Conformance Tests
    
    @Test("DependencyContainer conforms to DependencyContainerProtocol")
    func containerConformsToProtocol() {
        let container: DependencyContainerProtocol = TestDependencyContainer()
        
        // Test that protocol methods are accessible and return valid instances
        let onboardingUseCase = container.makeOnboardingUseCase()
        let cvManagementUseCase = container.makeCVManagementUseCase()
        
        // Verify the factory methods return concrete instances by checking they're not nil
        let onboardingUseCaseName = String(describing: type(of: onboardingUseCase))
        let cvManagementUseCaseName = String(describing: type(of: cvManagementUseCase))
        
        #expect(onboardingUseCaseName.contains("OnboardingUseCase"))
        #expect(cvManagementUseCaseName.contains("CVManagementUseCase"))
    }
}

// MARK: - Isolated Dependency Wiring Tests

@Suite("Dependency Wiring Tests")
struct DependencyWiringTests {
    
    @Test("OnboardingUseCase is properly wired with dependencies")
    func onboardingUseCaseIsProperlyWired() async {
        let container = TestDependencyContainer()
        defer { container.reset() }
        
        let useCase = container.makeOnboardingUseCase()
        
        // Test that the use case can perform its basic operations without errors
        let onboardingState = await useCase.checkOnboardingRequired()
        // Should be .firstTime since no CVs exist in clean mock storage
        #expect(onboardingState == .firstTime)
    }
    
    @Test("CVManagementUseCase is properly wired with dependencies")
    func cvManagementUseCaseIsProperlyWired() async throws {
        let container = TestDependencyContainer()
        defer { container.reset() }
        
        let useCase = container.makeCVManagementUseCase()
        
        // Test that the use case can perform basic operations without crashing
        let cvs = try await useCase.getAllCVs()
        // Should be empty initially with clean mock storage
        #expect(cvs.count == 0)
    }
    
    @Test("Container maintains consistent service instances")
    func containerMaintainsConsistentServiceInstances() async throws {
        let container = TestDependencyContainer()
        defer { container.reset() }
        
        // Create multiple use cases
        let onboardingUseCase1 = container.makeOnboardingUseCase()
        let onboardingUseCase2 = container.makeOnboardingUseCase()
        let cvManagementUseCase1 = container.makeCVManagementUseCase()
        let cvManagementUseCase2 = container.makeCVManagementUseCase()
        
        // Test that they share the same underlying repositories by checking behavior consistency
        // Both onboarding use cases should return the same state
        let state1 = await onboardingUseCase1.checkOnboardingRequired()
        let state2 = await onboardingUseCase2.checkOnboardingRequired()
        #expect(state1 == state2)
        #expect(state1 == .firstTime) // Should be firstTime with empty mock storage
        
        // Both CV management use cases should return the same CV count
        let cvs1 = try await cvManagementUseCase1.getAllCVs()
        let cvs2 = try await cvManagementUseCase2.getAllCVs()
        #expect(cvs1.count == cvs2.count)
        #expect(cvs1.count == 0) // Should be 0 with empty mock storage
    }
}

// MARK: - Integration Tests

@Suite("Integration Tests")
struct IntegrationTests {
    
    @Test("Container creates functional dependency graph")
    func containerCreatesFunctionalDependencyGraph() async throws {
        let container = TestDependencyContainer()
        defer { container.reset() }
        
        // Test that the entire dependency graph works together
        let onboardingUseCase = container.makeOnboardingUseCase()
        let cvManagementUseCase = container.makeCVManagementUseCase()
        
        // Check initial state - should be .firstTime with empty mock storage
        let initialState = await onboardingUseCase.checkOnboardingRequired()
        let initialCVs = try await cvManagementUseCase.getAllCVs()
        
        #expect(initialState == .firstTime)
        #expect(initialCVs.count == 0)
        
        // Create a CV and verify it's added
        let uniqueName = "Integration Test CV"
        let template = CVModel(name: uniqueName)
        let createdCV = try await onboardingUseCase.createFirstCV(from: template)
        
        #expect(createdCV.name == uniqueName)
        #expect(createdCV.id != template.id) // Should have new ID
        
        // Verify that the CV was added to the collection
        let newState = await onboardingUseCase.checkOnboardingRequired()
        let newCVs = try await cvManagementUseCase.getAllCVs()
        
        #expect(newState == .returning) // Should now show returning user after CV creation
        #expect(newCVs.count == 1) // Should have exactly one CV
        #expect(newCVs.contains { $0.name == uniqueName }) // Should contain our new CV
    }
    
    @Test("CV creation and management workflow")
    func cvCreationAndManagementWorkflow() async throws {
        let container = TestDependencyContainer()
        defer { container.reset() }
        
        let cvManagementUseCase = container.makeCVManagementUseCase()
        
        // Start with empty storage
        let initialCVs = try await cvManagementUseCase.getAllCVs()
        #expect(initialCVs.count == 0)
        
        // Create a CV using the management use case
        let template = CVModel(name: "Test CV")
        let createdCV = try await cvManagementUseCase.createCV(from: template)
        
        #expect(createdCV.name == "Test CV")
        #expect(createdCV.id != template.id)
        
        // Verify it was added
        let cvsAfterCreation = try await cvManagementUseCase.getAllCVs()
        #expect(cvsAfterCreation.count == 1)
        #expect(cvsAfterCreation.first?.name == "Test CV")
        
        // Update the CV
        let updatedCV = CVModel(
            id: createdCV.id,
            name: "Updated Test CV",
            title: createdCV.title,
            location: createdCV.location,
            email: createdCV.email,
            phone: createdCV.phone,
            portfolio: createdCV.portfolio,
            profile: createdCV.profile,
            relevant_experience: createdCV.relevant_experience,
            education: createdCV.education,
            skills: createdCV.skills,
            languages: createdCV.languages,
            certifications: createdCV.certifications,
            interests: createdCV.interests,
            social: createdCV.social
        )
        
        let savedUpdatedCV = try await cvManagementUseCase.updateCV(updatedCV)
        #expect(savedUpdatedCV.name == "Updated Test CV")
        #expect(savedUpdatedCV.id == createdCV.id)
        
        // Verify the update
        let cvsAfterUpdate = try await cvManagementUseCase.getAllCVs()
        #expect(cvsAfterUpdate.count == 1)
        #expect(cvsAfterUpdate.first?.name == "Updated Test CV")
        
        // Delete the CV
        try await cvManagementUseCase.deleteCV(id: createdCV.id)
        
        // Verify deletion
        let cvsAfterDeletion = try await cvManagementUseCase.getAllCVs()
        #expect(cvsAfterDeletion.count == 0)
    }
    
    @Test("CV duplication workflow")
    func cvDuplicationWorkflow() async throws {
        let container = TestDependencyContainer()
        defer { container.reset() }
        
        let cvManagementUseCase = container.makeCVManagementUseCase()
        
        // Create an original CV
        let originalTemplate = CVModel(name: "Original CV")
        let originalCV = try await cvManagementUseCase.createCV(from: originalTemplate)
        
        // Duplicate the CV
        let duplicatedCV = try await cvManagementUseCase.duplicateCV(id: originalCV.id)
        
        #expect(duplicatedCV.name.contains("Copy")) // Should have "Copy" in the name
        #expect(duplicatedCV.id != originalCV.id) // Should have different ID
        
        // Verify both CVs exist
        let allCVs = try await cvManagementUseCase.getAllCVs()
        #expect(allCVs.count == 2)
        #expect(allCVs.contains { $0.id == originalCV.id })
        #expect(allCVs.contains { $0.id == duplicatedCV.id })
    }
}

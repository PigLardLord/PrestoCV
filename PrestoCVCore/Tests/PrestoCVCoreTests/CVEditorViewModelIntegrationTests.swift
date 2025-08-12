import Testing
import Foundation
@testable import PrestoCVCore

@Suite("CVEditorViewModel Integration Tests")
struct CVEditorViewModelIntegrationTests {
    
    @Test("CVEditorViewModel loads existing CV correctly")
    func viewModelLoadsExistingCV() async throws {
        // Create mock use case with a stored CV
        let mockUseCase = MockCVManagementUseCase()
        let testCV = CVModel(
            id: UUID(),
            name: "Test CV",
            title: "Software Engineer",
            location: "San Francisco, CA",
            email: "test@example.com",
            phone: "+1234567890",
            portfolio: "https://example.com",
            profile: "Test profile description",
            relevant_experience: [
                Experience(
                    id: UUID(),
                    title: "Senior Developer",
                    company: "Test Company",
                    location: "Remote",
                    period: "2020-Present",
                    description: "Worked on various projects"
                )
            ],
            skills: [
                Skill(id: UUID(), name: "Swift", level: 5),
                Skill(id: UUID(), name: "iOS", level: 5)
            ]
        )
        
        // Store the CV in the mock
        mockUseCase.storeCV(testCV)
        
        // Create view model with the CV ID
        let viewModel = CVEditorViewModel(
            cvId: testCV.id.uuidString,
            cvManagementUseCase: mockUseCase
        )
        
        // Initially, the CV should be empty/default
        #expect(viewModel.cv.name == "")
        #expect(viewModel.cv.title == "")
        
        // Load the CV
        await viewModel.loadCV()
        
        // After loading, the CV should have the correct data
        #expect(viewModel.cv.name == "Test CV")
        #expect(viewModel.cv.title == "Software Engineer")
        #expect(viewModel.cv.email == "test@example.com")
        #expect(viewModel.cv.relevant_experience.count == 1)
        #expect(viewModel.cv.skills.count == 2)
    }
    
    @Test("CVEditorViewModel handles new CV correctly")
    func viewModelHandlesNewCV() async throws {
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            cvManagementUseCase: mockUseCase
        )
        
        // For new CVs, it should be initialized as loaded with empty data
        #expect(viewModel.cv.name == "")
        #expect(viewModel.cv.title == "")
        #expect(viewModel.cv.relevant_experience.isEmpty)
        #expect(viewModel.cv.skills.isEmpty)
    }
    
    // MARK: - Mock Implementation
    
    private class MockCVManagementUseCase: CVManagementUseCaseProtocol {
        private var storedCVs: [UUID: CVModel] = [:]
        
        func storeCV(_ cv: CVModel) {
            storedCVs[cv.id] = cv
        }
        
        func getAllCVs() async throws -> [CVModel] {
            return Array(storedCVs.values)
        }
        
        func createCV(from template: CVModel) async throws -> CVModel {
            var newCV = template
            newCV.id = UUID()
            storedCVs[newCV.id] = newCV
            return newCV
        }
        
        func updateCV(_ cv: CVModel) async throws -> CVModel {
            storedCVs[cv.id] = cv
            return cv
        }
        
        func deleteCV(id: UUID) async throws {
            storedCVs.removeValue(forKey: id)
        }
        
        func duplicateCV(id: UUID) async throws -> CVModel {
            guard let existingCV = storedCVs[id] else {
                throw AppError.notFound("CV not found")
            }
            
            var duplicatedCV = existingCV
            duplicatedCV.id = UUID()
            duplicatedCV.name = "\(existingCV.name) (Copy)"
            storedCVs[duplicatedCV.id] = duplicatedCV
            return duplicatedCV
        }
        
        func getCV(by id: UUID) async throws -> CVModel? {
            return storedCVs[id]
        }
    }
}
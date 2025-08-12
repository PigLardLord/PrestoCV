import Testing
import Foundation
@testable import PrestoCVCore

@Suite("CVEditorViewModel Tests")
struct CVEditorViewModelTests {
    
    // MARK: - Initialization Tests
    
    @Test("CVEditorViewModel initializes with nil CV ID for new CV")
    func viewModelInitializesWithNilCVId() throws {
        let mockUseCase = createMockCVManagementUseCase()
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: mockUseCase)
        
        #expect(viewModel.cv.name == "")
        #expect(viewModel.cv.title == "")
        #expect(viewModel.cv.relevant_experience.isEmpty)
        #expect(viewModel.cv.skills.isEmpty)
    }
    
    @Test("CVEditorViewModel initializes with valid CV ID")
    func viewModelInitializesWithValidCVId() throws {
        let mockUseCase = createMockCVManagementUseCase()
        let viewModel = CVEditorViewModel(cvId: "some-id", cvManagementUseCase: mockUseCase)
        
        #expect(viewModel.cv.name == "")
        #expect(viewModel.cv.title == "")
        #expect(viewModel.cv.relevant_experience.isEmpty)
        #expect(viewModel.cv.skills.isEmpty)
    }
    
    // MARK: - Helper Methods
    
    private func createMockCVManagementUseCase() -> CVManagementUseCaseProtocol {
        return MockCVManagementUseCase()
    }
    
    // MARK: - Mock Implementation
    
    private class MockCVManagementUseCase: CVManagementUseCaseProtocol {
        var storedCVs: [UUID: CVModel] = [:]
        
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
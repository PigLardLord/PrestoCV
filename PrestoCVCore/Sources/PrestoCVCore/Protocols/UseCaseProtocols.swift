import Foundation

// MARK: - Use Case Protocols

/// Protocol for managing user onboarding flow and first CV creation
public protocol OnboardingUseCaseProtocol: Sendable {
    /// Determines if the user requires onboarding based on existing data
    /// - Returns: OnboardingState indicating whether user is first-time or returning
    func checkOnboardingRequired() async -> OnboardingState
    
    /// Creates the user's first CV from a template during onboarding
    /// - Parameter template: The CVModel template to base the new CV on
    /// - Returns: The newly created CVModel with a unique ID
    /// - Throws: AppError if CV creation or saving fails
    func createFirstCV(from template: CVModel) async throws -> CVModel
}

/// Protocol for comprehensive CV management operations
public protocol CVManagementUseCaseProtocol: Sendable {
    /// Retrieves all user's CVs
    /// - Returns: Array of all CVModel instances belonging to the user
    /// - Throws: AppError if retrieval fails
    func getAllCVs() async throws -> [CVModel]
    
    /// Creates a new CV from a template
    /// - Parameter template: The CVModel template to base the new CV on
    /// - Returns: The newly created CVModel with a unique ID
    /// - Throws: AppError if CV creation or saving fails
    func createCV(from template: CVModel) async throws -> CVModel
    
    /// Updates an existing CV with new data
    /// - Parameter cv: The CVModel with updated information
    /// - Returns: The updated CVModel as saved in storage
    /// - Throws: AppError if update or saving fails
    func updateCV(_ cv: CVModel) async throws -> CVModel
    
    /// Deletes a CV permanently
    /// - Parameter id: The UUID of the CV to delete
    /// - Throws: AppError if CV doesn't exist or deletion fails
    func deleteCV(id: UUID) async throws
    
    /// Creates a duplicate copy of an existing CV
    /// - Parameter id: The UUID of the CV to duplicate
    /// - Returns: The new duplicated CVModel with a unique ID and modified name
    /// - Throws: AppError if source CV doesn't exist or duplication fails
    func duplicateCV(id: UUID) async throws -> CVModel
    
    /// Retrieves a specific CV by its unique identifier
    /// - Parameter id: The UUID of the CV to retrieve
    /// - Returns: The CVModel if found, nil otherwise
    /// - Throws: AppError if retrieval fails
    func getCV(by id: UUID) async throws -> CVModel?
}
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
    
    /// Retrieves all user's CVs, and counts the stored files that could not be opened as CVs
    /// - Returns: The CVs in list order, and the number of files that could not be opened
    /// - Throws: AppError if retrieval fails
    func getCVListing() async throws -> CVListing
    
    /// Records that the user has been told about the CV files that could not be opened, so they are no longer
    /// counted in the listing. The files are kept.
    /// - Throws: AppError if the files cannot be moved
    func acknowledgeUnreadableCVs() async throws
    
    /// Creates a new CV from a template
    /// - Parameter template: The CVModel template to base the new CV on
    /// - Returns: The newly created CVModel with a unique ID
    /// - Throws: AppError if CV creation or saving fails
    func createCV(from template: CVModel) async throws -> CVModel
    
    /// Stores a CV that the editor started, under the id it got when its editing began. Storing it again updates
    /// it, so a first save that is repeated, after the app was ended in the middle of it, never makes a second CV.
    /// - Parameter cv: The CV with its own id
    /// - Returns: The CV as stored
    /// - Throws: AppError if saving fails
    func storeNewCV(_ cv: CVModel) async throws -> CVModel
    
    /// Updates an existing CV with new data
    /// - Parameter cv: The CVModel with updated information
    /// - Returns: The updated CVModel as saved in storage
    /// - Throws: AppError if update or saving fails
    func updateCV(_ cv: CVModel) async throws -> CVModel
    
    /// Deletes a CV permanently. Deleting a CV that does not exist is not an error.
    /// - Parameter id: The UUID of the CV to delete
    /// - Throws: AppError if deletion fails
    func deleteCV(id: UUID) async throws
    
    /// Stores a copy of an existing CV, under a new identity
    /// - Parameters:
    ///   - id: The UUID of the CV to duplicate
    ///   - name: The name of the copy, which the caller gives it by the rule of PrestoCVDomain (`CVTitle.copyName`)
    /// - Returns: The copy, as stored
    /// - Throws: AppError if source CV doesn't exist or duplication fails
    func duplicateCV(id: UUID, named name: String) async throws -> CVModel
    
    /// Retrieves a specific CV by its unique identifier
    /// - Parameter id: The UUID of the CV to retrieve
    /// - Returns: The CVModel if found, nil otherwise
    /// - Throws: AppError if retrieval fails
    func getCV(by id: UUID) async throws -> CVModel?
}

extension CVManagementUseCaseProtocol {
    /// For a use case that does not tell which files it could not open: every CV it returns was opened.
    public func getCVListing() async throws -> CVListing {
        return CVListing(cvs: try await getAllCVs())
    }
    
    /// For a use case that sets no files aside: there is nothing to acknowledge.
    public func acknowledgeUnreadableCVs() async throws {}
}

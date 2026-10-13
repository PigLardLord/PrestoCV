import Foundation

// MARK: - Repository Protocols

/// Protocol for managing CV data persistence and retrieval
public protocol CVRepositoryProtocol: Sendable {
    /// Retrieves all stored CVs
    /// - Returns: Array of all CVModel instances
    /// - Throws: AppError if retrieval fails
    func getAllCVs() async throws -> [CVModel]
    
    /// Retrieves all stored CVs, and counts the stored files that could not be opened as CVs
    ///
    /// A file that could not be opened is counted until it can be, or, when it is corrupt and was set aside,
    /// until `acknowledgeUnreadableCVs()` is called. Which call set it aside makes no difference.
    /// - Returns: The CVs in list order, and the number of files that could not be opened
    /// - Throws: AppError if the stored CVs cannot be listed
    func getCVListing() async throws -> CVListing
    
    /// Records that the user has been told about the CV files that were set aside, so they are no longer counted
    /// in the listing. The files are kept.
    /// - Throws: AppError if the files cannot be moved
    func acknowledgeUnreadableCVs() async throws
    
    /// Retrieves a specific CV by its unique identifier
    /// - Parameter id: The UUID of the CV to retrieve
    /// - Returns: The CVModel if found, nil otherwise
    /// - Throws: AppError if retrieval fails
    func getCV(by id: UUID) async throws -> CVModel?
    
    /// Saves a CV to persistent storage
    /// - Parameter cv: The CVModel to save
    /// - Returns: The saved CVModel with any updates (e.g., timestamps)
    /// - Throws: AppError if save operation fails
    func saveCV(_ cv: CVModel) async throws -> CVModel
    
    /// Deletes a CV from persistent storage. Deleting a CV that does not exist is not an error.
    /// - Parameter id: The UUID of the CV to delete
    /// - Throws: AppError if deletion fails
    func deleteCV(id: UUID) async throws
    
    /// Checks if any CVs exist in storage, including CVs that could not be opened
    /// - Returns: true if at least one CV is stored or waits to be acknowledged, false otherwise
    /// - Throws: AppError if the stored CVs cannot be listed
    func cvExists() async throws -> Bool
    
    /// Gets the total count of CVs in storage
    /// - Returns: The number of CVs currently stored
    /// - Throws: AppError if the stored CVs cannot be listed
    func getCVsCount() async throws -> Int
}

/// Protocol for managing user onboarding state
public protocol OnboardingRepositoryProtocol: Sendable {
    /// Checks if the user has any existing CVs, including CVs that could not be opened
    /// - Returns: true if user has created CVs before, false otherwise
    /// - Throws: AppError if the stored CVs cannot be listed
    func hasExistingCVs() async throws -> Bool
    
    /// Determines the current onboarding state based on existing data
    /// - Returns: OnboardingState indicating if user is first-time or returning, or `.error` if the stored CVs cannot be listed
    func getOnboardingState() async -> OnboardingState
}

/// Protocol for managing sample CV templates
public protocol SampleCVRepositoryProtocol: Sendable {
    /// Retrieves the default empty CV template
    /// - Returns: A CVModel configured as the default template
    /// - Throws: AppError if template retrieval fails
    func getDefaultSample() async throws -> CVModel
    
    /// Retrieves all available sample CV templates
    /// - Returns: Array of all available CVModel templates
    /// - Throws: AppError if templates retrieval fails
    func getAllSamples() async throws -> [CVModel]
    
    /// Retrieves a specific sample template by name
    /// - Parameter name: The name identifier of the template
    /// - Returns: The CVModel template if found, nil otherwise
    /// - Throws: AppError if retrieval fails
    func getSample(by name: String) async throws -> CVModel?
}
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

/// Keeps the edits that the editor has not saved yet on the device, so that they survive the app being ended, and
/// finds them again. Each set of edits has one holder at a time, an editor or a window, which alone changes them.
public protocol UnsavedEditsUseCaseProtocol: Sendable {
    /// Takes the edits of a new editing, which has kept nothing yet, for its editor.
    /// - Returns: The claim, or nil when the editing is held already
    func claimEditing(_ editing: UUID) async -> UnsavedEditsClaim?
    
    /// Takes offered edits for one window, which then restores or discards them. Edits are held by one window or
    /// editor at a time, and only while they are kept as they were offered: an offer another window holds, or one that
    /// is no longer what is kept, is refused, and holds nothing.
    /// - Returns: The claim, or nil when the edits cannot be taken
    /// - Throws: AppError if the kept edits cannot be read
    func claim(_ edits: UnsavedEdits) async throws -> UnsavedEditsClaim?
    
    /// Lets go of edits: they are offered again, unless they were removed. A claim that no longer holds them does nothing.
    func release(_ claim: UnsavedEditsClaim) async
    
    /// Keeps the CV as the editor shows it, replacing what the editing kept before.
    /// - Parameters:
    ///   - cv: The CV as the editor shows it, with the id it is stored under or will be
    ///   - base: The stored CV the edits were made on, or what a save that has started is storing; nil when nothing
    ///     was stored yet
    ///   - claim: The claim that holds the editing
    /// - Throws: `UnsavedEditsError.notHeld` if the claim does not hold the editing; AppError if they cannot be kept
    func keep(_ cv: CVModel, over base: CVModel?, as claim: UnsavedEditsClaim) async throws
    
    /// Removes what an editing kept, once its edits were saved or discarded.
    /// - Throws: `UnsavedEditsError.notHeld` if the claim does not hold the editing; AppError if they cannot be removed
    func discard(as claim: UnsavedEditsClaim) async throws
    
    /// The latest kept edits that nobody holds: left by an earlier run of the app, or by an editor that went away
    /// without saving or discarding them.
    /// - Returns: The edits to offer to restore, or nil when there are none
    /// - Throws: AppError if the kept edits cannot be listed
    func editsToRestore() async throws -> UnsavedEdits?
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

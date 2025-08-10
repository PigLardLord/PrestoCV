import Foundation

// MARK: - Template Repository Implementation

public final class TemplateRepository: TemplateRepositoryProtocol, @unchecked Sendable {
    private let storageService: StorageServiceProtocol
    
    public init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }
    
    public func getDefaultTemplate() async throws -> CVModel {
        // Return a default empty CV template
        return CVModel()
    }
    
    public func getAllTemplates() async throws -> [CVModel] {
        // For now, just return the default template
        // Later this could load templates from bundle or remote
        return [try await getDefaultTemplate()]
    }
    
    public func getTemplate(by name: String) async throws -> CVModel? {
        if name == "default" {
            return try await getDefaultTemplate()
        }
        return nil
    }
}
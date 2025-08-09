import Foundation

// MARK: - Repository Protocols

public protocol CVRepositoryProtocol {
    func getAllCVs() async throws -> [CVModel]
    func getCV(by id: UUID) async throws -> CVModel?
    func saveCV(_ cv: CVModel) async throws -> CVModel
    func deleteCV(id: UUID) async throws
    func cvExists() async -> Bool
    func getCVsCount() async -> Int
}

public protocol OnboardingRepositoryProtocol {
    func hasExistingCVs() async -> Bool
    func getOnboardingState() async -> OnboardingState
}

public protocol TemplateRepositoryProtocol {
    func getDefaultTemplate() async throws -> CVModel
    func getAllTemplates() async throws -> [CVModel]
    func getTemplate(by name: String) async throws -> CVModel?
}

// MARK: - Use Case Protocols

public protocol OnboardingUseCaseProtocol {
    func checkOnboardingRequired() async -> OnboardingState
    func createFirstCV(from template: CVModel) async throws -> CVModel
}

public protocol CVManagementUseCaseProtocol {
    func getAllCVs() async throws -> [CVModel]
    func createCV(from template: CVModel) async throws -> CVModel
    func updateCV(_ cv: CVModel) async throws -> CVModel
    func deleteCV(id: UUID) async throws
    func duplicateCV(id: UUID) async throws -> CVModel
}

// MARK: - Infrastructure Protocols

public protocol StorageServiceProtocol {
    func save<T: Codable>(_ object: T, to identifier: String) async throws
    func load<T: Codable>(_ type: T.Type, from identifier: String) async throws -> T?
    func loadAll<T: Codable>(_ type: T.Type) async throws -> [T]
    func delete(identifier: String) async throws
    func exists(identifier: String) async -> Bool
    func getAllIdentifiers() async throws -> [String]
}

public protocol NetworkServiceProtocol {
    func upload<T: Codable>(_ object: T, to endpoint: String) async throws -> T
    func download<T: Codable>(_ type: T.Type, from endpoint: String) async throws -> T
    func sync<T: Codable>(_ objects: [T], with endpoint: String) async throws -> [T]
}

public protocol CacheServiceProtocol {
    func set<T: Codable>(_ object: T, forKey key: String) async
    func get<T: Codable>(_ type: T.Type, forKey key: String) async -> T?
    func remove(forKey key: String) async
    func clear() async
}

// MARK: - Dependency Container Protocol

public protocol DependencyContainerProtocol {
    func makeOnboardingUseCase() throws -> OnboardingUseCaseProtocol
    func makeCVManagementUseCase() throws -> CVManagementUseCaseProtocol
}
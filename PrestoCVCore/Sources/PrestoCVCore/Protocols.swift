import Foundation

// MARK: - Repository Protocols

public protocol CVRepositoryProtocol: Sendable {
    func getAllCVs() async throws -> [CVModel]
    func getCV(by id: UUID) async throws -> CVModel?
    func saveCV(_ cv: CVModel) async throws -> CVModel
    func deleteCV(id: UUID) async throws
    func cvExists() async -> Bool
    func getCVsCount() async -> Int
}

public protocol OnboardingRepositoryProtocol: Sendable {
    func hasExistingCVs() async -> Bool
    func getOnboardingState() async -> OnboardingState
}

public protocol SampleCVRepositoryProtocol: Sendable {
    func getDefaultSample() async throws -> CVModel
    func getAllSamples() async throws -> [CVModel]
    func getSample(by name: String) async throws -> CVModel?
}

// MARK: - Service Protocols

public protocol TemplateCategoryServiceProtocol: Sendable {
    func matchTemplateCategory(for fileName: String, to category: String) -> Bool
    func getCategoryKeywords() -> [String: [String]]
}

public protocol ParallelSearchServiceProtocol: Sendable {
    func findFirst<Source, Item>(
        in sources: [Source],
        loader: @escaping @Sendable (Source) async throws -> Item?,
        matcher: @escaping @Sendable (Item) -> Bool
    ) async throws -> Item? where Source: Sendable, Item: Sendable
    
    func findAll<Source, Item>(
        in sources: [Source],
        loader: @escaping @Sendable (Source) async throws -> Item?,
        matcher: @escaping @Sendable (Item) -> Bool
    ) async throws -> [Item] where Source: Sendable, Item: Sendable
}

public protocol BundleResourceServiceProtocol: Sendable {
    func getResourcePaths(ofType type: String, inDirectory directory: String?) async -> [String]
    func getResourceURL(forResource name: String, withExtension ext: String) async -> URL?
    func filterPaths(_ paths: [String], excluding excludedNames: Set<String>) async -> [String]
}

public protocol JSONTemplateLoaderProtocol: Sendable {
    func loadTemplate(from path: String) async -> CVModel?
    func loadTemplate(from url: URL) async throws -> CVModel
    func loadTemplates(from paths: [String]) async -> [CVModel]
    func loadTemplateIfMatches(
        path: String,
        matcher: @Sendable (String) -> Bool
    ) async throws -> CVModel?
}

// MARK: - Use Case Protocols

public protocol OnboardingUseCaseProtocol: Sendable {
    func checkOnboardingRequired() async -> OnboardingState
    func createFirstCV(from template: CVModel) async throws -> CVModel
}

public protocol CVManagementUseCaseProtocol: Sendable {
    func getAllCVs() async throws -> [CVModel]
    func createCV(from template: CVModel) async throws -> CVModel
    func updateCV(_ cv: CVModel) async throws -> CVModel
    func deleteCV(id: UUID) async throws
    func duplicateCV(id: UUID) async throws -> CVModel
    func getCV(by id: UUID) async throws -> CVModel?
}

// MARK: - Infrastructure Protocols

public protocol StorageServiceProtocol: Sendable {
    func save<T: Codable & Sendable>(_ object: T, to identifier: String) async throws
    func load<T: Codable & Sendable>(_ type: T.Type, from identifier: String) async throws -> T?
    func loadAll<T: Codable & Sendable>(_ type: T.Type) async throws -> [T]
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
    func makeSampleCVRepository() throws -> SampleCVRepositoryProtocol
    func makeTemplateCategoryService() throws -> TemplateCategoryServiceProtocol
}
import Foundation

// MARK: - Dependency Errors

public enum DependencyError: Error, LocalizedError {
    case serviceCreationFailed(String, Error)
    
    public var errorDescription: String? {
        switch self {
        case .serviceCreationFailed(_, let underlyingError):
            return String(format: String(localized: "error.dependency_failed"), underlyingError.localizedDescription)
        }
    }
}

// MARK: - Dependency Container Implementation

public final class DependencyContainer: DependencyContainerProtocol {
    
    // MARK: - Properties
    
    private let storageDirectory: @Sendable () throws -> URL

    /// The one storage of this container. It is created on first use and shared by every repository, because a
    /// storage serialises the operations on its directory and a second one would bypass that.
    private lazy var storageServiceResult: Result<StorageServiceProtocol, Error> = {
        do {
            let service = try FileStorageService(fileManager: .default, baseDirectory: try storageDirectory())
            return .success(service)
        } catch {
            return .failure(error)
        }
    }()
    
    // MARK: - Initialization
    
    /// - Parameter storageDirectory: Resolves the directory that holds the CV files. It is called on the first
    ///   use of the storage, and a failure surfaces as `DependencyError.serviceCreationFailed`.
    public init(storageDirectory: @escaping @Sendable () throws -> URL) {
        self.storageDirectory = storageDirectory
    }

    /// The import of what earlier versions of the app kept of unsaved editor work, over the folder that holds it.
    /// - Parameters:
    ///   - cvs: The CVs the edits go into.
    ///   - recoveredName: The name of the copy made when the stored CV changed after the edits were made on it.
    /// - Throws: AppError if the folder, or the one of its marks, cannot be made
    public static func makeLeftoverEditsImport(
        in directory: URL,
        cvs: CVManagementUseCaseProtocol,
        recoveredName: @escaping @Sendable (CVModel) -> String
    ) throws -> LeftoverEditsImport {
        LeftoverEditsImport(leftovers: try makeUnsavedEditsRepository(in: directory), cvs: cvs, recoveredName: recoveredName)
    }

    /// The edits earlier versions kept, in `directory`, and the marks of those already stored, in `StoredUnsavedEdits`
    /// beside it: a folder of its own, which a folder of edits that cannot be changed does not stop.
    /// - Throws: AppError if either folder cannot be made
    static func makeUnsavedEditsRepository(in directory: URL) throws -> UnsavedEditsRepository {
        let marks = directory.deletingLastPathComponent().appendingPathComponent("StoredUnsavedEdits", isDirectory: true)
        return UnsavedEditsRepository(
            storageService: try FileStorageService(fileManager: .default, baseDirectory: directory),
            marks: try FileStorageService(fileManager: .default, baseDirectory: marks)
        )
    }

    /// `Application Support/PrestoCV/CVs`: the CVs are the app's own data, not documents the user browses.
    public static func defaultStorageDirectory() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("PrestoCV", isDirectory: true)
            .appendingPathComponent("CVs", isDirectory: true)
    }

    /// `Application Support/PrestoCV/UnsavedEdits`, beside the CVs.
    public static func defaultUnsavedEditsDirectory() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("PrestoCV", isDirectory: true)
            .appendingPathComponent("UnsavedEdits", isDirectory: true)
    }
    
    // MARK: - Public Protocol Implementation
    
    public func makeOnboardingUseCase() throws -> OnboardingUseCaseProtocol {
        let onboardingRepo = try getOnboardingRepository()
        let sampleRepo = try getSampleRepository()
        let cvManagementUseCase = try makeCVManagementUseCase()
        return OnboardingUseCase(
            onboardingRepository: onboardingRepo,
            sampleRepository: sampleRepo,
            cvManagementUseCase: cvManagementUseCase
        )
    }
    
    public func makeCVManagementUseCase() throws -> CVManagementUseCaseProtocol {
        let cvRepo = try getCVRepository()
        let sampleRepo = try getSampleRepository()
        return CVManagementUseCase(
            cvRepository: cvRepo,
            sampleRepository: sampleRepo
        )
    }
    
    public func makeSampleCVRepository() throws -> SampleCVRepositoryProtocol {
        return try getSampleRepository()
    }
    
    public func makeTemplateCategoryService() throws -> TemplateCategoryServiceProtocol {
        return TemplateCategoryService()
    }
}

// MARK: - Private Helper Methods

extension DependencyContainer {
    
    // MARK: Service Factory Methods
    
    private func getStorageService() throws -> StorageServiceProtocol {
        switch storageServiceResult {
        case .success(let service):
            return service
        case .failure(let error):
            throw DependencyError.serviceCreationFailed("StorageService", error)
        }
    }
    
    private func getCVRepository() throws -> CVRepositoryProtocol {
        return CVRepository(storageService: try getStorageService(), now: { Date() })
    }
    
    private func getOnboardingRepository() throws -> OnboardingRepositoryProtocol {
        let cvRepository = try getCVRepository()
        return OnboardingRepository(cvRepository: cvRepository)
    }
    
    private func getSampleRepository() throws -> SampleCVRepositoryProtocol {
        let storageService = try getStorageService()
        let categoryService = getTemplateCategoryService()
        let bundleResourceService = getBundleResourceService()
        let templateLoader = getJSONTemplateLoader()
        let parallelSearchService = getParallelSearchService()
        return SampleCVRepository(
            storageService: storageService,
            categoryService: categoryService,
            bundleResourceService: bundleResourceService,
            templateLoader: templateLoader,
            parallelSearchService: parallelSearchService,
            languages: Bundle.main.preferredLocalizations
        )
    }
    
    private func getTemplateCategoryService() -> TemplateCategoryServiceProtocol {
        return TemplateCategoryService()
    }
    
    private func getParallelSearchService() -> ParallelSearchServiceProtocol {
        return ParallelSearchService()
    }
    
    private func getBundleResourceService() -> BundleResourceServiceProtocol {
        return BundleResourceService(bundle: .main)
    }
    
    private func getJSONTemplateLoader() -> JSONTemplateLoaderProtocol {
        return JSONTemplateLoader()
    }
}
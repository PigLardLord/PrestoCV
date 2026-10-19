import Foundation
@testable import PrestoCVCore

// The production types take every dependency through their initialisers. These tests give the ones they do not vary:
// files in temporary folders on the machine's file system, the machine's clock, and samples in English.

extension CVRepository {
    /// A repository whose saves are dated by the machine's clock
    convenience init(storageService: StorageServiceProtocol) {
        self.init(storageService: storageService, now: { Date() })
    }
}

extension SampleCVRepository {
    /// A repository that reads the samples in English
    convenience init(
        storageService: StorageServiceProtocol,
        categoryService: TemplateCategoryServiceProtocol,
        bundleResourceService: BundleResourceServiceProtocol,
        templateLoader: JSONTemplateLoaderProtocol,
        parallelSearchService: ParallelSearchServiceProtocol
    ) {
        self.init(
            storageService: storageService,
            categoryService: categoryService,
            bundleResourceService: bundleResourceService,
            templateLoader: templateLoader,
            parallelSearchService: parallelSearchService,
            languages: ["en"]
        )
    }
}

extension FileStorageService {
    /// A storage on the machine's file system
    init(baseDirectory: URL) throws {
        try self.init(fileManager: .default, baseDirectory: baseDirectory)
    }
}

extension UnsavedEditsUseCase {
    /// Unsaved edits whose claims get random tokens
    init(repository: UnsavedEditsRepositoryProtocol, now: @escaping @Sendable () -> Date) {
        self.init(repository: repository, now: now, makeToken: { UUID() })
    }
}

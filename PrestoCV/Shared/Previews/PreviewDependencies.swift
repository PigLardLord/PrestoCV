#if DEBUG
import Foundation
import PrestoCVCore

/// What the previews give the screens in place of the stores of the app: CVs, examples and an export choice kept in
/// memory, so that a preview neither reads nor writes the device.
enum PreviewDependencies {
    /// The CVs of a preview, managed as the app manages its own
    static func cvManagement(cvs: [CVModel] = []) -> CVManagementUseCaseProtocol {
        CVManagementUseCase(cvRepository: PreviewCVRepository(cvs: cvs), sampleRepository: PreviewSampleCVRepository())
    }

    /// The examples of a preview
    static let samples: SampleCVRepositoryProtocol = PreviewSampleCVRepository()
}

/// CVs kept in memory, listed by name.
private actor PreviewCVRepository: CVRepositoryProtocol {
    private var cvs: [UUID: CVModel]

    init(cvs: [CVModel]) {
        self.cvs = Dictionary(uniqueKeysWithValues: cvs.map { ($0.id, $0) })
    }

    func getAllCVs() -> [CVModel] {
        cvs.values.sorted { $0.name < $1.name }
    }

    func getCVListing() -> CVListing {
        CVListing(cvs: getAllCVs())
    }

    func acknowledgeUnreadableCVs() {}

    func getCV(by id: UUID) -> CVModel? {
        cvs[id]
    }

    func saveCV(_ cv: CVModel) -> CVModel {
        cvs[cv.id] = cv
        return cv
    }

    func deleteCV(id: UUID) {
        cvs[id] = nil
    }

    func cvExists() -> Bool {
        !cvs.isEmpty
    }

    func getCVsCount() -> Int {
        cvs.count
    }
}

/// Two examples, with a job and a summary each.
private struct PreviewSampleCVRepository: SampleCVRepositoryProtocol {
    private static let samples = [
        CVModel(personalInfo: PersonalInfo(title: "Senior Software Engineer", profile: "Senior engineer with 8+ years of experience.")),
        CVModel(personalInfo: PersonalInfo(title: "Senior UX/UI Designer", profile: "Designer with 7+ years of experience.")),
    ]

    func getDefaultSample() async throws -> CVModel {
        CVModel()
    }

    func getAllSamples() async throws -> [CVModel] {
        Self.samples
    }

    func getSample(by name: String) async throws -> CVModel? {
        nil
    }
}

/// The last export choice, kept in memory.
final class PreviewExportPreferencesStore: ExportPreferencesStore {
    private var preferences = ExportPreferences()

    func load() -> ExportPreferences {
        preferences
    }

    func save(_ preferences: ExportPreferences) {
        self.preferences = preferences
    }
}
#endif

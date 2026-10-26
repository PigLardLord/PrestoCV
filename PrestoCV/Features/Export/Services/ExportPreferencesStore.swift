import Foundation
import CVPDFExporter

/// The design the user chose the last time a PDF was exported: template, color palette and font scheme.
/// It is kept for the whole app, not per CV.
struct ExportPreferences: Codable, Equatable {
    var templateId: String?
    var colorPalette: ColorPalette?
    var fontScheme: FontScheme?
}

/// Where the last export choice is kept between launches.
protocol ExportPreferencesStore {
    /// The stored choice, or an empty one when nothing usable is stored.
    func load() -> ExportPreferences
    func save(_ preferences: ExportPreferences) throws
}

/// Keeps the choice in a small JSON file in Application Support.
/// It is a file and not `UserDefaults`, which would require a privacy manifest entry for its required-reason API.
struct FileExportPreferencesStore: ExportPreferencesStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() -> ExportPreferences {
        // A missing or damaged file only means the user has not chosen yet; the next export writes a fresh one.
        guard let data = try? Data(contentsOf: fileURL),
              let preferences = try? JSONDecoder().decode(ExportPreferences.self, from: data) else {
            return ExportPreferences()
        }
        return preferences
    }

    func save(_ preferences: ExportPreferences) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(preferences).write(to: fileURL, options: .atomic)
    }
}

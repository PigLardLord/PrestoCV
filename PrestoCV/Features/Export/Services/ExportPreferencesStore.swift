import Foundation
import CVPDFExporter

/// The design the user chose the last time a PDF was exported by a version that kept one choice for the whole app:
/// template, color palette and font scheme.
///
/// Since CVs keep their own look (`CVLook`), nothing writes this any more. The choice stays on the device of whoever
/// has it, read once as the look of a CV that has none (`ExportLookResolver`). Delete it, with its file, once no
/// installed version has CVs without a look.
struct ExportPreferences: Codable, Equatable {
    var templateId: String?
    var colorPalette: ColorPalette?
    var fontScheme: FontScheme?
}

/// Where the last choice of an earlier version is read from. It is read-only.
protocol ExportPreferencesStore {
    /// The stored choice, or an empty one when nothing usable is stored.
    func load() -> ExportPreferences
}

/// Reads the choice from the small JSON file that earlier versions wrote in Application Support.
struct FileExportPreferencesStore: ExportPreferencesStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() -> ExportPreferences {
        // A missing or damaged file only means no choice was made before CVs kept their own look.
        guard let data = try? Data(contentsOf: fileURL),
              let preferences = try? JSONDecoder().decode(ExportPreferences.self, from: data) else {
            return ExportPreferences()
        }
        return preferences
    }
}

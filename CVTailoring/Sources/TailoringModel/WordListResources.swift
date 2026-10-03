import Foundation

/// The word-list files, as resources of this package (ADR 0013, R13). A package reads its own resources through
/// `Bundle.module` (R2), and a server image ships the resource bundle beside its binary.
enum WordListResources {
    /// The directory the files are in, inside the package's resource bundle.
    static func directory() -> URL? {
        Bundle.module.url(forResource: "Resources/WordLists", withExtension: nil)
    }

    /// The bytes of a file by its name without extension, or nil when the package has no file by that name. A file that
    /// exists and cannot be read is an error, and so is a package without the directory (R7).
    static func data(named name: String, as file: WordListFile) throws(TailoringModelError) -> Data? {
        guard let url = directory()?.appendingPathComponent(name).appendingPathExtension("json") else { throw .corruptWordList(file) }
        do {
            return try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        } catch {
            throw .corruptWordList(file)
        }
    }
}

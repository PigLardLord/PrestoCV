import Foundation

/// The word-list files, as resources of this package (ADR 0013, R13). A package reads its own resources through
/// `Bundle.module` (R2), and a server image ships the resource bundle beside its binary.
enum WordListResources {
    /// The directory the files are in, inside the package's resource bundle.
    static func directory() -> URL? {
        Bundle.module.url(forResource: "Resources/WordLists", withExtension: nil)
    }

    /// The bytes of a file by its name without extension. A file the package does not have, or cannot read, is an error
    /// (R7), and so is a package without the directory.
    static func data(named name: String, as file: WordListFile) throws(TailoringModelError) -> Data {
        guard let url = directory()?.appendingPathComponent(name).appendingPathExtension("json") else { throw .corruptWordList(file, nil) }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw .corruptWordList(file, nil)
        }
    }
}

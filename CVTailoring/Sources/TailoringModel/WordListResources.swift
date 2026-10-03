import Foundation

/// The word-list files, as resources of this package (ADR 0013, R13). A package reads its own resources through
/// `Bundle.module` (R2), and a server image ships the resource bundle beside its binary.
enum WordListResources {
    /// The file of this package's resources with that name, without its extension: `index`, or a language's code. Each is
    /// looked up by its own name, so a file that is not in the resource bundle is nil.
    static func url(named name: String) -> URL? {
        Bundle.module.url(forResource: "Resources/WordLists/\(name)", withExtension: "json")
    }

    /// The bytes of a file by its name without extension. A file the package does not have, or cannot read, is an error
    /// (R7).
    static func data(named name: String, as file: WordListFile) throws(TailoringModelError) -> Data {
        guard let url = url(named: name) else { throw .corruptWordList(file, nil) }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw .corruptWordList(file, nil)
        }
    }
}

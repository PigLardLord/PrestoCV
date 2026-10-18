import Testing
import Foundation

/// The accent of the app is the brand's Mint from the asset catalog: no colour of the app's code is the system's blue.
@Suite("Accent colour - the Mint of the brand, in the code of the app")
struct AccentColorTests {

    // MARK: - Source

    @Test("No colour of the app is hard-coded to the system blue, purple or indigo: the brand's colour is the Mint of the asset catalog")
    func noColourIsHardCodedToBlueOrPurple() throws {
        let hue = try NSRegularExpression(pattern: #"\.(system)?(blue|purple|indigo|Blue|Purple|Indigo)\b"#)
        let files = try RepositorySources.swiftFiles(in: "PrestoCV")
        try #require(!files.isEmpty, "The sources of the app are in the repository")

        let offending = files.flatMap { file in
            file.text.components(separatedBy: .newlines).enumerated()
                .filter { _, line in hue.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil }
                .map { index, line in "\(file.path):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))" }
        }
        #expect(offending.isEmpty, "\(offending.joined(separator: "\n"))")
    }
}

// MARK: - Helpers

/// The files of the repository.
enum RepositorySources {
    struct File {
        let path: String
        let text: String
    }

    private static let root = Repository.root

    /// The Swift files under a folder of the repository.
    static func swiftFiles(in folder: String) throws -> [File] {
        guard let enumerator = FileManager.default.enumerator(at: root.appendingPathComponent(folder), includingPropertiesForKeys: nil) else {
            return []
        }
        var files: [File] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            files.append(File(path: String(url.path.dropFirst(root.path.count + 1)), text: try String(contentsOf: url, encoding: .utf8)))
        }
        return files.sorted { $0.path < $1.path }
    }
}

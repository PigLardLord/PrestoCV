import Foundation
import Testing

/// The repository the checks read: this file is Tools/SourceChecks/Tests/SourceChecksTests/Repository.swift.
enum Repository {
    static let root = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
}

@Suite("The repository the source checks read")
struct RepositoryTests {

    /// A scan of a folder that is not there finds nothing wrong, so a wrong root would pass the scans without checking anything.
    @Test("The root holds the app's project, its catalog and the folders whose code ships", arguments: [
        "PrestoCV.xcodeproj/project.xcproj", "PrestoCV/Localizable.xcstrings", "PrestoCV/PrivacyInfo.xcprivacy",
        "PrestoCV/Features", "PrestoCVCore/Sources/PrestoCVCore", "CVPDFExporter/Sources/CVPDFExporter",
        "CVGeneratorAI/Sources/CVGeneratorAI",
    ])
    func rootIsTheRepository(path: String) {
        #expect(FileManager.default.fileExists(atPath: Repository.root.appendingPathComponent(path).path), "\(path) is not under \(Repository.root.path)")
    }
}

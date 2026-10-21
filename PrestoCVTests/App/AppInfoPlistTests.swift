import Foundation
import Testing
@testable import PrestoCV

/// `Tools/Release/check-archive.sh` enforces the same rule on the archive before it is uploaded: change both together.
@Suite("App Info.plist Tests")
struct AppInfoPlistTests {

    private let appBundle = Bundle(for: AppRouter.self)

    @Test("Info.plist declares PDFs only, as a viewer of alternate rank, so that \"Open in PrestoCV\" offers the import")
    func infoPlistOpensPDFs() throws {
        let types = try #require(appBundle.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]])

        #expect(types.count == 1)
        #expect(types.first?["LSItemContentTypes"] as? [String] == ["com.adobe.pdf"])
        #expect(types.first?["LSHandlerRank"] as? String == "Alternate", "PrestoCV is no default reader of PDFs")
        #expect(types.first?["CFBundleTypeRole"] as? String == "Viewer")
    }

    @Test("A PDF opened in the app is copied for it, never opened in place")
    func pdfsAreCopied() {
        #expect(appBundle.object(forInfoDictionaryKey: "LSSupportsOpeningDocumentsInPlace") as? Bool == false)
    }

    @Test("Info.plist declares no type of its own", arguments: ["UTExportedTypeDeclarations", "UTImportedTypeDeclarations"])
    func infoPlistDeclaresNoTypes(key: String) {
        #expect(appBundle.object(forInfoDictionaryKey: key) == nil)
    }
}

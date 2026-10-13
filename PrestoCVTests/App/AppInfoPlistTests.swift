import Foundation
import Testing
@testable import PrestoCV

@Suite("App Info.plist Tests")
struct AppInfoPlistTests {

    @Test(
        "Info.plist declares no document types, since the app has no import",
        arguments: [
            "CFBundleDocumentTypes",
            "UTExportedTypeDeclarations",
            "UTImportedTypeDeclarations",
            "LSSupportsOpeningDocumentsInPlace"
        ]
    )
    func infoPlistDeclaresNoDocumentTypes(key: String) {
        let appBundle = Bundle(for: AppRouter.self)

        #expect(appBundle.object(forInfoDictionaryKey: key) == nil)
    }
}

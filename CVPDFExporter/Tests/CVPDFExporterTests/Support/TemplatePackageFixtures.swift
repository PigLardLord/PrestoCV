import Foundation
@testable import CVPDFExporter

/// Template packages for tests
enum TemplatePackageFixtures {

    static func makePackage(
        id: String,
        name: String,
        version: String = "1.0.0",
        css: String = "body { margin: 0; }",
        preview: Data? = nil
    ) -> TemplatePackage {
        let manifest = TemplateManifest(
            id: id,
            name: name,
            description: "Test template",
            author: "Test Author",
            version: version,
            previewImage: "preview.png",
            price: 0.0
        )
        return TemplatePackage(
            manifest: manifest,
            cssContent: css,
            htmlContent: nil,
            previewImageBase64: preview?.base64EncodedString()
        )
    }

    /// A tiny image that starts with the PNG signature; the variant makes two previews differ
    static func makePNG(variant: UInt8) -> Data {
        Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, variant])
    }
}

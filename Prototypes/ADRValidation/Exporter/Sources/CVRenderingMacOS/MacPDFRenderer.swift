#if os(macOS)
import AppKit
import CVRendering
import CVRenderingWebKitSupport

/// Not implemented in the prototype: there is no Apple toolchain on the machine that built it.
public enum RenderingUnavailable: Error { case notImplementedInPrototype }

public struct MacPDFRenderer: PDFRendering {
    public init() {}
    public func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        throw RenderingUnavailable.notImplementedInPrototype
    }
}
#endif

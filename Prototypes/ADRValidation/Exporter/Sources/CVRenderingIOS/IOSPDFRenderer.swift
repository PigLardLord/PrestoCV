#if os(iOS)
import UIKit
import CVRendering
import CVRenderingWebKitSupport

/// iOS adapter (ADR 0003). The whole file is platform-guarded so the package still builds on Linux.
/// Not implemented in the prototype: there is no Apple toolchain on the machine that built it.
public enum RenderingUnavailable: Error { case notImplementedInPrototype }

public struct IOSPDFRenderer: PDFRendering {
    public init() {}
    public func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        throw RenderingUnavailable.notImplementedInPrototype
    }
}
#endif

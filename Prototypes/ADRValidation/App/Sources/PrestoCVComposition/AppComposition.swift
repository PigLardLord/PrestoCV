#if os(iOS) || os(macOS)
import Foundation
import PrestoCVIntegration
import PrestoCVPresentation
import PrestoCVPersistence
import PrestoCVApplication
import CVRendering
#if os(iOS)
import CVRenderingIOS
#elseif os(macOS)
import CVRenderingMacOS
#endif

/// The single composition root (ADR 0008). The renderer is picked per platform through
/// conditional target dependencies; this is one of the places R11 allows a platform check.
@MainActor
public final class AppComposition {
    let repository: FileCVRepository
    let renderer: any PDFRendering

    /// Created exactly once, by the @main App type (a `static let` there is the only process-wide instance).
    public init(applicationSupport: URL, clock: any TimeSource) {
        repository = FileCVRepository(directory: applicationSupport.appendingPathComponent("CVs"), clock: clock)
        #if os(iOS)
        renderer = IOSPDFRenderer()
        #else
        renderer = MacPDFRenderer()
        #endif
    }
}
#endif

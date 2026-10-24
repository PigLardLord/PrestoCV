import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter

/// Prints a CV with the real renderer once per design and way of fitting, and keeps the layout of the PDF for the
/// suites that read it back. A suite asks for the same CV many times; printing is what takes the time.
actor RenderedLayouts {

    /// How the renderer treats a CV of two pages
    enum Fit: String, Sendable {
        /// The renderer the app uses
        case standard
        /// A renderer that prints the CV as its design lays it out
        case disabled
        /// A renderer with only the first step, which tightens the spacing a little: the renderer before the compact step
        case tighteningOnly

        var onePageFit: OnePageFit {
            switch self {
            case .standard: OnePageFit()
            case .disabled: .disabled
            case .tighteningOnly: OnePageFit(steps: Array(OnePageFit.standardSteps.prefix(1)))
            }
        }
    }

    static let shared = RenderedLayouts()

    private var layouts: [String: PDFLayout] = [:]

    /// The layout of the PDF of `cv` in `design`, with the options of the export sheet. `label` names the CV, and must name
    /// one CV only.
    func layout(label: String, cv: CVModel, design: String, fit: Fit = .standard) async throws -> PDFLayout {
        let key = "\(label)/\(design)/\(fit.rawValue)"
        if let known = layouts[key] { return known }

        let environment = try await ExportTestEnvironment.make()
        defer { environment.cleanUp() }
        let service = environment.makeService(onePageFit: fit.onePageFit)
        let options = await environment.exportOptions(for: design)
        let exported = try await service.export(cv: cv, templateId: design, options: options)

        let margins = (top: CGFloat(options.margins.top), left: CGFloat(options.margins.left),
                       bottom: CGFloat(options.margins.bottom), right: CGFloat(options.margins.right))
        guard let layout = PDFLayout(pdf: exported.url, margins: margins), layout.pageCount == exported.pageCount else {
            throw RenderedLayoutError.unreadable(key)
        }
        layouts[key] = layout
        return layout
    }

    enum RenderedLayoutError: Error { case unreadable(String) }
}

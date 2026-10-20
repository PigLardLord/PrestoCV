import Foundation
import CVPDFExporter

/// The message the user reads when loading the templates, making the preview or exporting the PDF fails.
/// It says what to do about it; the error's own description is for developers, in English, and never shown.
enum ExportErrorMessage {

    /// What the app was doing when the error happened, which decides the message for errors it cannot name
    enum Activity {
        case loadingTemplates
        case creatingPreview
        case exporting
    }

    static func message(for error: Error, during activity: Activity) -> String {
        switch error {
        case PDFExportError.tooManyPages(let count, let limit):
            return String(format: String(localized: "export.error.too_many_pages"), count, limit)
        case PDFExportError.invalidContent:
            return String(localized: "export.readiness.name_required")
        case PDFExportError.templateError, TemplateError.templateNotFound, TemplateError.invalidTemplate:
            return String(localized: "export.error.template_unavailable")
        default:
            return message(for: activity)
        }
    }

    private static func message(for activity: Activity) -> String {
        switch activity {
        case .loadingTemplates:
            return String(localized: "export.error.no_templates")
        case .creatingPreview:
            return String(localized: "export.error.preview_failed")
        case .exporting:
            return String(localized: "export.error.failed")
        }
    }
}

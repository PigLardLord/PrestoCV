import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter

@Suite("ExportErrorMessage Tests")
struct ExportErrorMessageTests {

    private struct UnexpectedError: Error, LocalizedError {
        var errorDescription: String? { "Technical detail that users must not see" }
    }

    // MARK: - Named errors

    @Test("too many pages says how many pages the CV needs and what the limit is")
    func tooManyPagesNamesBothNumbers() {
        let message = ExportErrorMessage.message(
            for: PDFExportError.tooManyPages(count: 12, limit: 10),
            during: .exporting
        )

        #expect(message == String(format: String(localized: "export.error.too_many_pages"), 12, 10))
        #expect(message.contains("12"))
        #expect(message.contains("10"))
    }

    @Test("a document without name or email asks the user to add them")
    func invalidContentAsksForNameAndEmail() {
        let message = ExportErrorMessage.message(
            for: PDFExportError.invalidContent("Document must have an email"),
            during: .exporting
        )

        #expect(message == String(localized: "export.error.missing_name_email"))
    }

    @Test("a template that cannot be used says so, whatever the activity",
          arguments: [ExportErrorMessage.Activity.loadingTemplates, .creatingPreview, .exporting])
    func templateErrorsSayTheTemplateIsUnavailable(activity: ExportErrorMessage.Activity) {
        let errors: [Error] = [
            TemplateError.templateNotFound("modern"),
            TemplateError.invalidTemplate("broken"),
            PDFExportError.templateError("broken")
        ]

        for error in errors {
            #expect(ExportErrorMessage.message(for: error, during: activity) == String(localized: "export.error.template_unavailable"))
        }
    }

    // MARK: - Other errors

    @Test("an error nobody foresaw is described by what the app was doing, never by its own text")
    func unknownErrorsUseTheActivity() {
        let error = UnexpectedError()

        #expect(ExportErrorMessage.message(for: error, during: .loadingTemplates) == String(localized: "export.error.no_templates"))
        #expect(ExportErrorMessage.message(for: error, during: .creatingPreview) == String(localized: "export.error.preview_failed"))
        #expect(ExportErrorMessage.message(for: error, during: .exporting) == String(localized: "export.error.failed"))
    }

    @Test("a rendering failure does not show the renderer's English description")
    func renderingFailureIsNotShownRaw() {
        let error = PDFExportError.renderingFailed("WKErrorDomain code 4")

        let message = ExportErrorMessage.message(for: error, during: .exporting)

        #expect(!message.contains("WKErrorDomain"))
        #expect(message == String(localized: "export.error.failed"))
    }
}

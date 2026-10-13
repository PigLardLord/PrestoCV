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

    // MARK: - Catalog

    @Test("every message exists in the six languages, and the translations differ from the English text")
    func catalogHasTheMessagesInAllLanguages() throws {
        let catalogURL = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("PrestoCV/Localizable.xcstrings")
        let catalog = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        )
        let strings = try #require(catalog["strings"] as? [String: Any])
        let keys = [
            "export.error.too_many_pages", "export.error.missing_name_email", "export.error.template_unavailable",
            "export.error.failed", "export.error.preview_failed", "export.error.no_templates"
        ]

        for key in keys {
            let entry = try #require(strings[key] as? [String: Any], "\(key) is missing")
            let localizations = try #require(entry["localizations"] as? [String: [String: Any]])
            #expect(Set(localizations.keys) == ["de", "en", "es", "fr", "it", "pt"], "\(key) languages")

            let values = localizations.mapValues { ($0["stringUnit"] as? [String: Any])?["value"] as? String ?? "" }
            let english = try #require(values["en"])
            for (language, value) in values {
                #expect(!value.isEmpty, "\(key) in \(language) is empty")
                if language != "en" {
                    #expect(value != english, "\(key) in \(language) is still the English text")
                }
            }
            if key == "export.error.too_many_pages" {
                for (language, value) in values {
                    #expect(value.contains("%1$d") && value.contains("%2$d"), "\(key) in \(language) needs both numbers")
                }
            }
        }
    }
}

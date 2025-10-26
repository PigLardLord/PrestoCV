import Foundation
import PrestoCVCore
import CVPDFExporter

/// Converter that transforms a Template from CVPDFExporter into a CVModel
/// Follows Single Responsibility Principle - only handles template-to-model conversion
struct TemplateToCVModelConverter {

    /// Converts a Template into an empty CVModel ready for editing
    /// - Parameter template: The template to convert
    /// - Returns: A new CVModel with the template's name and empty content
    func convert(template: Template) -> CVModel {
        return CVModel(
            id: UUID(),
            name: template.name
        )
    }
}

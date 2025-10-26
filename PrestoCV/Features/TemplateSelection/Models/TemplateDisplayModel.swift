import Foundation
import CVPDFExporter

/// Display model for presenting templates in the UI
/// Separates presentation concerns from domain model (Template)
struct TemplateDisplayModel: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let previewURL: URL?
    let isPremium: Bool

    /// The underlying Template domain object
    /// Stored to enable conversion to CVModel during navigation
    let template: Template

    /// Initialize from a Template domain model
    init(from template: Template) {
        self.id = template.id
        self.name = template.name
        self.description = template.description
        self.previewURL = template.thumbnailURL
        self.isPremium = template.isPremium
        self.template = template
    }

    /// Whether this template has a valid preview image URL
    var hasValidPreview: Bool {
        previewURL != nil
    }
}

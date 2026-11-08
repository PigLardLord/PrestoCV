import Foundation

/// The person's text in the editor's form, as they typed it. The view model reads it into a CV when it stores or exports
/// it; the form keeps the text as typed, spaces and half-written addresses included.
///
/// This step holds the title and the personal details. The sections stay in the CV the editor opened, unchanged, until
/// their rows are in the form.
public struct EditorContent: Hashable, Sendable {
    public var title: String
    public var fullName: String
    public var professionalTitle: String
    public var email: String
    public var phone: String
    public var location: String
    public var website: String
    public var summary: String
}

/// A look of the document, by the ids of its design, palette and fonts.
public struct EditorLook: Hashable, Sendable {
    public let design: String
    public let palette: String?
    public let fonts: String?

    public init(design: String, palette: String?, fonts: String?) {
        self.design = design
        self.palette = palette
        self.fonts = fonts
    }
}

/// A part of a look the person chose in the look picker.
public enum LookPart: Hashable, Sendable, CaseIterable {
    case design, palette, fonts
}

/// The PDF an export made, for the share sheet.
public struct ExportedDocument: Hashable, Sendable {
    public let pdf: Data
    public let pages: Int
}

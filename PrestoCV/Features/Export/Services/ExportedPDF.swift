import Foundation

/// A PDF that is rendered and written to disk, with what the export sheet shows about it.
struct ExportedPDF: Equatable, Sendable, Identifiable {
    let url: URL
    let pageCount: Int
    /// The first page as a PNG, for the preview of the share sheet; nil when the PDF could not be drawn
    let thumbnail: Data?

    /// A file is one PDF: the viewer that shows it is presented by it
    var id: URL { url }

    /// The name the recipient will see
    var fileName: String { url.lastPathComponent }
}

import CVDocumentModel
import CVRendering

/// The links of a document that the exporter would not print as they are. The domain and the exporter each have a rule
/// for a link; the exporter's builder silently leaves out one it refuses, so the workflow looks first and fails visibly
/// (`ExportFailure.invalidDocument`) rather than hand the person a PDF that lacks a link.
enum DocumentLinks {
    /// The links that are refused or would be printed differently, in document order. Empty when all are printable.
    static func unprintable(in document: CVDocument) -> [String] {
        var links: [String] = document.person.website.map { [$0] } ?? []
        for section in document.sections {
            switch section {
            case .certifications(let items): links += items.compactMap(\.url)
            case .profiles(let items): links += items.map(\.url)
            case .summary, .experience, .education, .skills, .languages, .interests: break
            }
        }
        return links.filter { CVRendering.WebLink($0)?.url != $0 }
    }
}

import Foundation

/// Completeness (ValidatingBoundary, ADR 0011): every text node the builder produced must appear in the PDF, counted
/// occurrence by occurrence. A value that also occurs elsewhere (a skill named in the summary, two
/// identical entries, a date) is required as many times as the document contains it, so removing one
/// occurrence is detected. Case and whitespace are ignored: designs may use text-transform, and PDF text
/// extraction does not preserve spacing.
public enum DocumentCompleteness {
    /// The text nodes the PDF text does not contain. Every node, each occurrence counted, needs its own span of the
    /// PDF text that no other node uses, so a value made of the end of one field and the start of the next ("Greg" +
    /// "Officer" contains "go") cannot stand in for a missing field.
    ///
    /// Spans that start and end where the PDF text breaks (whitespace or a line end) are tried first, and the search
    /// backtracks when a choice leaves another node without a span ("Ann" + "Anna"). A search that exceeds its step
    /// budget counts as incomplete: the check fails closed.
    ///
    /// - Parameters:
    ///   - pdfText: the text extracted from the PDF.
    ///   - textNodes: the text nodes of the document, as `RenderedDocument.textNodes` lists them.
    /// - Returns: the nodes with no span of their own, each text once and in document order; empty when the PDF is complete.
    public static func missing(in pdfText: String, expected textNodes: [String]) -> [String] {
        missing(in: pdfText, expected: textNodes, stepBudget: SpanSearch.defaultStepBudget)
    }

    /// `missing(in:expected:)` with the number of steps the search may take before it gives up and fails closed.
    static func missing(in pdfText: String, expected textNodes: [String], stepBudget: Int) -> [String] {
        let pdf = PDFTextIndex(pdfText)
        let expected = ExpectedTexts(textNodes, in: pdf)
        var search = SpanSearch(expected, pdfLength: pdf.scalars.count, stepBudget: stepBudget)
        if search.placesEveryText() { return [] }
        let unplaced = ShortfallDiagnosis(expected, pdfLength: pdf.scalars.count).unplacedIndices()
        return distinctTexts(of: textNodes, at: unplaced)
    }

    private static func distinctTexts(of textNodes: [String], at indices: Set<Int>) -> [String] {
        var seen = Set<String>(), texts: [String] = []
        for (index, text) in textNodes.enumerated() where indices.contains(index) {
            if seen.insert(text).inserted { texts.append(text) }
        }
        return texts
    }
}

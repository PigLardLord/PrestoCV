import PrestoCVImporting

/// Reads a text given to the AI draft that is already a CV, so that the editor gets the person's own words instead of a
/// draft written from them (ADR 0034).
protocol PastedCVReading: Sendable {
    /// The draft the import reads in `text`, or nil when the text is a free description for the AI draft.
    func read(_ text: String) -> ImportedDraft?
}

/// Reads the text with the import and keeps what it read only when `CVRecognition` says the text is already a CV.
///
/// A text the import refuses (over its limits, or with no letter) or does not recognise is left to the AI draft, which
/// words its own errors: the person never sees an import error for a text they gave to the AI screen.
struct PastedCVIntake: PastedCVReading {
    private let importer: ImportCV
    private let mapper: ImportedCVMapper

    init(importer: ImportCV, mapper: ImportedCVMapper) {
        self.importer = importer
        self.mapper = mapper
    }

    func read(_ text: String) -> ImportedDraft? {
        guard let result = try? importer.importText(text), CVRecognition.isAlreadyACV(result.cv) else { return nil }
        return mapper.map(result)
    }
}

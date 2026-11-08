internal import PrestoCVDomain
import PrestoCVWorkflowPorts

// From the import port's values to the screen's (#396), one to one: each switch names every case (R7).

extension ImportedDraft {
    /// The CV goes into the draft as it is; the review keeps the import's order and the person's words.
    init(_ outcome: ImportOutcome, from source: ImportSource) {
        let saving: SaveStatus? = switch outcome.saving {
        case .ok: nil
        case .notEnoughContent, .textTooLong, .tooManyEntries, .cvTooLarge: SaveStatus(waiting: outcome.saving)
        }
        self.init(start: .draft(CVDraft(cv: outcome.cv)),
                  review: ImportReview(entries: outcome.review.map(ReviewEntry.init), notImported: outcome.notImported,
                                       source: source),
                  saving: saving)
    }
}

extension ImportProblem {
    init(_ failure: ImportFailure) {
        switch failure {
        case .empty: self = .empty
        case .tooLarge: self = .tooLarge
        case .tooManyPages: self = .tooManyPages
        case .encrypted: self = .encrypted
        case .unreadable: self = .unreadable
        case .noText: self = .noText
        case .fileNotRead: self = .fileNotRead
        }
    }
}

extension ReviewEntry {
    init(_ item: ImportReviewItem) {
        self.init(field: ReviewedField(item.field), reason: ReviewReason(item.reason), text: item.text)
    }
}

extension ReviewedField {
    init(_ field: ImportReviewField) {
        switch field {
        case .name: self = .name
        case .title: self = .title
        case .location: self = .location
        case .summary: self = .summary
        case .experience(let entry): self = .experience(entry)
        case .experiencePeriod(let entry): self = .experiencePeriod(entry)
        case .education(let entry): self = .education(entry)
        case .educationPeriod(let entry): self = .educationPeriod(entry)
        case .educationLocation(let entry): self = .educationLocation(entry)
        case .language(let entry): self = .language(entry)
        case .languageNotKept(let entry): self = .languageNotKept(entry)
        case .certificationYear(let entry): self = .certificationYear(entry)
        }
    }
}

extension ReviewReason {
    init(_ reason: ImportReviewReason) {
        switch reason {
        case .nameByPosition: self = .nameByPosition
        case .titleByPosition: self = .titleByPosition
        case .locationByPosition: self = .locationByPosition
        case .summaryWithoutHeading: self = .summaryWithoutHeading
        case .roleOrEmployerByOrder: self = .roleOrEmployerByOrder
        case .entryBoundsUnsure: self = .entryBoundsUnsure
        case .periodUnreadable: self = .periodUnreadable
        case .periodOpenEnd: self = .periodOpenEnd
        case .periodNotARange: self = .periodNotARange
        case .levelNotCEFR: self = .levelNotCEFR
        case .levelsDiffer: self = .levelsDiffer
        case .levelMissing: self = .levelMissing
        case .locationNotKept: self = .locationNotKept
        case .yearUnreadable: self = .yearUnreadable
        }
    }
}

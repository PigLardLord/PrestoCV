import PrestoCVPresentation
import SwiftUI

// The words of an import's review (R13): the review gives codes, and each switch lists every one, so that a new code has
// no screen until it has words.

extension ReviewNoticeKind {
    /// What the notice says: that the CV was imported, and what the review holds. It names no source, since a PDF was
    /// never the person's text (#310).
    var words: LocalizedStringResource {
        switch self {
        case .checkAndCopy: "import.notice.checkAndCopy"
        case .checkOnly: "import.notice.checkOnly"
        case .copyOnly: "import.notice.copyOnly"
        }
    }
}

extension ReviewedField {
    /// Where the value is, with the entry's number as the person counts the entries on the screen.
    var label: LocalizedStringResource {
        switch self {
        case .name: "import.review.field.name"
        case .title: "import.review.field.title"
        case .location: "import.review.field.location"
        case .summary: "import.review.field.summary"
        case .experience(let entry): "import.review.field.experience \(entry)"
        case .experiencePeriod(let entry): "import.review.field.experiencePeriod \(entry)"
        case .education(let entry): "import.review.field.education \(entry)"
        case .educationPeriod(let entry): "import.review.field.educationPeriod \(entry)"
        case .educationLocation(let entry): "import.review.field.educationLocation \(entry)"
        case .language(let entry): "import.review.field.language \(entry)"
        case .languageNotKept(let entry): "import.review.field.languageNotKept \(entry)"
        case .certificationYear(let entry): "import.review.field.certificationYear \(entry)"
        }
    }
}

extension ReviewReason {
    /// Why the person should check the value, and what to do when the draft does not hold it.
    var words: LocalizedStringResource {
        switch self {
        // The three were each taken from where they stand in the text, and are checked the same way
        case .nameByPosition, .titleByPosition, .locationByPosition: "import.review.reason.position"
        case .summaryWithoutHeading: "import.review.reason.summaryWithoutHeading"
        case .roleOrEmployerByOrder: "import.review.reason.order"
        case .entryBoundsUnsure: "import.review.reason.bounds"
        case .headingUnsure: "import.review.reason.heading"
        case .periodUnreadable: "import.review.reason.period"
        case .periodOpenEnd: "import.review.reason.periodOpenEnd"
        case .periodNotARange: "import.review.reason.periodNotARange"
        case .levelNotCEFR: "import.review.reason.levelNotCEFR"
        case .levelsDiffer: "import.review.reason.levels"
        case .levelMissing: "import.review.reason.levelMissing"
        case .locationNotKept: "import.review.reason.place"
        case .yearUnreadable: "import.review.reason.year"
        }
    }
}

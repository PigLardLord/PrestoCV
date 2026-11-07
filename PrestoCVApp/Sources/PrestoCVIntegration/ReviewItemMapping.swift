import Foundation
import PrestoCVImporting
import PrestoCVWorkflowPorts

/// The core's review items as the port's (R13: codes, and the person's own text). Entries are counted from one, as the
/// person counts them on the screen; the core counts from zero. No `default:` anywhere: a new reason or field of the core
/// stops the build here.
public enum ReviewItemMapping {
    public static func reason(_ reason: CheckReason) -> ImportReviewReason {
        switch reason {
        case .nameByPosition: .nameByPosition
        case .titleByPosition: .titleByPosition
        case .locationByPosition: .locationByPosition
        case .summaryWithoutHeading: .summaryWithoutHeading
        case .roleOrEmployerByOrder: .roleOrEmployerByOrder
        case .entryBoundsUnsure: .entryBoundsUnsure
        case .periodUnreadable: .periodUnreadable
        case .periodOpenEnd: .periodOpenEnd
        case .levelNotCEFR: .levelNotCEFR
        case .levelsDiffer: .levelsDiffer
        }
    }

    public static func field(_ field: ReviewItem.Field) -> ImportReviewField {
        switch field {
        case .name: .name
        case .title: .title
        case .location: .location
        case .summary: .summary
        case .experience(let index): .experience(index + 1)
        case .experiencePeriod(let index): .experiencePeriod(index + 1)
        case .education(let index): .education(index + 1)
        case .educationPeriod(let index): .educationPeriod(index + 1)
        case .language(let index): .language(index + 1)
        }
    }

    public static func item(_ item: ReviewItem) -> ImportReviewItem {
        ImportReviewItem(field: field(item.field), reason: reason(item.reason), text: item.text)
    }
}

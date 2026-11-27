import PrestoCVPresentation
import SwiftUI

/// The notice above the form while the person's text cannot be stored as it is (#402, decision 8): what to do, and the
/// ways on the status offers (`SaveStatus.statusActions`). The line under the title says where the text stands; when the
/// status changes, VoiceOver hears that line's words and then the notice's, which name the ways on (`spoken(in:)`), so
/// that a person who cannot see the hidden Back button learns how to go on. While a reload or a copy runs, the ways on
/// wait (`isReplacing`). It stands first among the notices above the form, which share one cap (`EditorNotices`).
struct StatusNotice: View {
    let editor: EditorViewModel
    /// Closes the editor without storing its text.
    let discard: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        if editor.saveStatus.blocksLeaving {
            notice
        }
    }

    private var notice: some View {
        InlineNotice(actions: editor.saveStatus.statusActions.map(noticeAction)) {
            WholeWordsText(editor.saveStatus.notice(in: locale))
        }
        .disabled(editor.isReplacing)
        .accessibilityIdentifier("editor.notice")
    }

    private func noticeAction(_ action: StatusAction) -> NoticeAction {
        switch action {
        case .reload:
            NoticeAction("editor.action.reload", actionIdentifier: "editor.notice.reload") {
                Task { await editor.reload() }
            }
        case .saveAsCopy:
            NoticeAction("editor.action.saveAsCopy", actionIdentifier: "editor.notice.saveAsCopy") {
                Task { await editor.saveAsCopy() }
            }
        case .discard:
            NoticeAction("editor.action.discard", actionIdentifier: "editor.notice.discard", perform: discard)
        case .retry:
            NoticeAction("editor.action.retry", actionIdentifier: "editor.notice.retry") {
                Task { await editor.saveNow() }
            }
        }
    }
}

extension SaveStatus {
    /// What the notice says to do, with the field's label in `locale`, the language the screen shows. A text too long
    /// names its field where the form has a label for it; the fields of the sections are named in a later step. A status
    /// that does not block leaving has no notice, and gives its line's words.
    func notice(in locale: Locale) -> LocalizedStringResource {
        switch self {
        case .conflict: "editor.notice.conflict"
        case .deletedElsewhere: "editor.notice.deletedElsewhere"
        case .failed: "editor.notice.failed"
        case .tooLarge: "editor.notice.tooLarge"
        case .textTooLong(let field): Self.textTooLong(field, in: locale)
        case .tooManyEntries: "editor.notice.tooManyEntries"
        case .saved, .pending, .saving, .notEnoughContent, .unreadable: words
        }
    }

    /// What VoiceOver hears when the status changes: the line's words, then, while the person cannot leave, what the
    /// notice says to do.
    func spoken(in locale: Locale) -> [LocalizedStringResource] {
        blocksLeaving ? [words, notice(in: locale)] : [words]
    }

    /// The notice of a text too long, which names the field where the form has a label for it.
    private static func textTooLong(_ field: EditorField, in locale: Locale) -> LocalizedStringResource {
        guard let label = field.formLabel else { return "editor.notice.textTooLong" }
        let name = resolved(label, in: locale)
        return "editor.notice.textTooLong.named \(name)"
    }

    private static func resolved(_ label: LocalizedStringResource, in locale: Locale) -> String {
        var resource = label
        resource.locale = locale
        return String(localized: resource)
    }
}

extension EditorField {
    /// The label the form shows for the field, for the fields of the details; nil for the fields of the sections.
    fileprivate var formLabel: LocalizedStringResource? {
        switch self {
        case .title: "editor.field.title"
        case .fullName: "editor.field.fullName"
        case .professionalTitle: "editor.field.professionalTitle"
        case .email: "editor.field.email"
        case .phone: "editor.field.phone"
        case .location: "editor.field.location"
        case .website: "editor.field.website"
        case .summary: "editor.field.summary"
        case .experienceRole, .experienceCompany, .experienceLocation, .experienceDescription, .experiencePeriod,
             .educationDegree, .educationSchool, .educationDescription, .educationPeriod,
             .skillName, .skillLevel, .language, .languageProficiency,
             .certificationName, .certificationIssuer, .certificationDescription, .certificationIssued,
             .certificationLink, .profilePlatform, .profileLink, .interest:
            nil
        }
    }
}

import PrestoCVPresentation
import SwiftUI

/// The notice above the form while the person's text cannot be stored as it is (#402, decision 8): what to do, and the
/// ways on the status offers (`SaveStatus.statusActions`). The line under the title says where the text stands, and
/// VoiceOver hears that line's words when the status changes; the notice says what to do about it. Where the form is
/// short of room, the notice takes at most a quarter of the editor's height and scrolls inside (`EditorChrome`).
struct StatusNotice: View {
    let editor: EditorViewModel
    /// The editor's height, 0 while it is not known yet.
    let editorHeight: Double
    /// Closes the editor without storing its text.
    let discard: () -> Void
    @Environment(\.isCompactHeight) private var isCompactHeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    /// The notice's own height, which the cap never exceeds.
    @State private var fullHeight: Double = 0

    var body: some View {
        if editor.saveStatus.blocksLeaving {
            placed
        }
    }

    @ViewBuilder
    private var placed: some View {
        let chrome = EditorChrome(isCompactHeight: isCompactHeight, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
        if let height = chrome.noticeHeight(fullHeight: fullHeight, editorHeight: editorHeight) {
            ScrollView { measured }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicatorsFlash(onAppear: true)
                .frame(height: height)
        } else {
            measured
        }
    }

    private var measured: some View {
        notice
            .padding(.horizontal, Spacing.medium)
            .readableWidth()
            .onGeometryChange(for: Double.self) { Double($0.size.height) } action: { fullHeight = $0 }
    }

    private var notice: some View {
        InlineNotice(actions: editor.saveStatus.statusActions.map(noticeAction)) {
            message
        }
        .accessibilityIdentifier("editor.notice")
    }

    /// A text too long names its field where the form has a label for it; the fields of the sections are named in a later
    /// step.
    @ViewBuilder
    private var message: some View {
        if case .textTooLong(let field) = editor.saveStatus, let label = field.formLabel {
            let name = resolved(label)
            WholeWordsText("editor.notice.textTooLong.named \(name)")
        } else {
            WholeWordsText(editor.saveStatus.noticeWords)
        }
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

    /// The label in the language the screen shows, as every other text of it.
    private func resolved(_ label: LocalizedStringResource) -> String {
        var resource = label
        resource.locale = locale
        return String(localized: resource)
    }
}

extension SaveStatus {
    /// What the notice says to do. A status that does not block leaving has no notice.
    fileprivate var noticeWords: LocalizedStringResource {
        switch self {
        case .conflict: "editor.notice.conflict"
        case .deletedElsewhere: "editor.notice.deletedElsewhere"
        case .failed: "editor.notice.failed"
        case .tooLarge: "editor.notice.tooLarge"
        case .textTooLong: "editor.notice.textTooLong"
        case .tooManyEntries: "editor.notice.tooManyEntries"
        case .saved, .pending, .saving, .notEnoughContent, .unreadable: words
        }
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

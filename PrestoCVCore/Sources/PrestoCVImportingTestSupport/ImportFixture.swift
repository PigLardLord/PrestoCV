public import Foundation
public import PrestoCVDomain
public import PrestoCVImporting

/// Builds imports that no reader read, for the tests of what consumes them (the app's mapper and workflow). Every value
/// quotes a piece of one text, as an import's values do, so that its spans point into the document. The text is the
/// fixture's, and every quoted piece is found in it: a piece that is not there is a defect of the test, so it stops.
public struct ImportFixture: Sendable {
    public let text: String
    private let scalars: [Unicode.Scalar]

    public init(text: String) {
        self.text = text
        self.scalars = Array(text.unicodeScalars)
    }

    /// The span of the first occurrence of `piece`, in scalars of the text.
    public func span(_ piece: String) -> SourceSpan {
        let needle = Array(piece.unicodeScalars)
        guard !needle.isEmpty, needle.count <= scalars.count else { preconditionFailure("fixture piece not in the text: \(piece)") }
        for start in 0...(scalars.count - needle.count) where Array(scalars[start..<(start + needle.count)]) == needle {
            return SourceSpan(start, start + needle.count)
        }
        preconditionFailure("fixture piece not in the text: \(piece)")
    }

    /// A value quoted from `piece` of the text.
    public func sourced<Value: Hashable & Sendable>(
        _ value: Value, quoting piece: String, reading: ReadingRule? = nil, check: CheckReason? = nil
    ) -> Sourced<Value> {
        Sourced(value: value, spans: [span(piece)], reading: reading, check: check)
    }

    /// A text value that is its own quote.
    public func quoted(_ piece: String, check: CheckReason? = nil) -> Sourced<String> {
        sourced(piece, quoting: piece, check: check)
    }

    public func link(_ kind: ImportedLink.Kind, _ address: Sourced<WebLink>, heading: String? = nil) -> ImportedLink {
        ImportedLink.scripted(kind, address, heading: heading)
    }

    public func experience(
        role: Sourced<String>? = nil, employer: Sourced<String>? = nil, location: Sourced<String>? = nil,
        period: Sourced<ImportedPeriod>? = nil, details: [Sourced<String>] = [], check: CheckReason? = nil
    ) -> ImportedExperience {
        ImportedExperience.scripted(role: role, employer: employer, location: location, period: period, details: details, check: check)
    }

    public func education(
        degree: Sourced<String>? = nil, school: Sourced<String>? = nil, location: Sourced<String>? = nil,
        period: Sourced<ImportedPeriod>? = nil, details: [Sourced<String>] = [], check: CheckReason? = nil, heading: String? = nil
    ) -> ImportedEducation {
        ImportedEducation.scripted(
            degree: degree, school: school, location: location, period: period, details: details, check: check, heading: heading
        )
    }

    public func language(
        _ name: Sourced<String>, level: Sourced<LanguageProficiency>? = nil, levelWords: Sourced<String>? = nil, heading: String? = nil
    ) -> ImportedLanguage {
        ImportedLanguage.scripted(name, level: level, levelWords: levelWords, heading: heading)
    }

    public func certification(
        _ name: Sourced<String>, issuer: Sourced<String>? = nil, year: Sourced<Int>? = nil, link: Sourced<WebLink>? = nil,
        description: Sourced<String>? = nil
    ) -> ImportedCertification {
        ImportedCertification.scripted(name, issuer: issuer, year: year, link: link, description: description)
    }

    /// Text that fits no field, quoted from `piece`.
    public func unplaced(_ piece: String, section: SectionKind = .unknown, heading: String? = nil) -> UnplacedText {
        UnplacedText.scripted(section: section, heading: heading, text: piece, span: span(piece))
    }

    /// The result of an import of this text that read `cv`.
    public func result(
        _ cv: ImportedCV, language: CVLanguage? = nil, unplaced: [UnplacedText] = [], leftOut: [LeftOutText] = []
    ) -> ImportResult {
        ImportResult(document: SourceDocument(format: .pastedText, text: text, blocks: []), cv: cv, language: language,
                     unplaced: unplaced, leftOut: leftOut)
    }
}

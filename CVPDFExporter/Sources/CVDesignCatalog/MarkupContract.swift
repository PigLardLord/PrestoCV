/// The document markup contract (ADR 0011): the only elements, classes and attributes a design may
/// select. Rendering emits exactly this structure; the catalog validates designs against it.
///
/// A text of several lines (the summary, a description) is one `p` per non-blank line, each with the same class
/// (`cv-summary`, `cv-entry-description`): the person's line breaks are never lost, and no element is added.
///
/// A section's title and its first entry are wrapped in `div.cv-section-start`, which the builder keeps on one page where
/// it fits; an inline section's (skills, profiles, interests) holds the title alone, and its entries follow. The title
/// reserves room for what must follow it, so it is never alone at the foot of a page (#467).
public enum MarkupContract {
    /// Bumped on any change a design could depend on; designs declare the version they target. Version 2 added
    /// `div.cv-section-start`, which changed the nesting (#467).
    public static let version = 2
    public static let elements: Set<String> = ["main", "header", "section", "div", "article", "h1", "h2", "h3", "p", "span", "a"]
    public static let classes: Set<String> = [
        "cv", "cv-header", "cv-name", "cv-title", "cv-contact", "cv-phone", "cv-location", "cv-website",
        "cv-section", "cv-section-start", "cv-section-title", "cv-summary",
        "cv-entry", "cv-entry-title", "cv-entry-subtitle", "cv-entry-location", "cv-entry-period", "cv-entry-description", "cv-entry-link",
        "cv-skill", "cv-language", "cv-language-level", "cv-profile", "cv-profile-platform", "cv-profile-url", "cv-interest",
    ]
    public static let sectionKinds: Set<String> = ["summary", "experience", "education", "skills", "languages", "certifications", "profiles", "interests"]
    public static let ratings: Set<String> = ["1", "2", "3", "4", "5"]
    public static let pseudoClasses: Set<String> = ["first-child", "last-child", "only-child"]

    /// A length a design may not exceed, in the element's em or in pt (px and rem count as pt, at 16px to 1rem).
    public struct Limit: Sendable, Equatable {
        public let em: Double
        public let pt: Double
    }

    /// The most a section's title may set below its last line (#467): its bottom padding and its bottom margin, each up to
    /// `titleBottomSpacing`, and a bottom border up to `borderWidth`, as any border. The builder reserves room for them
    /// under the title; the title stays a block, and a section's start takes no layout and nothing below its children.
    public static let titleBottomSpacing = Limit(em: 1, pt: 12)
    public static let borderWidth = Limit(em: 0.3, pt: 4)
}

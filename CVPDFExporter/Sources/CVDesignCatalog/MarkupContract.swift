/// The document markup contract (ADR 0011): the only elements, classes and attributes a design may
/// select. Rendering emits exactly this structure; the catalog validates designs against it.
///
/// A text of several lines (the summary, a description) is one `p` per non-blank line, each with the same class
/// (`cv-summary`, `cv-entry-description`): the person's line breaks are never lost, and no element is added.
///
/// A section's title and its first entry (all the entries of an inline section: skills, profiles, interests) are wrapped
/// in `div.cv-section-start`, which the builder keeps on one page: a title is never alone at the foot of a page (#467).
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
}

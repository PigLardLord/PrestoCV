/// The document markup contract (ADR 0011): the only elements, classes and attributes a design may
/// select. Rendering emits exactly this structure; the catalog validates designs against it.
public enum MarkupContract {
    /// Bumped on any change a design could depend on; designs declare the version they target.
    public static let version = 1
    public static let elements: Set<String> = ["main", "header", "section", "article", "h1", "h2", "h3", "p", "span", "a"]
    public static let classes: Set<String> = [
        "cv", "cv-header", "cv-name", "cv-title", "cv-contact", "cv-phone", "cv-location", "cv-website",
        "cv-section", "cv-section-title", "cv-summary",
        "cv-entry", "cv-entry-title", "cv-entry-subtitle", "cv-entry-location", "cv-entry-period", "cv-entry-description", "cv-entry-link",
        "cv-skill", "cv-language", "cv-language-level", "cv-profile", "cv-profile-platform", "cv-profile-url", "cv-interest",
    ]
    public static let sectionKinds: Set<String> = ["summary", "experience", "education", "skills", "languages", "certifications", "profiles", "interests"]
    public static let ratings: Set<String> = ["1", "2", "3", "4", "5"]
    public static let pseudoClasses: Set<String> = ["first-child", "last-child", "only-child"]

    /// Whether a design may select `[name=value]`.
    static func allowsAttribute(_ name: String, value: String) -> Bool {
        (name == "data-section" && sectionKinds.contains(value)) || (name == "data-rating" && ratings.contains(value))
    }
}

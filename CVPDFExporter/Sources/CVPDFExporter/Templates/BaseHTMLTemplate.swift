import Foundation

/// Base HTML template with i18n placeholders for localization
///
/// This template provides the complete HTML structure for CV rendering
/// with all section titles as i18n placeholders (e.g., `{{i18n_work_experience}}`).
/// A package without HTML of its own supplies the whole stylesheet, which goes into the `{{customCSS}}`
/// placeholder. The Modern template is such a package.
///
/// Features:
/// - Fully semantic HTML5 structure
/// - i18n-ready section titles
/// - The language of the document in the `lang` attribute
/// - CSS injection point for the stylesheet of the package
/// - Mustache template syntax for data binding
///
/// Usage:
/// ```swift
/// var html = BaseHTMLTemplate.html
/// html = html.replacingOccurrences(of: "{{customCSS}}", with: myCustomCSS)
/// // MustacheTemplateEngine localizes the headings in the language of the document it renders
/// ```
struct BaseHTMLTemplate {
    static let html = """
    <!DOCTYPE html>
    <html lang="{{lang}}">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <title>{{name}} - CV</title>
        <style>
            {{customCSS}}
        </style>
    </head>
    <body>
        <div class="container">
            <!-- Hero Section -->
            <header class="hero-section">
                <div class="hero-content">
                    <div class="hero-text">
                        <h1 class="hero-name">{{name}}</h1>
                        {{#hasTitle}}
                        <h2 class="hero-title">{{title}}</h2>
                        {{/hasTitle}}
                        {{#hasSummary}}
                        <p class="hero-summary">{{summary}}</p>
                        {{/hasSummary}}
                    </div>
                    <div class="hero-sidebar">
                        <div class="contact-card">
                            {{#hasLocation}}
                            <div class="contact-item">
                                <span class="contact-icon">📍</span>
                                <span>{{location}}</span>
                            </div>
                            {{/hasLocation}}
                            {{#email}}
                            <div class="contact-item">
                                <span class="contact-icon">✉️</span>
                                <span>{{email}}</span>
                            </div>
                            {{/email}}
                            {{#hasPhone}}
                            <div class="contact-item">
                                <span class="contact-icon">📱</span>
                                <span>{{phone}}</span>
                            </div>
                            {{/hasPhone}}
                            {{#hasWebsite}}
                            <div class="contact-item">
                                <span class="contact-icon">🌐</span>
                                <span>{{website}}</span>
                            </div>
                            {{/hasWebsite}}
                        </div>
                    </div>
                </div>
            </header>

            <!-- Skills Spotlight -->
            {{#hasSkills}}
            <section class="skills-spotlight">
                <h3 class="spotlight-title">{{i18n_skills}}</h3>
                <div class="skills-showcase">
                    {{#skills}}
                    <div class="skill-badge">
                        <span class="skill-name">{{name}}</span>
                        {{#hasLevel}}
                        <span class="skill-level">{{levelDots}}</span>
                        {{/hasLevel}}
                    </div>
                    {{/skills}}
                </div>
            </section>
            {{/hasSkills}}

            <!-- Main Content Grid -->
            <main class="content-grid">
                <!-- Primary Column -->
                <div class="primary-column">
                    {{#hasWorkExperience}}
                    <section class="experience-section">
                        <h3 class="section-title">
                            <span class="title-accent"></span>
                            <span class="section-title-text">{{i18n_work_experience}}</span>
                        </h3>
                        <div class="experience-content">
                            {{#workExperience}}
                            <div class="job-entry">
                                <div class="job-header">
                                    <span class="job-title">{{title}}</span>
                                    {{#company}}
                                    <span class="job-company"> @ {{company}}</span>
                                    {{/company}}
                                </div>
                                {{#period}}
                                <div class="job-period">{{period}}</div>
                                {{/period}}
                                {{#location}}
                                <div class="job-location">{{location}}</div>
                                {{/location}}
                                {{#description}}
                                <div class="job-description">{{description}}</div>
                                {{/description}}
                            </div>
                            {{/workExperience}}
                        </div>
                    </section>
                    {{/hasWorkExperience}}

                    {{#hasCertifications}}
                    <section class="certifications-section">
                        <h3 class="section-title">
                            <span class="title-accent"></span>
                            <span class="section-title-text">{{i18n_certifications}}</span>
                        </h3>
                        {{#certifications}}
                        <div class="cert-entry">
                            <span class="cert-title">{{title}}</span>
                            {{#issuer}}
                            <span class="cert-issuer"> @ {{issuer}}</span>
                            {{/issuer}}
                            {{#date}}
                            <div class="cert-date">{{date}}</div>
                            {{/date}}
                            {{#url}}
                            <div class="cert-url">{{url}}</div>
                            {{/url}}
                            {{#description}}
                            <span class="cert-description">{{description}}</span>
                            {{/description}}
                        </div>
                        {{/certifications}}
                    </section>
                    {{/hasCertifications}}
                </div>

                <!-- Secondary Column -->
                <div class="secondary-column">
                    {{#hasEducation}}
                    <section class="education-section">
                        <h3 class="section-title">
                            <span class="title-accent"></span>
                            <span class="section-title-text">{{i18n_education}}</span>
                        </h3>
                        <div class="education-content">
                            {{#education}}
                            <div class="edu-entry">
                                <div class="edu-degree">{{degree}}</div>
                                {{#school}}
                                <div class="edu-school">{{school}}</div>
                                {{/school}}
                                {{#period}}
                                <div class="edu-period">{{period}}</div>
                                {{/period}}
                                {{#description}}
                                <div class="edu-description">{{description}}</div>
                                {{/description}}
                            </div>
                            {{/education}}
                        </div>
                    </section>
                    {{/hasEducation}}

                    {{#hasLanguages}}
                    <section class="languages-section">
                        <h3 class="section-title">
                            <span class="title-accent"></span>
                            <span class="section-title-text">{{i18n_languages}}</span>
                        </h3>
                        <ul class="languages-list">
                            {{#languages}}
                            <li><strong>{{language}}</strong>{{#level}} - {{level}}{{/level}}</li>
                            {{/languages}}
                        </ul>
                    </section>
                    {{/hasLanguages}}

                    {{#hasInterests}}
                    <section class="interests-section">
                        <h3 class="section-title">
                            <span class="title-accent"></span>
                            <span class="section-title-text">{{i18n_interests}}</span>
                        </h3>
                        <div class="interests-tags">
                            {{#interests}}
                            <span class="tag">{{.}}</span>
                            {{/interests}}
                        </div>
                    </section>
                    {{/hasInterests}}

                    {{#hasSocialLinks}}
                    <section class="social-section">
                        <h3 class="section-title">
                            <span class="title-accent"></span>
                            <span class="section-title-text">{{i18n_social_links}}</span>
                        </h3>
                        {{#socialLinks}}
                        <div class="social-link">
                            <span class="social-platform">{{platform}}</span>
                            {{#url}}
                            <span class="social-url">{{url}}</span>
                            {{/url}}
                        </div>
                        {{/socialLinks}}
                    </section>
                    {{/hasSocialLinks}}
                </div>
            </main>
        </div>
    </body>
    </html>
    """
}

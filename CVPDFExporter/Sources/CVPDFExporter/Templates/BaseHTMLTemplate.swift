import Foundation

/// Base HTML template with i18n placeholders for localization
///
/// This template provides the complete HTML structure for CV rendering
/// with all section titles as i18n placeholders (e.g., `{{i18n_work_experience}}`).
/// CSS-only templates can inject custom styles via `{{customCSS}}` placeholder.
///
/// Features:
/// - Fully semantic HTML5 structure
/// - Print-optimized with @page rules
/// - i18n-ready section titles
/// - CSS injection point for customization
/// - Mustache template syntax for data binding
///
/// Usage:
/// ```swift
/// var html = BaseHTMLTemplate.html
/// html = html.replacingOccurrences(of: "{{customCSS}}", with: myCustomCSS)
/// let localizer = TemplateLocalizer(locale: .current)
/// html = localizer.localize(template: html)
/// // Then render with MustacheTemplateEngine
/// ```
struct BaseHTMLTemplate {
    static let html = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <title>{{name}} - CV</title>
        <style>
            html {
                -webkit-text-size-adjust: 100%;
                text-size-adjust: 100%;
            }
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
                -webkit-print-color-adjust: exact !important;
                color-adjust: exact !important;
                print-color-adjust: exact !important;
            }

            @page {
                size: A4;
                margin: 0.6in 0.5in;
            }

            body {
                font-family: {{fontBody}};
                font-size: {{fontSize}};
                line-height: 1.3;
                color: {{colorText}};
                background: white;
            }

            .container {
                padding: 0 4pt;
            }

            /* Hero Section */
            .hero-section {
                background: white;
                padding: 0 0 10pt 0;
                margin-bottom: 10pt;
                border-bottom: 2pt solid #e5e7eb;
                page-break-inside: avoid;
            }

            .hero-content {
                display: grid;
                grid-template-columns: 2fr 1fr;
                gap: 12pt;
                align-items: start;
            }

            .hero-text {
                padding-right: 4pt;
            }

            .hero-name {
                font-size: 24pt;
                font-weight: 800;
                color: {{colorPrimary}};
                margin-bottom: 3pt;
                line-height: 1.0;
                letter-spacing: -0.5pt;
            }

            .hero-title {
                font-size: 12pt;
                font-weight: 600;
                color: {{colorSecondary}};
                margin-bottom: 8pt;
                text-transform: uppercase;
                letter-spacing: 0.5pt;
            }

            .hero-summary {
                font-size: 9pt;
                line-height: 1.3;
                color: {{colorText}};
            }

            .hero-sidebar {
                display: flex;
                flex-direction: column;
                gap: 8pt;
            }

            .contact-card {
                background: #f8fafc;
                border: 1pt solid #e5e7eb;
                border-radius: 4pt;
                padding: 8pt;
            }

            .contact-item {
                margin-bottom: 4pt;
                font-size: 8pt;
                color: {{colorText}};
                display: flex;
                align-items: center;
                gap: 4pt;
            }

            .contact-item:last-child {
                margin-bottom: 0;
            }

            .contact-icon {
                font-size: 7pt;
            }

            /* Skills Spotlight */
            .skills-spotlight {
                background: white;
                padding: 8pt 0;
                margin-bottom: 10pt;
                border-bottom: 1pt solid #e5e7eb;
                page-break-inside: avoid;
            }

            .spotlight-title {
                text-align: center;
                font-size: 10pt;
                font-weight: 700;
                color: {{colorText}};
                margin-bottom: 6pt;
                text-transform: uppercase;
                letter-spacing: 0.5pt;
            }

            .skills-showcase {
                display: grid;
                grid-template-columns: repeat(3, 1fr);
                gap: 4pt;
            }

            .skill-badge {
                background: white;
                border: 1pt solid #d1d5db;
                border-radius: 3pt;
                padding: 3pt 5pt;
                display: flex;
                align-items: center;
                justify-content: space-between;
            }

            .skill-name {
                font-weight: 600;
                color: {{colorText}};
                font-size: 8pt;
            }

            .skill-level {
                font-family: monospace;
                font-size: 8pt;
                color: {{colorPrimary}};
                letter-spacing: 0.3pt;
            }

            /* Main Content Grid */
            .content-grid {
                display: grid;
                grid-template-columns: 62% 36%;
                gap: 12pt;
            }

            /* Section Styling */
            section {
                margin-bottom: 12pt;
                page-break-inside: avoid;
            }

            .section-title {
                display: flex;
                align-items: center;
                gap: 4pt;
                margin-bottom: 6pt;
                padding-bottom: 3pt;
                border-bottom: 1pt solid #e5e7eb;
            }

            .title-accent {
                width: 2pt;
                height: 12pt;
                background: {{colorPrimary}};
                border-radius: 1pt;
            }

            .section-title-text {
                font-size: 9pt;
                font-weight: 700;
                color: {{colorText}};
                text-transform: uppercase;
                letter-spacing: 0.25pt;
            }

            /* Experience Section */
            .job-entry {
                border-left: 2pt solid #e5e7eb;
                padding: 6pt 0 6pt 8pt;
                margin-bottom: 8pt;
                page-break-inside: avoid;
            }

            .job-header {
                margin-bottom: 2pt;
            }

            .job-title {
                font-weight: 700;
                color: {{colorPrimary}};
                font-size: 9pt;
            }

            .job-company {
                font-weight: 600;
                color: {{colorText}};
                font-size: 9pt;
            }

            .job-period {
                font-size: 8pt;
                color: {{colorSecondary}};
                font-weight: 500;
                margin-bottom: 4pt;
            }

            .job-location {
                font-size: 8pt;
                color: {{colorSecondary}};
                font-style: italic;
                margin-bottom: 4pt;
            }

            .job-description {
                color: {{colorText}};
                line-height: 1.3;
                font-size: 8pt;
            }

            /* Education Section */
            .edu-entry {
                background: white;
                border: 0.5pt solid #e5e7eb;
                border-radius: 2pt;
                padding: 6pt;
                margin-bottom: 6pt;
                page-break-inside: avoid;
            }

            .edu-degree {
                font-weight: 700;
                color: {{colorPrimary}};
                margin-bottom: 1pt;
                font-size: 8pt;
            }

            .edu-school {
                font-weight: 600;
                color: {{colorText}};
                font-size: 8pt;
            }

            .edu-period {
                color: {{colorSecondary}};
                font-size: 7pt;
                margin-bottom: 3pt;
            }

            .edu-description {
                color: {{colorText}};
                font-size: 7pt;
                line-height: 1.2;
                margin-top: 3pt;
            }

            /* Certifications */
            .cert-entry {
                background: #f8fafc;
                border-radius: 2pt;
                padding: 4pt;
                margin-bottom: 3pt;
                border-left: 2pt solid #3b82f6;
                page-break-inside: avoid;
                font-size: 8pt;
            }

            .cert-title {
                color: {{colorPrimary}};
                font-weight: 700;
            }

            .cert-issuer {
                color: {{colorText}};
                font-weight: 600;
            }

            .cert-date {
                color: {{colorSecondary}};
                font-size: 7pt;
            }

            .cert-description {
                display: block;
                margin-top: 1pt;
                font-size: 7pt;
                color: {{colorText}};
                line-height: 1.2;
            }

            /* Languages */
            .languages-list {
                list-style: none;
            }

            .languages-list li {
                padding: 3pt 0;
                border-bottom: 0.5pt solid #f3f4f6;
                font-size: 8pt;
                color: {{colorText}};
            }

            .languages-list li:last-child {
                border-bottom: none;
            }

            /* Interests */
            .interests-tags {
                display: flex;
                flex-wrap: wrap;
                gap: 2pt;
            }

            .tag {
                background: {{colorBackground}};
                color: {{colorPrimary}};
                padding: 2pt 3pt;
                border-radius: 2pt;
                font-size: 7pt;
                font-weight: 500;
                border: 0.5pt solid {{colorSecondary}};
            }

            /* Social Links */
            .social-link {
                background: #f8fafc;
                border-radius: 2pt;
                padding: 4pt 6pt;
                margin-bottom: 3pt;
                border-left: 2pt solid {{colorPrimary}};
                page-break-inside: avoid;
                font-size: 8pt;
                display: flex;
                flex-direction: column;
                gap: 1pt;
            }

            .social-platform {
                color: {{colorPrimary}};
                font-weight: 700;
                font-size: 8pt;
            }

            .social-url {
                color: {{colorSecondary}};
                font-size: 7pt;
                word-break: break-all;
            }

            /* Page Break Control */
            .hero-section {
                page-break-after: avoid;
            }

            .skills-spotlight {
                page-break-after: avoid;
            }

            .content-grid {
                page-break-before: avoid;
            }

            h1, h2, h3 {
                page-break-after: avoid;
            }

            p, li {
                orphans: 2;
                widows: 2;
            }

            /* Custom CSS Injection Point */
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
                            <div class="contact-item">
                                <span class="contact-icon">✉️</span>
                                <span>{{email}}</span>
                            </div>
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
                    {{#skillList}}
                    <div class="skill-badge">
                        <span class="skill-name">{{name}}</span>
                        {{#hasLevel}}
                        <span class="skill-level">{{levelDots}}</span>
                        {{/hasLevel}}
                    </div>
                    {{/skillList}}
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
                                    <span class="job-company"> @ {{company}}</span>
                                </div>
                                <div class="job-period">{{startDate}}{{#endDate}} - {{endDate}}{{/endDate}}</div>
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
                                <div class="edu-school">{{school}}</div>
                                <div class="edu-period">{{startDate}}{{#endDate}} - {{endDate}}{{/endDate}}</div>
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
                            <li><strong>{{language}}</strong> - {{level}}</li>
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
                            <span class="social-url">{{url}}</span>
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

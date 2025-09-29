import Foundation

/// Modern template HTML content
struct ModernHTMLTemplate {
    static let html = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{{name}} - CV</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }

            :root {
                --color-primary: {{colorPrimary}};
                --color-secondary: {{colorSecondary}};
                --color-accent: {{colorAccent}};
                --color-background: {{colorBackground}};
                --color-text: {{colorText}};
                --color-text-light: #94A3B8;
                --font-heading: {{fontHeading}};
                --font-body: {{fontBody}};
                --font-size: {{fontSize}};
                --spacing-xs: 5pt;
                --spacing-sm: 10pt;
                --spacing-md: 15pt;
                --spacing-lg: 20pt;
                --spacing-xl: 30pt;
            }

            body {
                font-family: var(--font-body);
                font-size: var(--font-size);
                color: var(--color-text);
                background: var(--color-background);
                line-height: 1.7;
            }

            /* Modern gradient header */
            .header {
                background: linear-gradient(135deg, var(--color-primary) 0%, var(--color-accent) 100%);
                color: white;
                padding: var(--spacing-xl) var(--spacing-xl) var(--spacing-lg);
                position: relative;
                overflow: hidden;
            }

            .header::before {
                content: '';
                position: absolute;
                top: -50%;
                right: -50%;
                width: 200%;
                height: 200%;
                background: radial-gradient(circle, rgba(255,255,255,0.1) 0%, transparent 70%);
            }

            .header-content {
                position: relative;
                z-index: 1;
            }

            h1 {
                font-family: var(--font-heading);
                font-size: 28pt;
                font-weight: 300;
                letter-spacing: -0.5pt;
                margin-bottom: var(--spacing-xs);
            }

            .tagline {
                font-size: 12pt;
                opacity: 0.95;
                margin-bottom: var(--spacing-md);
            }

            .contact-grid {
                display: flex;
                flex-wrap: wrap;
                gap: var(--spacing-md);
                font-size: 9pt;
            }

            .contact-item {
                display: flex;
                align-items: center;
                gap: var(--spacing-xs);
            }

            .contact-icon {
                width: 4pt;
                height: 4pt;
                background: white;
                border-radius: 50%;
                opacity: 0.7;
            }

            /* Content sections */
            .content {
                padding: var(--spacing-xl);
                max-width: 800pt;
            }

            .summary {
                background: linear-gradient(90deg, var(--color-background) 0%, rgba(var(--color-primary), 0.05) 100%);
                border-left: 3pt solid var(--color-accent);
                padding: var(--spacing-md);
                margin-bottom: var(--spacing-xl);
                font-style: italic;
                color: var(--color-text);
            }

            .section {
                margin-bottom: var(--spacing-xl);
                page-break-inside: avoid;
            }

            h2 {
                font-family: var(--font-heading);
                color: var(--color-primary);
                font-size: 13pt;
                font-weight: 500;
                letter-spacing: 2pt;
                text-transform: uppercase;
                margin-bottom: var(--spacing-md);
                padding-bottom: var(--spacing-xs);
                border-bottom: 2pt solid var(--color-accent);
            }

            .item {
                margin-bottom: var(--spacing-lg);
                padding-left: var(--spacing-md);
                position: relative;
                page-break-inside: avoid;
            }

            .item::before {
                content: '';
                position: absolute;
                left: 0;
                top: 8pt;
                width: 4pt;
                height: 4pt;
                background: var(--color-accent);
                border-radius: 50%;
            }

            .item-header {
                display: flex;
                justify-content: space-between;
                align-items: baseline;
                margin-bottom: var(--spacing-xs);
            }

            .item-title {
                font-weight: 600;
                color: var(--color-primary);
                font-size: 11pt;
            }

            .item-subtitle {
                color: var(--color-secondary);
                font-weight: 500;
            }

            .item-date {
                color: var(--color-text-light);
                font-size: 9pt;
                font-weight: 300;
            }

            .item-location {
                color: var(--color-text-light);
                font-size: 9pt;
                font-style: italic;
            }

            .item-description {
                margin-top: var(--spacing-xs);
                color: var(--color-text);
                text-align: justify;
            }

            /* Skills section with tags */
            .skills-group {
                margin-bottom: var(--spacing-md);
            }

            .skills-category {
                font-weight: 600;
                color: var(--color-primary);
                margin-bottom: var(--spacing-xs);
            }

            .skills-tags {
                display: flex;
                flex-wrap: wrap;
                gap: var(--spacing-xs);
                margin-top: var(--spacing-xs);
            }

            .skill-tag {
                background: var(--color-secondary);
                color: white;
                padding: 2pt 8pt;
                border-radius: 12pt;
                font-size: 9pt;
                font-weight: 500;
            }

            /* Print styles */
            @media print {
                body {
                    padding: 0;
                }

                .header {
                    background: linear-gradient(135deg, var(--color-primary) 0%, var(--color-accent) 100%) !important;
                    -webkit-print-color-adjust: exact;
                    print-color-adjust: exact;
                }

                .section {
                    page-break-inside: avoid;
                }

                .item {
                    page-break-inside: avoid;
                }
            }
        </style>
    </head>
    <body>
        <header class="header">
            <div class="header-content">
                <h1>{{name}}</h1>
                {{#hasSummary}}
                <p class="tagline">{{summary}}</p>
                {{/hasSummary}}
                <div class="contact-grid">
                    <div class="contact-item">
                        <span class="contact-icon"></span>
                        <span>{{email}}</span>
                    </div>
                    {{#hasPhone}}
                    <div class="contact-item">
                        <span class="contact-icon"></span>
                        <span>{{phone}}</span>
                    </div>
                    {{/hasPhone}}
                    {{#hasLocation}}
                    <div class="contact-item">
                        <span class="contact-icon"></span>
                        <span>{{location}}</span>
                    </div>
                    {{/hasLocation}}
                    {{#hasWebsite}}
                    <div class="contact-item">
                        <span class="contact-icon"></span>
                        <span>{{website}}</span>
                    </div>
                    {{/hasWebsite}}
                </div>
            </div>
        </header>

        <div class="content">
            {{#hasWorkExperience}}
            <section class="section">
                <h2>Experience</h2>
                {{#workExperience}}
                <div class="item">
                    <div class="item-header">
                        <div>
                            <span class="item-title">{{title}}</span>
                            <span class="item-subtitle">@ {{company}}</span>
                        </div>
                        <span class="item-date">{{startDate}} - {{endDate}}</span>
                    </div>
                    {{#location}}
                    <div class="item-location">{{location}}</div>
                    {{/location}}
                    {{#description}}
                    <div class="item-description">{{description}}</div>
                    {{/description}}
                </div>
                {{/workExperience}}
            </section>
            {{/hasWorkExperience}}

            {{#hasEducation}}
            <section class="section">
                <h2>Education</h2>
                {{#education}}
                <div class="item">
                    <div class="item-header">
                        <div>
                            <span class="item-title">{{degree}}</span>
                            <span class="item-subtitle">@ {{school}}</span>
                        </div>
                        <span class="item-date">{{startDate}} - {{endDate}}</span>
                    </div>
                    {{#description}}
                    <div class="item-description">{{description}}</div>
                    {{/description}}
                </div>
                {{/education}}
            </section>
            {{/hasEducation}}

            {{#hasSkills}}
            <section class="section">
                <h2>Skills</h2>
                {{#skills}}
                <div class="skills-group">
                    <div class="skills-category">{{category}}</div>
                    {{#hasSkills}}
                    <div class="skills-tags">
                        {{#skillList}}
                        <span class="skill-tag">{{name}}</span>
                        {{/skillList}}
                    </div>
                    {{/hasSkills}}
                </div>
                {{/skills}}
            </section>
            {{/hasSkills}}

            {{#hasCertifications}}
            <section class="section">
                <h2>Certifications</h2>
                {{#certifications}}
                <div class="item">
                    <div class="item-header">
                        <div>
                            <span class="item-title">{{title}}</span>
                            {{#issuer}}
                            <span class="item-subtitle">@ {{issuer}}</span>
                            {{/issuer}}
                        </div>
                        {{#date}}
                        <span class="item-date">{{date}}</span>
                        {{/date}}
                    </div>
                    {{#description}}
                    <div class="item-description">{{description}}</div>
                    {{/description}}
                </div>
                {{/certifications}}
            </section>
            {{/hasCertifications}}

            {{#hasLanguages}}
            <section class="section">
                <h2>Languages</h2>
                <div class="skills-tags">
                    {{#languages}}
                    <span class="skill-tag">{{language}} - {{level}}</span>
                    {{/languages}}
                </div>
            </section>
            {{/hasLanguages}}
        </div>
    </body>
    </html>
    """
}
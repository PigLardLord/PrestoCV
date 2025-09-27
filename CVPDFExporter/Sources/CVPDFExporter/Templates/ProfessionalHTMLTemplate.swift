import Foundation

/// Professional template HTML content
struct ProfessionalHTMLTemplate {
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
                --color-text-light: #7F8C8D;
                --font-heading: {{fontHeading}};
                --font-body: {{fontBody}};
                --font-size: {{fontSize}};
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
                line-height: 1.6;
                padding: 40pt;
            }

            header {
                border-bottom: 3pt solid var(--color-primary);
                padding-bottom: var(--spacing-lg);
                margin-bottom: var(--spacing-xl);
            }

            h1 {
                font-family: var(--font-heading);
                color: var(--color-primary);
                font-size: 24pt;
                font-weight: 700;
                margin-bottom: 5pt;
            }

            .contact-info {
                color: var(--color-secondary);
                font-size: 9pt;
                margin-top: 5pt;
            }

            .contact-info span {
                display: inline-block;
                margin-right: 15pt;
            }

            .summary {
                margin-bottom: var(--spacing-xl);
                padding: var(--spacing-md);
                background-color: #F8F9FA;
                border-left: 3pt solid var(--color-accent);
            }

            .section {
                margin-bottom: var(--spacing-xl);
                page-break-inside: avoid;
            }

            h2 {
                font-family: var(--font-heading);
                color: var(--color-primary);
                font-size: 14pt;
                font-weight: 600;
                border-bottom: 1pt solid #E0E0E0;
                padding-bottom: 5pt;
                margin-bottom: var(--spacing-md);
                text-transform: uppercase;
            }

            .item {
                margin-bottom: var(--spacing-lg);
                page-break-inside: avoid;
            }

            .item-header {
                display: flex;
                justify-content: space-between;
                margin-bottom: 5pt;
            }

            .item-title {
                font-weight: 600;
                color: var(--color-primary);
            }

            .item-subtitle {
                color: var(--color-accent);
                font-weight: 500;
            }

            .item-date {
                color: var(--color-text-light);
                font-size: 9pt;
                font-style: italic;
            }

            .item-description {
                margin-top: 5pt;
                text-align: justify;
            }

            .skills-group {
                margin-bottom: var(--spacing-md);
            }

            .skills-category {
                font-weight: 600;
                color: var(--color-primary);
                margin-bottom: 5pt;
            }

            .skills-list {
                display: flex;
                flex-wrap: wrap;
                gap: 8pt;
            }

            .skill-tag {
                background-color: #ECF0F1;
                padding: 3pt 8pt;
                border-radius: 3pt;
                font-size: 9pt;
            }

            @media print {
                body {
                    padding: 0;
                }
                .summary {
                    background-color: #F8F9FA !important;
                    -webkit-print-color-adjust: exact;
                    print-color-adjust: exact;
                }
                .skill-tag {
                    background-color: #ECF0F1 !important;
                    -webkit-print-color-adjust: exact;
                    print-color-adjust: exact;
                }
            }
        </style>
    </head>
    <body>
        <header>
            <h1>{{name}}</h1>
            <div class="contact-info">
                <span>{{email}}</span>
                {{#hasPhone}}<span>{{phone}}</span>{{/hasPhone}}
                {{#hasLocation}}<span>{{location}}</span>{{/hasLocation}}
                {{#hasWebsite}}<span>{{website}}</span>{{/hasWebsite}}
            </div>
        </header>

        {{#hasSummary}}
        <section class="summary">
            <p>{{summary}}</p>
        </section>
        {{/hasSummary}}

        {{#hasWorkExperience}}
        <section class="section">
            <h2>Work Experience</h2>
            {{#workExperience}}
            <div class="item">
                <div class="item-header">
                    <div>
                        <span class="item-title">{{title}}</span>
                        <span class="item-subtitle">at {{company}}</span>
                    </div>
                    <span class="item-date">{{startDate}} - {{endDate}}</span>
                </div>
                <div class="item-description">
                    {{description}}
                </div>
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
                    </div>
                    <span class="item-date">{{startDate}} - {{endDate}}</span>
                </div>
                <div class="item-subtitle">{{school}}</div>
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
                <div class="skills-list">
                    {{#skills}}
                    <span class="skill-tag">{{.}}</span>
                    {{/skills}}
                </div>
            </div>
            {{/skills}}
        </section>
        {{/hasSkills}}
    </body>
    </html>
    """
}

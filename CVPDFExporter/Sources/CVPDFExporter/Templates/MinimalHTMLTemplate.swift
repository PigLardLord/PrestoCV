import Foundation

/// Minimal template HTML content
struct MinimalHTMLTemplate {
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
                --font-heading: {{fontHeading}};
                --font-body: {{fontBody}};
                --font-size: {{fontSize}};
                --spacing-xs: 8pt;
                --spacing-sm: 12pt;
                --spacing-md: 20pt;
                --spacing-lg: 30pt;
                --spacing-xl: 40pt;
            }

            body {
                font-family: var(--font-body);
                font-size: var(--font-size);
                color: var(--color-text);
                background: var(--color-background);
                line-height: 1.6;
                max-width: 700pt;
                margin: 0 auto;
                padding: var(--spacing-xl);
            }

            /* Header - Clean and simple */
            header {
                text-align: center;
                margin-bottom: var(--spacing-xl);
                padding-bottom: var(--spacing-md);
                border-bottom: 1pt solid var(--color-text);
            }

            h1 {
                font-family: var(--font-heading);
                font-size: 20pt;
                font-weight: normal;
                letter-spacing: 1pt;
                margin-bottom: var(--spacing-xs);
            }

            .contact-info {
                font-size: 10pt;
                color: var(--color-secondary);
                margin-top: var(--spacing-xs);
            }

            .contact-info span {
                margin: 0 var(--spacing-sm);
            }

            .contact-info span:first-child {
                margin-left: 0;
            }

            .summary {
                font-style: italic;
                text-align: center;
                margin-bottom: var(--spacing-lg);
                padding: 0 var(--spacing-xl);
                color: var(--color-secondary);
            }

            /* Content sections */
            .section {
                margin-bottom: var(--spacing-lg);
                page-break-inside: avoid;
            }

            h2 {
                font-family: var(--font-heading);
                font-size: 12pt;
                font-weight: normal;
                letter-spacing: 0.5pt;
                margin-bottom: var(--spacing-md);
                padding-bottom: var(--spacing-xs);
                border-bottom: 0.5pt solid var(--color-text);
            }

            .item {
                margin-bottom: var(--spacing-md);
                page-break-inside: avoid;
            }

            .item-header {
                display: flex;
                justify-content: space-between;
                align-items: baseline;
                margin-bottom: var(--spacing-xs);
            }

            .item-left {
                flex: 1;
            }

            .item-title {
                font-weight: 600;
                color: var(--color-primary);
            }

            .item-subtitle {
                color: var(--color-secondary);
                font-style: italic;
            }

            .item-date {
                color: var(--color-secondary);
                font-size: 9pt;
                white-space: nowrap;
            }

            .item-description {
                margin-top: var(--spacing-xs);
                text-align: justify;
                hyphens: auto;
            }

            /* Skills - Simple list style */
            .skills-group {
                margin-bottom: var(--spacing-sm);
            }

            .skills-category {
                font-weight: 600;
                color: var(--color-primary);
                display: inline;
            }

            .skills-list {
                display: inline;
                margin-left: var(--spacing-xs);
            }

            .skill {
                display: inline;
                color: var(--color-secondary);
            }

            .skill:after {
                content: ", ";
            }

            .skill:last-child:after {
                content: "";
            }

            /* Print styles */
            @media print {
                body {
                    padding: 0;
                    max-width: 100%;
                }

                .section {
                    page-break-inside: avoid;
                }

                .item {
                    page-break-inside: avoid;
                }

                h2 {
                    page-break-after: avoid;
                }
            }
        </style>
    </head>
    <body>
        <header>
            <h1>{{name}}</h1>
            <div class="contact-info">
                <span>{{email}}</span>
                {{#hasPhone}}
                <span>•</span>
                <span>{{phone}}</span>
                {{/hasPhone}}
                {{#hasLocation}}
                <span>•</span>
                <span>{{location}}</span>
                {{/hasLocation}}
                {{#hasWebsite}}
                <span>•</span>
                <span>{{website}}</span>
                {{/hasWebsite}}
            </div>
        </header>

        {{#hasSummary}}
        <div class="summary">
            {{summary}}
        </div>
        {{/hasSummary}}

        {{#hasWorkExperience}}
        <section class="section">
            <h2>Experience</h2>
            {{#workExperience}}
            <div class="item">
                <div class="item-header">
                    <div class="item-left">
                        <span class="item-title">{{title}}</span>
                        <span class="item-subtitle">— {{company}}</span>
                    </div>
                    <span class="item-date">{{startDate}}–{{endDate}}</span>
                </div>
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
                    <div class="item-left">
                        <span class="item-title">{{degree}}</span>
                        <span class="item-subtitle">— {{school}}</span>
                    </div>
                    <span class="item-date">{{startDate}}–{{endDate}}</span>
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
                <span class="skills-category">{{category}}:</span>
                <span class="skills-list">
                    {{#skills}}
                    {{#.}}
                    <span class="skill">{{.}}</span>
                    {{/.}}
                    {{/skills}}
                </span>
            </div>
            {{/skills}}
        </section>
        {{/hasSkills}}
    </body>
    </html>
    """
}
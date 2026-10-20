# Glossary

One word, one meaning, in code, UI copy, tickets and translations. Today "template" means several different things (a sample CV, a visual design, a file type); that ends here.

| Term | Meaning | Not to be confused with | Context |
|---|---|---|---|
| **CV** | The aggregate the user edits: personal details plus ordered sections of entries. Identified by a `CVID`. | "Resume" (don't use it in copy), "document" | Authoring |
| **CV title** | The user's private label for a CV ("iOS Dev – Apple"). It is never printed. | The person's professional title | Authoring |
| **Professional title** | The role printed under the person's name. | CV title | Authoring |
| **Entry** | One item of a section: an experience, an education, a skill, a language, a certification, a profile link. | — | Authoring |
| **Period** | A structured start (month or year precision) and an end that is a date, "current", or "ended, date unknown". Never free text, never an invented date. | — | Authoring |
| **Sample CV** | Example content a user can start from. | Design (formerly both were called "template") | Authoring |
| **Draft** | A CV proposed by AI Drafting. Not saved until the user reviews and saves it. | Unsaved CV | Drafting → Authoring |
| **Import** | Turning a CV someone already has (pasted text, a text PDF) into a draft by rules, every value quoted from the text. Not saved until the user saves it. | Draft (written by AI) | Import → Authoring |
| **Source document** | `SourceDocument`: the imported text in reading order, with its blocks and, from a PDF, their page, box and style. Every value of an import points to a span of it. | Document (`CVDocument`) | Import |
| **Review list** | The values of an import that the rules are unsure of, each with its reason, for the user to check. | — | Import |
| **Text not imported** | The text of an imported document that fits no field. It is shown to the user, ready to copy, never dropped. | — | Import |
| **Unsaved CV** | A CV created in the editor that has never been saved (revision 0). In code: `NewCV`. | Draft | Authoring |
| **Design** | The visual look of an exported CV: layout, CSS, typography. What the UI calls it. | Sample CV | Design Catalog |
| **Design package** | The `.mcvt` file that carries a design: manifest, CSS, preview image. | — | Design Catalog |
| **Bundled design** | A design package shipped inside `CVBundledDesigns`. | Installed design | Design Catalog |
| **Installed design** | A design package in the design store, bundled or imported. | — | Design Catalog |
| **Palette** / **Font scheme** | Customisations of a design. They get their own names in the UI (colour names, typeface names), never a design's name. | Design | Design Catalog |
| **Design choice** | The design, palette and font a CV uses, stored on the CV. | — | Authoring (as opaque identifiers) |
| **Document** | `CVDocument`: the input of rendering, the published language of `CVPDFExporter`. | CV | Rendering |
| **Document language** | The language a CV is written and printed in. It can differ from the app language. | App language | Authoring, Rendering, Drafting |
| **Preview** | HTML rendered on screen from the same pipeline and policy as the PDF. | — | Rendering |
| **Render policy** | Required fields and page limits, the same for preview and export. | — | Rendering |
| **Workflow** | An app-level use case that spans contexts (export a CV, draft with AI, browse designs). | Use case (single context) | App integration |

## UI copy in other languages

Translations follow the same vocabulary. The catalog carries one agreed term per concept and per language:
- Italian: CV, *design*, *CV di esempio*, *bozza*.
- German: *Lebenslauf* consistently, never mixed with "CV".

Each language uses its own capitalisation rules: sentence case in Italian and German, not English title case. Issue #43 tracks the full review.

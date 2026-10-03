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
| **Tailoring** | Rewriting one CV and writing a cover letter for one advert, then holding both to the source. | Translation: a CV is tailored in its own language | Tailoring |
| **Advert** | The job advert a tailoring is for: its text and what it asks for. | — | Tailoring |
| **Source CV** | The snapshot of the CV a tailoring starts from. | The stored CV, which can change meanwhile | Tailoring |
| **Tailored CV** | The CV a tailoring produces: the source CV rewritten for one advert, each rewritten line naming its source statements. | Draft, source CV | Tailoring |
| **Statement** | One line of an experience's description, as written, without its leading bullet. The unit of provenance. | An entry, or a whole description | Tailoring |
| **Evidence** | Where the source CV states a term the advert asks for: in prose, only listed, or absent. Only prose counts as evidence. | A skills list, which names a term without showing it | Tailoring |
| **Provenance** | The source statements a tailored line names. | — | Tailoring |
| **Provenance check** | The gate that refuses a tailored CV or letter that states anything its sources do not. | An audit that only warns | Tailoring |
| **Question** | What the user is asked. Before a tailoring: what the advert asks for that the source CV does not evidence, and the letter fields the advert asks for that the defaults do not give. After it: what the model says it would have needed. Never written into the CV. | — | Tailoring |
| **Answer** | What the user replies to a question. It is a source for that tailoring only, and only in its question's scope. | An edit of the CV: an answer never changes it | Tailoring |
| **Cover letter** | The letter a tailoring writes for one advert. It is held to the source CV, the advert and the letter defaults: whom it addresses comes from the advert, what it argues from the source. | — | Tailoring |

## UI copy in other languages

Translations follow the same vocabulary. The catalog carries one agreed term per concept and per language:
- Italian: CV, *design*, *CV di esempio*, *bozza*.
- German: *Lebenslauf* consistently, never mixed with "CV".

Each language uses its own capitalisation rules: sentence case in Italian and German, not English title case. Issue #43 tracks the full review.

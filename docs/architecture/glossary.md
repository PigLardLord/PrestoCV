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
| **Tailored CV** | The CV a tailoring produces: the source CV rewritten for one advert, each rewritten line naming its sources. | Draft, source CV | Tailoring |
| **Statement** | One line of an experience's description, as written, without its leading bullet. The unit of provenance. | An entry, or a whole description | Tailoring |
| **Evidence** | Where the source CV states a term the advert asks for: in prose, only listed, or absent. Only prose counts as evidence. | A skills list, which names a term without showing it | Tailoring |
| **Provenance** | The sources a tailored line names: statements of the same experience, and answers in scope. | — | Tailoring |
| **Provenance check** | The gate that refuses a tailored CV or letter that states anything its sources do not. | An audit that only warns | Tailoring |
| **Question** | What the user is asked. Before a tailoring: what the advert asks for that the source CV does not evidence, and the letter fields the advert asks for that the defaults do not give. After it: what the model says it would have needed. Never written into the CV. | — | Tailoring |
| **Answer** | What the user replies to a question. It is a source for that tailoring only, and only in its question's scope. | An edit of the CV (an answer never changes it); the model's reply | Tailoring |
| **Cover letter** | The letter a tailoring writes for one advert. It is held to the source CV, the advert and the letter defaults: whom it addresses comes from the advert, what it argues from the source. | — | Tailoring |
| **Role** | What one run of the server binary does: `serve` answers the API, `work` runs tailorings. The local profile runs both in one process. | An experience's role, or the professional title | Server |
| **Profile** | `hosted` or `local`: the set of adapters a composition root picks from configuration. | Environment | Server |
| **Environment** | Where the server runs: `local`, `staging` or `production`. `local` uses the local profile, the other two the hosted one. | Profile | Server |
| **Job** | One tailoring the server runs: its state, its CV and its result. It is erased once the app confirms it has saved the result, and 24 hours after the job ends at the latest. | The position an advert offers. Tailoring is the work; the job is the server's record of it | Server |
| **Provider** | A service that runs models, reached through an adapter: a hosted router, a commercial API, or a local model server. Its name and its models' identifiers appear nowhere in the repository except the published privacy policy and the hosted deployment's runbook; tests and configuration examples use invented names. | A model, which a provider runs and the configuration picks | Server |
| **Alias** | The name the configuration gives a provider and each of its models. It is the only name of a provider or a model in a result, a log or a report. | The provider's own name, which `GET /v1/policy` and the privacy policy show | Server |
| **Dialect** | An endpoint's quirks within the shared chat-completions API: its routing preferences, how it is asked for structured output, the extra headers it asks for. | A capability, which a model has or lacks: whether it supports structured output, and its context size. Several providers can share a dialect | Server |
| **Declaration** | What the deployment's operator declares of a provider: whether it keeps prompts (the request or its answer, for any purpose or time), whether it trains on them, and the regions it may run in. A router's declaration covers the upstreams its routing preferences allow (#154): it keeps prompts, trains on them or runs in a region if it or any of those upstreams does. | The provider's real behaviour, which the server cannot see | Server |
| **Data policy** | What a deployment requires of its providers: whether they may keep prompts, whether they may train on them, and the regions they may run in. A provider meets it when its declaration is at least as strict. The server refuses to start when a provider's declaration does not meet it. `GET /v1/policy` serves it with the processors, which are the providers named as the privacy policy names them, and the policy's version changes with either. | Declaration. The privacy policy, a document in the repository (#190) | Server |
| **Retention** | How long the server keeps something. A job is erased once the app confirms it has saved the result, and 24 hours after it ends at the latest. A device unused for 90 days is erased. A log line is kept for Cloud Logging's default of 30 days, and never holds a CV or an advert. Each period the server applies is configuration. | A provider's retention, which its declaration states as whether it keeps prompts | Server |
| **Cost limit** | One of four caps on tailorings and spend: 5 tailorings a device a day, 100 for everyone a day, the credit limit of the hosted router's key (5 $ a month) and a Google budget alert at 1 €. The server checks the first two. The provider enforces the third, and the alert only warns. Each is configurable, and these are the hosted defaults. | The per-address limits on unauthenticated requests (#172), which count requests and not tailorings | Server |
| **Spec** | `openapi.yaml`: the single source of the API between the app and the server, and its documentation. The types, the server's protocol and the app's client are generated from it. | The generated code, which follows the spec and is never edited by hand | App, Server |
| **Problem** | An error response of the API, in problem+json, with a stable `type` that the spec documents. Its `type` URI is its code; `title` and `detail` are for developers and never shown. | A typed error of a context (R7), which an adapter maps from or to a problem | App, Server |
| **Minimum app version** | The oldest version of the app that the server accepts. An older one is refused with a problem that tells the user to update. | The app's minimum operating system | App, Server |

## UI copy in other languages

Translations follow the same vocabulary. The catalog carries one agreed term per concept and per language:
- Italian: CV, *design*, *CV di esempio*, *bozza*.
- German: *Lebenslauf* consistently, never mixed with "CV".

Each language uses its own capitalisation rules: sentence case in Italian and German, not English title case. Issue #43 tracks the full review.

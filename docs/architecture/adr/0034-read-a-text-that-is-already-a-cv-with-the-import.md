# 0034. Read a text that is already a CV with the import, not the AI

- **Status:** Accepted
- **Date:** 2026-11-05
- **Related:** [ADR 0022](0022-ship-legacy-app-as-v1.md) (amended), [ADR 0023](0023-ground-the-ai-draft-in-the-description.md), [ADR 0027](0027-import-a-cv-from-its-text-with-rules.md), [ADR 0033](0033-change-the-legacy-app-only-to-fix-the-published-version.md), issues #359, #371

## Context

- **The AI draft is built for a free description.** The person writes a few sentences about their work, and the on-device model writes a CV from them, under the grounding rules of [ADR 0023](0023-ground-the-ai-draft-in-the-description.md): nothing invented, nothing of the person's lost.
- **People also paste a CV they already have.** The owner did so on their phone on 2026-11-05, with version 1.0. The draft was not credible: duties rewritten in other words, an internship shown before the current job, languages and years lost. The model shortens and rewrites what it is given, and the grounding rules then cut what they cannot trace back to the text. Both steps are right for a description of a few sentences, and both lose data on a CV.
- **The import already reads a pasted CV** ([ADR 0027](0027-import-a-cv-from-its-text-with-rules.md)). It keeps every job with its duties as written, invents nothing, and lists for the person what it could not place. On invented CVs in English, Italian and German it kept every job, every duty and every language, in under a fifth of a second for 8,000 characters.
- **The AI draft refuses more than 2000 characters** (`CVGenerationLimits.maximumDescriptionLength`), and the Generate button is off above it, so a whole CV can only reach the model shortened.
- **Version 1 is submitted,** so a change to the legacy app must fix a bug of the published version ([ADR 0033](0033-change-the-legacy-app-only-to-fix-the-published-version.md)). A pasted CV that comes back with fewer facts than it had is a loss of data. Pasted text is a way in that version 1 already offers, in the AI draft and in the import.

## Decision

**The owner decided on 2026-11-05** that a text that is already a CV is read by the import, not the AI. The AI draft stays for free descriptions.

- **When the text given to the AI draft is already a CV,** the app reads it with the import of [ADR 0027](0027-import-a-cv-from-its-text-with-rules.md) and opens the editor with the import's review list, as the import screen does. The text is not sent to the model.
- **"Already a CV" is one rule in `PrestoCVImporting`:** the import fills at least two of the seven sections (summary under a heading, experience, education, skills, languages, certifications, interests) from headings it recognises, and at least one experience or education entry has a period. The two numbers are named constants with one test table.
- **Any doubt goes to the AI draft, as today.** When the rule says no, when the import throws or when its limits refuse the text, the AI draft runs unchanged. The person who asked for a draft never sees an import error.
- **The editor says what happened:** the text was already a CV, so it was read as written, and nothing was added or rewritten. The notice's review button opens the import's review list.
- **Generate stays on above 2000 characters,** so that a whole CV can be recognised. A free description above the limit is still refused after the press, with the AI draft's existing message, and nothing is sent to the model. The counter still turns red.
- **Version 1.0.1 adds no control to choose.** A prompt such as "Import it as written?" or a way to ask the AI anyway is a new control, so a feature under [ADR 0033](0033-change-the-legacy-app-only-to-fix-the-published-version.md). The model's code (`CVGeneratorAI`) does not change for this decision.
- **From version 1.1, in the new targets,** the AI only fills the gaps of a text that is already a CV, such as a missing summary or the skills a described job implies. It never rewrites a job the person described. The choice to use the AI anyway comes with it.

## Consequences

- **A pasted CV keeps the person's words,** in the order they wrote them, and opens in a fraction of a second instead of waiting for the model.
- **A wrong "yes" is visible and loses nothing.** A free description with two headings and a dated line is read as written: the person sees their own text in the editor and in the review list, and can edit it. They cannot ask the AI to rewrite it in 1.0.1.
- **A wrong "no" is today's behaviour.** A CV with no dates, or with headings the import does not know, still goes to the AI draft.
- **Sections the import does not read,** such as projects or volunteering, stay in the review list as text not imported, as [ADR 0027](0027-import-a-cv-from-its-text-with-rules.md) decided.
- **The AI draft's own defects are fixed in its code,** after #359. This decision takes the pasted CV away from the model; it does not change what the model writes from a description.
- **The rule lives in `PrestoCVImporting`,** a target of the new architecture, and follows its rules: it is pure, holds no user text and builds on Linux. The app wires it in the AI draft's view model through an injected intake, so no rule sits in a view or a view model. Its tests are the rule's table of invented texts (CVs in several languages, free descriptions, the boundaries of both numbers) and the app's routing tests.
- **Every text given to the AI draft is read by the import first,** so the app's log and the diagnostics of a TestFlight install show an import before each AI draft ([logging](../../logging.md)).
- **No check enforces the choice of the path.** The tests pin the rule and the routing; the review of the change checks that the model is not called for a recognised text.

## Alternatives considered

- **Ask first, "Import it as written?"** Clearer when the rule is wrong, but a new control, so a feature under [ADR 0033](0033-change-the-legacy-app-only-to-fix-the-published-version.md). It comes in 1.1, with the choice to use the AI anyway.
- **Let the model decide whether the text is a CV.** Slow, it would change with each model version, and the model is the step that lost the facts.
- **Fix the AI draft first (#359).** Needed anyway, but a model that rewrites a whole CV keeps losing some of it, and until then every pasted CV would. The import already keeps it.
- **Also use the share of text the import could not place.** It was zero both for a clean CV and for a description with no headings, so it told the two apart in no case.
- **Require three sections.** It misses a short real CV with only experience and languages.

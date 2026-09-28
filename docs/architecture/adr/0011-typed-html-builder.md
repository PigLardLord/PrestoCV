# 0011. Generate document HTML with a typed builder; designs are allow-listed CSS only

- **Status:** Accepted
- **Date:** 2026-09-28
- **Related:** [ADR 0002](0002-cvpdfexporter-standalone-and-portable.md), [ADR 0007](0007-each-package-owns-its-model.md), R8, issues #2, #3, #9, #21

## Context

Rendering today goes through an in-house Mustache-like engine built on regular expressions, fed with a `[String: Any]` context. Almost every defect in the exported PDF comes from that path:
- **#2.** Placeholders in the HTML that actually renders don't match the keys the engine provides. Loop items fall back to the parent context, so the person's job title appears in Education, Languages, Interests and Social.
- **#3.** Design CSS targets class names that the rendered HTML does not emit.
- **#21.** Triple-mustache never works, user text containing `{{…}}` is re-evaluated or stripped, and empty strings count as present.
- **#9.** Imported packages can ship arbitrary HTML, and CSS is interpolated with placeholders.

The three bundled designs are CSS-only (`htmlContent: null`). R8 already rejects HTML from design packages that come from outside the bundle.

## Decision

- **A typed HTML builder.** `CVRendering` builds the document HTML in Swift from `CVDocument`. There is no template language and no string-keyed context.
  - Tag and attribute names are closed enums.
  - Text and attribute values are escaped **per Unicode scalar**.
  - Raw HTML cannot be represented.
  - The language attribute must look like a BCP 47 tag.
  - Links are kept only as parsed `WebLink`s.
  - Dates are typed until the builder formats them in the document's language. An ended period with no end date shows only its start; it never says "present".
- **The document markup contract.** The output follows a stable, versioned structure, specified in [markup-contract.md](../markup-contract.md). A golden HTML file in the tests pins it.
- **Designs are CSS only, and their CSS is parsed, not sanitised.**
  - A CSS tokenizer accepts only the contract's selectors and an **allow-list** of properties with bounded values. It then re-serialises the tokens, so the emitted CSS is exactly the validated CSS.
  - The allow-list leaves out everything that can load a resource, or hide, move, reorder or inject content. Colours come only from palette variables, and a palette exists only with readable contrast. Fonts come only from a closed set of system families.
  - The manifest declares the contract version, which must be supported.
- **Completeness is checked on every export, against the actual document.** The builder returns the HTML together with the text nodes it contains: fields, headings, dates, levels. Every text node must occur in the PDF text at least as often as in the document, ignoring case and spacing.
  - Removing one of two identical entries is detected.
  - So is removing a value that also appears inside another one, such as a skill named in the summary, or removing every date (review round 2).
- **Installing a design goes through a rendering gate.** The catalog's `InstallDesign` validates the package, then calls `DesignRenderingGate`, then stores it. The catalog owns that port; `CVRendering` implements it (`FixtureRenderingGate`), along the allowed Rendering → Catalog edge. The gate renders a fixture that uses every section, and requires an untruncated PDF with every text node. Nothing is stored otherwise. The same gate runs on the backend.
  - Designs cannot produce text (`content`, `list-style` strings, counters, `quotes` and the like are not allowed), so the check cannot be satisfied by injected text.
  - Checking every export also defeats a design that behaves differently on the fixture.
- **Headings are localised** from package resources, matched by BCP 47. An unsupported language is an error.

## Consequences

- **Whole classes of bug become impossible:** placeholder mismatch, parent-context leaks, re-parsing of user text, and style breakouts. They are either compile errors or not expressible.
- **The old engine is deleted:** `TemplateEngine`, `BaseHTMLTemplate`, the fallback HTML, and the `htmlContent` field of design packages. A package that still has the field is rejected, not silently accepted.
- **Designs control presentation, not structure.** A layout CSS cannot express needs a new contract version, reviewed like code. This limits third-party designs, and it is the intended trade-off: designs are untrusted, especially on a backend.
- **The bundled designs are rewritten against contract 1**, with CSS custom properties instead of placeholders and no `content:` separators.
- **The allow-list is conservative.** Adding a property means a code change and tests, not a data change.

## Validation

**Scope.** HTML and CSS level. PDF-level evidence needs the native renderers ([ADR 0003](0003-one-pdf-renderer-per-platform.md)), and the geometric completeness check is still pending.

The validation prototype in `Prototypes/ADRValidation/` (Swift 6.3.3, Linux). 42 Exporter tests pass, many with dozens of parameterised cases.

**Passed**
- **Every field in its own section.** There is no parent-context leak (#2), and an unrated skill has no bare number (#21).
- **Golden file.** The output matches the committed golden file, and changing the fixture makes the test fail.
- **Escaping.**
  - A quote followed by U+0301 cannot add an attribute, checked with a scalar-level tag tokenizer. Swapping in the old `Character`-based escaping fails the test.
  - An invalid language tag becomes `und`.
- **Links.** Dropped: userinfo, homograph hosts, U+202E, NBSP, backslashes, oversized URLs, `mailto` with a query, non-default ports, `javascript:` in any casing. Safe links are kept in their parsed form.
- **The `<style>` breakout of the security review (C1)** is rejected, whether bare, in a comment or in a string. So is the comment-inside-string evasion (C2).
- **Resource loads (17 cases)** are rejected, including CSS escapes, `image-set()`, `@font-face`, `data:`, `border-image`, `mask`, `cursor` and `filter:url`.
- **Hiding, moving and injecting (54 cases)** are rejected. This covers all 34 constructs the security review found accepted by the old deny-list, plus `:has()`, `:nth-of-type`, ids, custom properties, `!important`, `@supports`, `@layer`, `@container`, nested rules and `calc()`.
- **A realistic two-column design passes**, and is emitted in canonical form without comments.
- **Contact fields and certifications** render in their contract classes and section (review round 2).
- **Links and inline entries.**
  - Every link prints its `href` as its text. A PDF that keeps the labels but loses the destinations is incomplete (review round 3).
  - Skills, profiles and interests are separated by a space that is not a field (review round 4).
  - A flex or grid rule without a column gap of at least 3pt is rejected: 9 rejected and 5 accepted cases (review round 5).
- **Completeness counts occurrences.** It fails when the Swift skill is removed while "Swift" remains in the summary, when one of two identical entries is removed, and when every date is removed.
- **Install gate:**
  - a design that renders completely is stored;
  - a renderer that loses content leaves the store empty;
  - an invalid package is rejected before anything is rendered.
- **Numbers:** `font-size:0` (also `+0`, `0.0`) is rejected. Numbers too long for the tokenizer are rejected instead of crashing the validator (review round 2: an `Int(Double)` overflow trap). `margin:0` is still accepted.
- **Package validation:** traversal ids, a trailing newline in the id, an `htmlContent` key, unknown keys, an unsupported contract, a bad preview, oversized bytes and non-objects are all rejected. A valid PNG preview is kept.
- **Palettes.** Low-contrast palettes cannot be created, and colours with a trailing line terminator are rejected.

**Found**
- Review round 2: bare `0` was accepted for `font-size`; an oversized number crashed the validator; the completeness predicate could be satisfied by a value occurring elsewhere; the install path had no permitted way to render.
- The first validator was a regex deny-list. It checked comment-stripped text but emitted the original, so `</style>` inside a comment passed; the security review showed 34 of 34 hiding constructs got through. It was replaced by the tokenizer and allow-list.
- The builder emitted `</meta>`. `meta` is a void element, so this was fixed.
- All three bundled designs are rejected as they stand: legacy `htmlContent` key, no contract version, placeholders, `content:` separators.

## Alternatives considered

- **Adopt a spec-compliant Mustache library** (for example, one that supports Linux). It would fix the engine bugs and keep structural freedom for designs. It would not fix the contract problem: keys would still be strings checked at runtime, and HTML from packages would still need sanitising. This is the fallback if designs ever need their own markup; it would come with a separate ADR, a golden test per design, and a strict "unknown key is an error" mode.
- **Fix the in-house engine.** Rejected: that keeps a template language to maintain, with the same contract problem.

# Document markup contract and design CSS grammar

This document defines two things, both normative ([ADR 0011](adr/0011-typed-html-builder.md)):

- the HTML structure that `CVRendering` produces from a `CVDocument`;
- the CSS a design may use to style it.

A design declares the contract version it targets in its manifest (`markupContract`), and the validator rejects any other version.

The cover letter has a structure of its own, which no design styles. It is specified below, in its own section ([ADR 0019](adr/0019-applications.md)).

The source of truth is code in `CVDesignCatalog`: `MarkupContract` for the structure, `allowedProperties` for the properties. This page must match that code exactly. That code is `CSS.swift` and `MarkupContract.swift` in `CVPDFExporter/Sources/CVDesignCatalog/`, with the attack fixtures in `CVPDFExporter/Tests/`. `MarkupContractPageTests`, in `CVPDFExporter/Tests/CVDesignCatalogTests/`, reads this page and fails when it and the code disagree: the sets must be equal, and every documented value and bound is probed at its edges.

## Version 1

### Structure

```
html[lang]
└── body
    └── main.cv[data-schema]
        ├── header.cv-header
        │   ├── h1.cv-name
        │   ├── p.cv-title            (if present)
        │   ├── p.cv-contact          (email, if present)
        │   ├── p.cv-phone            (if present)
        │   ├── p.cv-location         (if present)
        │   └── a.cv-website[href]    (if present and a valid WebLink; its text is the href)
        └── section.cv-section[data-section=<kind>]      one per non-empty section, in document order
            ├── h2.cv-section-title                     localised heading
            └── entries:
                experience, education,
                certifications:          article.cv-entry
                                         ├── h3.cv-entry-title        role / degree / certification name
                                         ├── p.cv-entry-subtitle      company / school / issuer
                                         ├── p.cv-entry-location      (experience: if present)
                                         ├── p.cv-entry-period        (if present; certifications: the year)
                                         ├── p.cv-entry-description   (if present)
                                         └── a.cv-entry-link[href]    (certifications: if present and valid; its text is the href)
                summary:                 p.cv-summary
                skills:                  span.cv-skill[data-rating=1…5]   (data-rating only when rated)
                languages:               p.cv-language > span.cv-language-level
                profiles:                a.cv-profile[href]
                                         ├── span.cv-profile-platform
                                         └── span.cv-profile-url      its text is the href
                interests:               span.cv-interest
```

**Inline text never runs together.** Adjacent inline entries (skills, profiles, interests) are separated by one space in the markup. So are a profile's platform and URL. The space is not a field for completeness.
- In normal flow, and between `inline-block` boxes, the space is rendered.
- Flex and grid layouts drop it. So a rule that sets `display: flex`, `inline-flex` or `grid` must also set `gap` or `column-gap`, with a column gap of at least 3pt (0.25em); otherwise the stylesheet is rejected (review round 5).
- The native renderer tests check the separation in the printed text (#78).

**Links print their destination.** Every link's destination is printed as text, exactly as its `href`.
- Whether a PDF keeps clickable link annotations depends on the platform's PDF path. The printed text is what completeness checks ([R8](rules.md#r8-untrusted-input-enters-through-one-validating-boundary)), so a PDF that keeps a link's label but loses its destination fails.
- Where a platform keeps the annotations, the native renderer tests also check that they match the `href`s.
- The builder's own base style sets `a { overflow-wrap: anywhere }`, so a long destination wraps instead of running off the page. Designs cannot set `overflow-wrap`.

### Pages

The renderers print on the page size, A4 unless the caller says otherwise. Every page keeps 36pt free at its top and at its bottom, the pages after the first too; a design's padding only applies where the document starts and ends. The left and right margins are the design's: its padding on `.cv`. A design keeps a heading with what follows it with `break-after: avoid`, and an entry together with `break-inside: avoid`.

### Selectable by a design

| Kind | Values |
|---|---|
| Elements | `main`, `header`, `section`, `article`, `h1`, `h2`, `h3`, `p`, `span`, `a` |
| Classes | `cv`, `cv-header`, `cv-name`, `cv-title`, `cv-contact`, `cv-phone`, `cv-location`, `cv-website`, `cv-section`, `cv-section-title`, `cv-summary`, `cv-entry`, `cv-entry-title`, `cv-entry-subtitle`, `cv-entry-location`, `cv-entry-period`, `cv-entry-description`, `cv-entry-link`, `cv-skill`, `cv-language`, `cv-language-level`, `cv-profile`, `cv-profile-platform`, `cv-profile-url`, `cv-interest` |
| `[data-section=…]` | `summary`, `experience`, `education`, `skills`, `languages`, `certifications`, `profiles`, `interests` |
| `[data-rating=…]` | `1` … `5` |
| Pseudo-classes | `:first-child`, `:last-child`, `:only-child` |
| Combinators | descendant, `>`, `+`, `~`; selector lists with `,` |
| Custom properties (read only, through `var()`) | `--color-text`, `--color-primary`, `--color-background`, `--font-body`, `--font-heading` |

### Design CSS grammar

**Lexical rules.** The stylesheet must be printable ASCII outside comments. The following are rejected anywhere, including inside comments and strings:
- `<`;
- `\` (CSS escapes);
- control characters;
- numbers with more than nine digits before the decimal point.

Comments are dropped. Strings may appear only as `[data-section="…"]` values. The emitted stylesheet is the canonical re-serialisation of the validated tokens: no comments, no redundant whitespace, lower-case properties and keywords.

**Structure.** A stylesheet is a sequence of rules `selector-list { declarations }` and of `@media print|screen|all { rules }`. Rules cannot be nested. No other at-rule is allowed.

**Rejected outright:**
- ids, the universal selector `*` (it also reaches the document root), attribute selectors other than the two above, pseudo-elements, functional pseudo-classes (`:has()`, `:not()`, `:nth-*()`), and any element or class outside the contract;
- custom property declarations (`--x: …`), `!important`, and every function except `var()` on the variables above.

**Declarations.** Only these properties exist. Any other property, or a value outside the bounds, rejects the whole stylesheet.

Units and bounds:
- Lengths are written in `pt`, `px`, `em` or `rem`, and `%` where the table allows it.
- `px` is checked after conversion (1px = 0.75pt).
- A bare `0` is allowed only where 0 is within the bounds, so `font-size: 0` is rejected.

| Property | Allowed values |
|---|---|
| `color`, `border-color` | `var(--color-text)` or `var(--color-primary)` |
| `background-color` | `var(--color-background)` or `transparent` |
| `font-family` | `var(--font-body)` or `var(--font-heading)` |
| `font-size` | 7–48 pt (px converted). Relative units are refused: `em` and `%` compound through nesting, and `rem` follows the root's size, so only an absolute size keeps the floor. |
| `font-weight` | a number 100–900, `normal`, `bold` |
| `font-style` | `normal`, `italic` |
| `line-height` | a number 1–3, `normal` |
| `letter-spacing` | 0–3 pt; 0–0.3 em/rem |
| `text-transform` | `none`, `uppercase`, `lowercase`, `capitalize` |
| `text-align` | `left`, `right`, `center`, `justify`, `start`, `end` |
| `text-decoration` | `none`, `underline` |
| `margin`, `padding` | 1–4 lengths, each 0–48 pt; 0–4 em/rem |
| `margin-top`, `-bottom`, `-left`, `-right`; `padding-top`, `-bottom`, `-left`, `-right` | one length, 0–48 pt; 0–4 em/rem |
| `border`, `border-top`, `-bottom`, `-left`, `-right` | in any order: a width of 0–4 pt (0–0.3 em/rem), a style (`solid`, `dashed`, `dotted`, `none`), a colour as for `color` |
| `border-radius` | 0–16 pt; 0–1 em/rem |
| `display` | `block`, `inline`, `inline-block`, `flex`, `inline-flex`, `grid`; a rule that sets `flex`, `inline-flex` or `grid` must also set `gap` or `column-gap` |
| `flex-direction` | `row`, `column` |
| `flex-wrap` | `wrap`, `nowrap` |
| `flex` | a number 0–10 |
| `justify-content` | `flex-start`, `flex-end`, `center`, `space-between`, `space-around`, `start`, `end` |
| `align-items` | `flex-start`, `flex-end`, `center`, `baseline`, `stretch`, `start`, `end` |
| `gap` | 1 length (row and column) or 2 lengths (row, then column): row 0–48 pt, 0–4 em/rem; column 3–48 pt, 0.25–4 em/rem |
| `row-gap` | one length, 0–48 pt; 0–4 em/rem |
| `column-gap` | one length, 3–48 pt; 0.25–4 em/rem |
| `grid-template-columns` | 1–4 tracks, each 0.1–10 `fr`, 36–600 pt, 3–40 em/rem, or 10–100 % |
| `width`, `max-width` | 36–600 pt; 3–40 em/rem; 10–100 % |
| `break-inside`, `page-break-inside` | `auto`, `avoid` |
| `break-before`, `break-after` | `auto`, `page`, `avoid` |

Anything that could load a resource, or hide, move, reorder or inject content, is absent from this table by design. That includes `position`, `transform`, `zoom`, `filter`, `mask`, `clip`, `overflow`, `visibility`, `opacity`, `height`, `content`, `list-style`, `quotes`, counters, `direction`, `unicode-bidi`, `order` and grid placement. The palette itself only exists with readable contrast ([R8](rules.md#r8-untrusted-input-enters-through-one-validating-boundary)).

## The cover letter's structure (planned, #187)

A `LetterDocument` is rendered as a structure of its own, beside the CV's. One built-in stylesheet styles it, for every design ([ADR 0019](adr/0019-applications.md)).

- **Its elements and classes are its own.** None of its classes is in the table of what a design may select, so a design's CSS cannot select them: the design validator rejects any class outside that table.
- **Its stylesheet is not a design.** It passes the same tokenizer and property allow-list as a design's, checked against the letter structure's selectors. Its colours and fonts are fixed values of the stylesheet.
- **The structure is pinned by a golden HTML file** (R10), and a test reads this section and holds the code to it, as `MarkupContractPageTests` does for the CV's structure.
- **The structure itself is written here when #187 lands:** the tree, the classes and the page rules. Its headings differ from the CV's `### Structure` and `### Selectable by a design`, which `MarkupContractPageTests` finds by name. Until then this section only states that the letter is separate from the CV's contract.

## Changelog

| Version | Change | Compatible with |
|---|---|---|
| 1 | Initial contract (2026-09-28): structure, contact fields, certifications, links that print their destination, spaces between inline entries, an experience's location, CSS grammar with absolute font sizes and no universal selector. | — |

A change that could break an existing design bumps the version, for example removing a class, changing the nesting, or tightening a bound. Adding a class, a property or a wider bound does not.

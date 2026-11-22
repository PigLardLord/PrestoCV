# Document markup contract and design CSS grammar

This document defines two things, both normative ([ADR 0011](../../docs/architecture/adr/0011-typed-html-builder.md)):

- the HTML structure that `CVRendering` produces from a `CVDocument`;
- the CSS a design may use to style it.

A design declares the contract version it targets in its manifest (`markupContract`), and the validator rejects any other version. A design store still lists a design it saved for an older version, but refuses it when read; the sync replaces a bundled one with its new version.

The manifest also names the design's default palette (`defaultPalette`: `ink`, `slate`, `ocean` or `plum`) and default font scheme (`defaultFonts`: `system`, `serif` or `rounded`), both required and written as identifiers; a user's choice that names none, or one the catalog does not know, falls back to them. Its `version` is `MAJOR.MINOR.PATCH`, each part `0` or one to nine ASCII digits without a leading zero, and versions are compared by number. Its `name` is one line of 1–80 Unicode scalars and its `description` up to 500; neither holds a control character (a description may span lines with `\n`), a line or paragraph separator or a bidirectional override. The validator rejects an unknown identifier, a malformed version, and a name or description outside these bounds.

The source of truth is code in `CVDesignCatalog`: `MarkupContract` for the structure, `allowedProperties` for the properties. This page must match that code exactly. That code is `CSS.swift` and `MarkupContract.swift` in `CVPDFExporter/Sources/CVDesignCatalog/`, with the attack fixtures in `CVPDFExporter/Tests/`. `MarkupContractPageTests`, in `CVPDFExporter/Tests/CVDesignCatalogTests/`, reads this page through `Bundle.module`, since its test target copies it, and fails when it and the code disagree: the sets must be equal, and every documented value and bound is probed at its edges.

## Version 2

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
            ├── div.cv-section-start                    the title and the first entry, kept on one page where it fits
            │   ├── h2.cv-section-title                 localised heading
            │   └── the first entry                     (skills, profiles, interests: none, the entries all follow)
            └── the other entries, each one of:
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
- In normal flow, and between `inline-block` boxes, the space is rendered. Skills and interests are always in normal flow, since a section stays a block (see [Pages](#pages)).
- Flex and grid layouts drop it, for example on a profile or an entry. So a rule that sets `display: flex`, `inline-flex` or `grid` must also set `gap` or `column-gap`, with a column gap of at least 3pt (0.25em); otherwise the stylesheet is rejected (review round 5).
- The native renderer tests check the separation in the printed text: `flex and grid keep inline entries apart`, on macOS and on the iOS simulator (#78).

**Links print their destination.** Every link's destination is printed as text, exactly as its `href`.
- Whether a PDF keeps clickable link annotations depends on the platform's PDF path. The printed text is what completeness checks ([R8](../../docs/architecture/rules.md#r8-untrusted-input-enters-through-one-validating-boundary)), so a PDF that keeps a link's label but loses its destination fails.
- The macOS renderer keeps one link annotation per link, and its tests check that the destinations match the `href`s. The iOS renderer keeps none, and its test fails if that changes (`the annotations match the builder's hrefs, or the platform keeps none, as recorded`, #78).
- The builder's own base style sets `a { overflow-wrap: anywhere }`, so a long destination wraps instead of running off the page. Designs cannot set `overflow-wrap`.

### Pages

The renderers print on the page size, A4 unless the caller says otherwise. Every page keeps 36pt free at its top and at its bottom, the pages after the first too; a design's top padding on `.cv` only applies where the document starts. The left and right margins are the design's: its padding on `.cv`. A design keeps an entry together with `break-inside: avoid`.

The builder's own base style decides two things whatever the design says, with `!important`, which a design cannot use (#467):
- **A title is never alone at the foot of a page.** Neither print path honours `break-after: avoid`, so a design cannot keep a title with what follows it by itself. The title, kept whole, holds an empty block under its last line, as tall as what must follow it, that never breaks across pages and gives back all but 1px of its room: where the page's foot cannot hold it, the title moves to the next page with its section. The block covers the title's bottom padding and bottom margin at the limits below (each the larger of 1em and 12pt), its bottom border at the border limit (the larger of 0.3em and 4pt), and the next line, a first row of skills included (the larger of 2.5em and 30pt; 23pt at most in the bundled designs). It is at least 150pt when the first entry has a description (its head, title, organisation, place and dates, and its first line: 143pt at most). A forced break between a title and what follows it is ignored; a break before a section, or after a first entry, stays. A section's title and its first entry are one block, `div.cv-section-start`, which does not break across pages where it fits on one, so a short first entry moves with its title; a longer one breaks inside, under its title. An inline section's start holds its title alone, since its entries can fill more than a page.
- **The room is enough because a design is bounded there.** A stylesheet is rejected, with the reason, if a rule that could style a section's title (`h2.cv-section-title`) sets a bottom padding or a bottom margin above 1em or 12pt, or a `display` other than `block`; if a rule that could style a section's start (`div.cv-section-start`) sets a `display` other than `block`, or any bottom padding, bottom border or bottom margin; or if a rule that could style the document (`main.cv`) or a section (`section.cv-section`) sets a `display` other than `block`. A flex or grid container printed across pages cuts lines at a page's end, loses text and leaves a section's start at a page's foot, in WebKit on both print paths, so no reserve can hold there. Entries, their lines, profiles and the header may still use flex and grid. The limits are `MarkupContract.titleBottomSpacing` and `MarkupContract.borderWidth` (#467).
- **Nothing follows the last line,** so a full last page never pushes out a blank one: the bottom margins of `body`, of `.cv` and of the last element at every depth below `.cv` (`.cv > :last-child`, `.cv > :last-child > :last-child`, and so on), and the bottom padding of `.cv`, are zero. The page's own 36pt is the space at its foot. A bottom padding or border a design puts on another last element still prints.

### Selectable by a design

| Kind | Values |
|---|---|
| Elements | `main`, `header`, `section`, `div`, `article`, `h1`, `h2`, `h3`, `p`, `span`, `a` |
| Classes | `cv`, `cv-header`, `cv-name`, `cv-title`, `cv-contact`, `cv-phone`, `cv-location`, `cv-website`, `cv-section`, `cv-section-start`, `cv-section-title`, `cv-summary`, `cv-entry`, `cv-entry-title`, `cv-entry-subtitle`, `cv-entry-location`, `cv-entry-period`, `cv-entry-description`, `cv-entry-link`, `cv-skill`, `cv-language`, `cv-language-level`, `cv-profile`, `cv-profile-platform`, `cv-profile-url`, `cv-interest` |
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

Anything that could load a resource, or hide, move, reorder or inject content, is absent from this table by design. That includes `position`, `transform`, `zoom`, `filter`, `mask`, `clip`, `overflow`, `visibility`, `opacity`, `height`, `content`, `list-style`, `quotes`, counters, `direction`, `unicode-bidi`, `order` and grid placement. The palette itself only exists with readable contrast ([R8](../../docs/architecture/rules.md#r8-untrusted-input-enters-through-one-validating-boundary)).

## Changelog

| Version | Change | Compatible with |
|---|---|---|
| 1 | Initial contract (2026-09-28): structure, contact fields, certifications, links that print their destination, spaces between inline entries, an experience's location, CSS grammar with absolute font sizes and no universal selector. | — |
| 2 | A section's title and its first entry are wrapped in `div.cv-section-start`, which does not break across pages where it fits on one (the title alone for skills, profiles and interests, whose entries follow it); the title keeps room for what follows it at a page's foot, so a title's bottom padding and margin are at most 1em or 12pt, and the title, a section's start, the sections and the document stay `display: block`; the base style ends the document at its last line (2026-11-21, #467). | not 1: the nesting changed, so `.cv-section > .cv-entry`, `.cv-entry + .cv-entry`, `:first-child` and `:last-child` no longer select what they did in block sections |

A change that could break an existing design bumps the version, for example removing a class, changing the nesting, or tightening a bound. Adding a class, a property or a wider bound does not.

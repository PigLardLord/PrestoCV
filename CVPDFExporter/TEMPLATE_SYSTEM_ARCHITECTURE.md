# The legacy template system

The HTML templates of the legacy `CVPDFExporter` target, the exporter that the published app ships. The targets of the Design Catalog and Document Rendering context replace it, and it is deleted once the app no longer uses it ([ADR 0012](../docs/architecture/adr/0012-legacy-targets-during-migration.md)).

## Where the templates come from

- **The bundled designs** are the `.mcvt` packages in `Resources/Templates/Bundled`: professional, modern and minimal. At launch `TemplateBootstrapService.syncBundledTemplates()` installs each one through `InstallTemplateUseCase`. A package that is not registered is installed, and an installed one is replaced only when the bundled version is higher. The service takes professional, modern and minimal in that order, then any other package by file name, so the template the export sheet preselects does not depend on the file system. A package that cannot be installed is logged and skipped; the others are still installed.
- **`FileTemplateRepository`** keeps the installed packages in Application Support (`PrestoCV/Templates`). Installing a package writes it, caches its preview image as `<id>_preview.png` in the registry's directory and writes the registry entry (`TemplateRegistryManager`) last, replacing an installed version. A file it cannot decode is skipped.
- **`BundledTemplateRepository`** (`Templates/TemplateRepository.swift`) is the read-only list the app shows. It reads through a `FileTemplateRepository` and lists a template only once it is registered; installing through it throws. If the storage cannot be opened, the error is thrown when the templates are requested, not when the repository is made. `loadTemplate(id:)` throws `TemplateError.templateNotFound` for an unknown id.
- **`GetAvailableTemplatesUseCase`** joins the lists of several repositories. A template that two repositories hold is listed once, from the first; a repository that fails leaves out only its own templates.

## The .mcvt package

A `.mcvt` file is a `TemplatePackage` in JSON:

```json
{
  "manifest": {
    "id": "modern",
    "name": "Modern",
    "description": "Contemporary design with clean lines and modern typography",
    "author": "PrestoCV",
    "version": "1.0.5",
    "previewImage": "preview.png",
    "price": 0.0
  },
  "cssContent": "/* the design's stylesheet */",
  "htmlContent": null,
  "previewImageBase64": "<the thumbnail, a PNG in base64>"
}
```

- The id, the name and the version may not be empty, the price may not be negative (`TemplateManifest`), and the stylesheet may not be empty (`TemplatePackage`).
- `htmlContent` is the page of the package. When it is null, as in modern, the page is the base template (`BaseHTMLTemplate`).
- `previewImageBase64` is the thumbnail the export sheet shows (see "Regenerating the thumbnails" below). Older packages keep it in the manifest; `embeddedPreviewBase64` returns whichever the package has.
- `Scripts/update_template_manifests.py` adds the manifest fields a package lacks ([Scripts/README.md](Scripts/README.md)).

## From template to PDF

1. The export sheet offers the templates of `GetAvailableTemplatesUseCase`, and the person picks one.
2. The page is the package's `htmlContent`, or the base template when it has none, with the package's `cssContent` in the `{{customCSS}}` slot (`TemplatePackage.composedHTML`).
3. `TemplateLocalizer` replaces the `{{i18n_*}}` placeholders with the headings of the document's language: English, Italian, German, Spanish, French or Portuguese. Any other language gets English.
4. `TemplateEngine` binds the CV's data. Text from the CV is escaped, braces included, so it is never read as a template tag.
5. `PDFRendererFactory` gives the platform's renderer, `EnhancedWKWebViewPDFRenderer` on iOS and `ProperMacOSPDFRenderer` on macOS, which prints the page to a PDF.

### Page breaks

The iOS renderer paginates with `UIPrintPageRenderer`, which keeps a block whole for `break-inside: avoid` and keeps the first and the last lines of a block together for `orphans` and `widows`, but does not honour `break-after: avoid`: a title would stay alone at the foot of a page. The bundled designs therefore:

- print each entry of work experience, education and certifications as one block of inline content, whose first lines stay together (`orphans: 3`, `widows: 3`) and flow over the page break; a long entry is cut, a short one is not;
- print the title of such a section as the first line of its first entry. The engine flags that entry with `isFirst`: `{{#isFirst}}<span class="section-title">…</span>{{/isFirst}}`;
- keep a small section (skills, languages, interests, social links) whole with `break-inside: avoid`, and a certificate;
- space blocks with a margin above each block that follows another, never below, so that the end of the CV has no margin to push an empty page out;
- let a web address break after its slashes: the engine puts a `<wbr>` after each slash that follows a name, and the designs use `overflow-wrap: anywhere` for an address longer than its column.

`PageBreakManager` adds forced breaks (`.page-break`) and `.avoid-break`, and nothing that makes a section or an entry unbreakable.

### A short CV on one page

A short CV often runs over one page by a few lines, and its last sections, kept whole, would then be alone on a second page. `OnePageFit` says how the iOS renderer prints such a CV on one page instead. A CV is a candidate when it takes two pages with the design's own spacing; a CV of one page, or of three or more, is printed once, as its design lays it out.

The renderer tries two steps on a candidate, lightest first, and keeps the first print that takes one page:

1. **Tightening** (class `fit-one-page` on the root element): the space between blocks and between lines closes up a little. The foot margin of the page stays.
2. **Compact** (classes `fit-one-page` and `fit-one-page-compact`): the space closes up to the least that is still easy to read; the small lists (languages, profiles, certificates) of the designs that stack them run along a line instead of down a column; and the margin at the foot of the page shrinks from the page's margin to `OnePageFit.minimumBottomMargin`, which is 10 mm.

A CV that no step brings onto one page is printed as its design lays it out. That print is drawn before the page changes, so it is the same, page for page, as without `OnePageFit`: a long CV keeps its page breaks, and so does a CV of two pages that is too long to fit.

What a step never does:
- change the size of the text, narrow the page's side margins or the text column, or scale the page;
- set the lines closer than 1.2 times the size of the text;
- take the margin at the foot of the page below 10 mm.

The text of the compact print reads in the order of the design's own print: an item that a design stacks, such as a profile's platform over its address, is set on one line so that the platform comes before its address. WebKit prints Modern scaled to fit, and the scale follows the height of the printable area, so its text comes out a fraction of a percent smaller when the foot margin shrinks (the name is 28.9 pt instead of 29.0 pt), as it does for any change of the page's margin without a step; the CSS sets the same sizes.

Each bundled design says how it tightens, with rules under `html.fit-one-page` and `html.fit-one-page-compact`; a rule of a step starts at the root element, so it cannot reach a page that is not tightened. `OnePageFitTests` holds the designs to what they may set (spacing and the layout of lists, never a font size, a width or a transform), to the line height and to the least space they keep between sections and entries, and they read the cascade to hold Modern's first entry of a section flush under its heading in every step. A design without such rules is printed as it lays itself out. The version of a design goes up when its rules change, so that an installed copy is replaced.

### The thumbnails

The template carousel of the export sheet shows the `previewImageBase64` of each bundled package: the first page of the PDF of the example CV, one pixel per point (595 × 842). The test that regenerated it ran in the legacy app's test target, which was deleted with the legacy app (#406), so no test rewrites the thumbnails now. `BundledThumbnailTests` still checks that every thumbnail is a PNG of 595 × 842 pixels. When a design changes, raise its `version`: an installed copy is only replaced by a newer version.

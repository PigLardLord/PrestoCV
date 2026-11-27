# Bundled designs

The `.mcvt` design packages shipped with CVPDFExporter, served as raw bytes through `Bundle.module` (docs/architecture/modules.md).

`professional`, `modern` and `minimal` are written against markup contract 2 (`Docs/markup-contract.md`): a manifest and a stylesheet, no HTML. The builder keeps a section's title with its first entry and ends the document at its last line, whatever a design says (#467): so a design sets no `break-after: avoid` on a title, which neither print path honours, and no bottom padding on `.cv`, which is not printed. The manifest names the design's default palette (`defaultPalette`: `ink`, `slate`, `ocean` or `plum`) and default font scheme (`defaultFonts`: `system`, `serif` or `rounded`), which a CV that makes no choice gets; the gate renders the fixture with the default palette under every font scheme. `minimal` is `ink`, `modern` is `ocean` and `professional` is `slate`, all with `system` fonts: the colours each design had before the manifest named them. Each passes the same `DesignPackageValidator` an installed design does.

To change a design, in this order:

1. **Give a shipped package a new version.** The catalog's sync never replaces an installed design of the same version, so a package that has shipped never changes in place: change `version` in its manifest.
2. **Keep the defaults in step.** A change of look is a new `defaultPalette` or `defaultFonts` in the manifest, with the new version; a palette that is not one of the named ones is refused.
3. **Review the output.** `UPDATE_GOLDEN=1 swift test --package-path CVPDFExporter --filter BundledDesignsRenderingTests` rewrites `design-<name>.html`, the HTML each design produces for the fixture; the diff is the review.
4. **Store the previews** on a Mac, printed by the real renderer: `UPDATE_PREVIEWS=1 swift test --package-path CVPDFExporter --filter BundledDesignsPreviewTests` stores the first page of each design in its package.
5. **Pin the new hash** of each changed file in `BundledDesignsRenderingTests.pins`. It comes last, because the preview changes the file: `sha256sum <file>` on Linux, `shasum -a 256 <file>` on a Mac.

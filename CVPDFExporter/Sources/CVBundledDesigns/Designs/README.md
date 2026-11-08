# Bundled designs

The `.mcvt` design packages shipped with CVPDFExporter, served as raw bytes through `Bundle.module` (docs/architecture/modules.md).

`professional`, `modern` and `minimal` are written against markup contract 1 (`Docs/markup-contract.md`): a manifest and a stylesheet, no HTML. Each passes the same `DesignPackageValidator` an installed design does.

To change a design, in this order:

1. **Give a shipped package a new version.** The catalog's sync never replaces an installed design of the same version, so a package that has shipped never changes in place: change `version` in its manifest.
2. **Review the output.** `UPDATE_GOLDEN=1 swift test --package-path CVPDFExporter --filter BundledDesignsRenderingTests` rewrites `design-<name>.html`, the HTML each design produces for the fixture; the diff is the review.
3. **Store the previews** on a Mac, printed by the real renderer: `UPDATE_PREVIEWS=1 swift test --package-path CVPDFExporter --filter BundledDesignsPreviewTests` stores the first page of each design in its package.
4. **Pin the new hash** of each changed file in `BundledDesignsRenderingTests.pins`. It comes last, because the preview changes the file: `sha256sum <file>` on Linux, `shasum -a 256 <file>` on a Mac.

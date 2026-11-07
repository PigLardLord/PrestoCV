# Bundled designs

The `.mcvt` design packages shipped with CVPDFExporter, served as raw bytes through `Bundle.module` (docs/architecture/modules.md).

`professional`, `modern` and `minimal` are written against markup contract 1 (`Docs/markup-contract.md`): a manifest and a stylesheet, no HTML. Each passes the same `DesignPackageValidator` an installed design does.

- **A change needs a new version.** The catalog's sync never replaces a design of the same version, so change `version` in the manifest and pin the new hash of the file in `BundledDesignsRenderingTests.pins`.
- **Review the output.** `UPDATE_GOLDEN=1 swift test --package-path CVPDFExporter --filter BundledDesignsRenderingTests` rewrites `design-<name>.html`, the HTML each design produces for the fixture; the diff is the review.
- **Previews** are made by the real renderer: `UPDATE_PREVIEWS=1 swift test --package-path CVPDFExporter --filter BundledDesignsPrintedTests` on a Mac stores the first page of each design in its package. That changes the hash: pin it again.

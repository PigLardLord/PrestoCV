# CVPDFExporter

The package of the Design Catalog and Document Rendering context: it turns a CV, given as a `CVDocument`, into a PDF in an installed design. It depends on no other PrestoCV package ([ADR 0002](../docs/architecture/adr/0002-cvpdfexporter-standalone-and-portable.md)), so it can be used on its own, and its portable targets build on Linux and Android as well as on Apple platforms, for a rendering backend.

## Targets

The portable targets, on iOS, macOS, Linux and Android:

- `CVDocumentModel`: `CVDocument`, the package's public contract and the JSON a backend accepts, with its validator.
- `CVDesignCatalog`: the markup contract, the CSS policy, design packages and their validation, palettes and font schemes, and the use cases that list, install, resolve and sync designs.
- `CVDesignCatalogFileStore`: the catalog's store on disk.
- `CVBundledDesigns`: the designs that ship with the package.
- `CVRendering`: the HTML builder, the heading tables, the rendering and inspection ports, and the checks that a PDF holds the whole document.
- `CVBundledHeadings`: the heading tables in each language.

The Apple-only adapters:

- `CVRenderingIOS` and `CVRenderingMacOS`: one PDF renderer per platform, on WebKit ([ADR 0003](../docs/architecture/adr/0003-one-pdf-renderer-per-platform.md)).
- `CVRenderingWebKitSupport`: what both renderers share, the web view's security rules among them.
- `CVRenderingPDFKitInspector`: reads a PDF's pages, text and layout with PDFKit.

`CVRenderingTestSupport` and `CVRenderingNativeTestSupport` hold the test doubles and the contract suites that the tests of each implementation run.

What each target holds, what it may import and the rules it follows are in [docs/architecture/modules.md](../docs/architecture/modules.md).

### The legacy target

`CVPDFExporter` is the exporter that the published app ships, with its HTML templates (see [TEMPLATE_SYSTEM_ARCHITECTURE.md](TEMPLATE_SYSTEM_ARCHITECTURE.md)). It depends on `PrestoCVCore`, is declared only on Apple hosts, and is deleted when the targets above replace it in the app ([ADR 0012](../docs/architecture/adr/0012-legacy-targets-during-migration.md)).

## Contracts

- [Docs/markup-contract.md](Docs/markup-contract.md): the elements and classes a design's stylesheet may target. `MarkupContractPageTests` hold the page to the code.
- [Docs/cv-document.schema.json](Docs/cv-document.schema.json): the JSON Schema of `CVDocument`. `DocumentSchemaTests` hold it to the type in both directions.

## Testing

```bash
swift test --package-path CVPDFExporter
```

On Linux this runs the tests of the portable targets. On macOS it also runs the tests of the Apple adapters (the macOS renderer, WebKit support, the PDFKit inspector) and of the legacy target. The iOS renderer's tests run on the simulator, in the app's `CI` test plan or through the package's `ExporterTests` scheme, which holds the new test targets only.

## Demos

The demos live in a separate package, [CVPDFExporterExamples](../CVPDFExporterExamples), so that this one holds no executables. They use the legacy target and build on macOS only. This one writes a preview image of each bundled template, `<id>_preview.png`, into the given folder:

```bash
swift run --package-path CVPDFExporterExamples CVPDFExporterDemo [output folder]
```

---

## License

Copyright 2026 Giovanni Trovato. Licensed under the Apache License, Version 2.0: see [LICENSE](../LICENSE) and [NOTICE](../NOTICE) at the repository root.

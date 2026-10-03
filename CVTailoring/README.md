# CVTailoring

The CV Tailoring context: it rewrites one CV and writes a cover letter for one job advert, and holds the CV to the source CV, and the letter to the source CV, the advert and the letter defaults. A model writes; a deterministic provenance gate refuses every figure, name, date, employer and technology the source does not state. The decision is [ADR 0013](../docs/architecture/adr/0013-cv-tailoring-context.md).

Like `CVPDFExporter`, it imports no PrestoCV package. In the app, only `PrestoCVIntegration` translates into and out of its model ([ADR 0007](../docs/architecture/adr/0007-each-package-owns-its-model.md)). The server's targets that import it are set by the server's ADR (#158). The tailoring loop runs only on the server. The package builds on iOS, macOS and Linux. Its five targets, their layers and their allowed imports are in [modules.md](../docs/architecture/modules.md). They are empty until the tailoring tickets of #133 fill them.

```bash
swift build --package-path CVTailoring
```

Tests arrive with #135.

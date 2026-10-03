# CVTailoring

The CV Tailoring context: it rewrites one CV and writes a cover letter for one job advert, and holds both to the source CV. A model writes; a deterministic provenance gate refuses every figure, name, date, employer and technology the source does not state. The decision is [ADR 0013](../docs/architecture/adr/0013-cv-tailoring-context.md).

The package imports no other PrestoCV package, and no PrestoCV package imports it except `PrestoCVIntegration`. It builds on iOS, macOS and Linux. Its five targets, their layers and their allowed imports are in [modules.md](../docs/architecture/modules.md). They are empty until the tailoring tickets of #133 fill them.

```bash
swift build --package-path CVTailoring
```

Tests arrive with #135.

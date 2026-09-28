# ADR validation prototype

Throwaway code that validated ADRs 0001–0012 on Linux with Swift 6.3.3. It is not production code and nothing builds it:
- no target of the app or of its packages depends on it;
- the architecture checker maps it as `excluded`.

Each part is ported into the real targets and reviewed there as new code. See "Porting from the validation prototype" in `docs/architecture/README.md`.

| Folder | What it validates | Ported by |
|---|---|---|
| `Exporter/` | Document model, design catalog with the CSS allow-list, typed HTML builder, rendering contract, completeness, install gate | #74, #75 |
| `Core/` | CV Authoring: domain, use cases, schema-v1 file persistence with the store lock and the maintenance port | #85, #86 |
| `Drafting/` | AI Drafting model and ports | #93 |
| `App/` | Workflow ports, integration mappers, the UI-free presentation package | #88 |
| `checker/` | The architecture checker (SwiftSyntax), its rules, baseline and self-test | #66 |

The Apple-only files (`CVRenderingWebKitSupport`, `CVRenderingIOS`, `CVRenderingMacOS`) do not compile on Linux and were never validated. The native renderers are written from scratch (#76–#79).

## Running it

From this folder:

```bash
swift test --package-path Exporter
swift test --package-path Core
swift test --package-path App
swift build -c release --package-path checker && checker/selftest.sh
cd checker && .build/release/ArchitectureCheck .. --rules rules.json --baseline baseline.json \
  --modules ../../../docs/architecture/modules.md --packages Core,Exporter,Drafting,App \
  --adr-dir ../../../docs/architecture/adr
```

`Drafting` has no tests of its own; `App` exercises it.

Results when it was imported (2026-09-28):
- Exporter: 42 tests pass;
- Core: 27 tests pass;
- App: 15 tests pass;
- checker self-test: 95 of 95 cases pass;
- checker: no findings against `docs/architecture`.

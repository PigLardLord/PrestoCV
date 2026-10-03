# 0013. Tailor a CV in a context of its own, behind a provenance gate

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0002](0002-cvpdfexporter-standalone-and-portable.md), [ADR 0005](0005-remove-ai-tailoring-and-json-resume.md), [ADR 0006](0006-enforce-architecture-mechanically.md), [ADR 0007](0007-each-package-owns-its-model.md), R1, R2, R7, R8, R13, issues #133, #134

## Context

- [ADR 0005](0005-remove-ai-tailoring-and-json-resume.md) removed the old tailoring code and reserved CV optimisation as a context of its own. Its design is epic #133.
- The rules come from cv-giovanni, the owner's web-CV project. There, a model rewrites a CV for one advert, and a deterministic check refuses every figure, name, date, employer and technology the source does not state.
- cv-giovanni's code is JavaScript and its model is cv-giovanni's profile. So its rules and its tests are ported, not its code.
- The tailoring must run in the app (advert analysis, checks on a CV the user writes, questions) and on the server (the loop with a model).
- PrestoCV's CV model has a single description per experience, no entry ids and no highlights list.

## Decision

- **A package of its own, `CVTailoring`,** at the repository root.
  - Like `CVPDFExporter`, it imports no PrestoCV package, and no PrestoCV package imports it except `PrestoCVIntegration`. The server's targets are added by the server's ADR.
  - It builds and tests on iOS, macOS and Linux.
- **It owns its model** ([ADR 0007](0007-each-package-owns-its-model.md)): a snapshot of the source CV, the advert and the letter defaults. The app maps its `CV` into it in `PrestoCVIntegration`. The server maps its API types into it.
- **A tailoring produces a CV and a cover letter.**
- **The check is a gate, not an audit.**
  - No field lifts it.
  - A failure goes back to the model at most twice. After that the tailoring fails, with every failure listed.
  - Whatever the advert asks for that the CV does not evidence becomes a question for the user, never a line of the CV.
- **The unit of provenance is a line of an experience's description,** called a statement. Each rewritten line names the lines of the same experience it comes from. PrestoCV's CV model does not change.
- **Any profession.** The checks stay general. Word lists that know a field's names, starting with technologies, are a floor that grows. The check never depends on them.
- **Six languages in the first version:** English, German, Spanish, French, Italian and Portuguese, each one as data (one resource file per language). Any other language is a typed error, never a weaker check that reads as a pass.
- **No translation in the first version.** A CV is tailored in its own language (#147).
- **Errors are typed per check** (R7) and carry codes. Their wording is produced at the edges (R13).
- **Five targets,** with these layers and allowed imports:

| Target | Layer | Holds | May import |
|---|---|---|---|
| `TailoringModel` | domain | the snapshot types (source CV, statements and typed references, tailored CV, cover letter, letter defaults, advert, the six languages, the report and the questions) and the per-language word lists as resources read through `Bundle.module` | Foundation |
| `AdvertAnalysis` | domain | what an advert asks for, and where the CV evidences it; language detection | `TailoringModel`, Foundation |
| `ContentChecks` | domain | spans that stay true, and figures as the CV writes them | `TailoringModel`, Foundation |
| `Provenance` | domain | the gate for the tailored CV and for the cover letter | `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, Foundation |
| `Tailoring` | application | the tailoring loop, its outbound inference port (owned here, R3; adapters live on the server), the prompt, questions and answers | `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, `Provenance`, Foundation |

## Consequences

- **R1** lists four isolated packages: `PrestoCVCore`, `CVPDFExporter`, `CVGeneratorAI` and `CVTailoring`. [modules.md](../modules.md) and the checker's `rules.json` gain the package, and CI builds it on Linux and macOS.
- **The same checks run on the device and on the server.** The date a span is checked against is passed in (R2).
- **A model's reply is untrusted input** (R8). Nothing it writes reaches a CV except through the gate.
- **Costs:**
  - a fourth model of a CV, and one more mapper in `PrestoCVIntegration`;
  - word lists to keep in six languages;
  - reading names in German is open until #142, so German is a typed error in the provenance check until then.
- **Enforced by:**
  - the compiler, through the target graph;
  - the checker: the allow-lists, and the R1, R2, R9, R11, R13 and R14 detectors;
  - the tests that each ticket of #133 adds.

## Alternatives considered

- **Tailoring inside `PrestoCVCore`.** Rejected: the server would carry the authoring package and its persistence, and the contexts would share a model, against [ADR 0007](0007-each-package-owns-its-model.md).
- **Calling cv-giovanni's JavaScript from a Node service.** Rejected by the owner: one Swift core runs on the device, on the server and on a developer's machine, and the rules are ported with their tests.
- **One target for the whole context.** Rejected: the compiler would not keep the domain checks apart from the loop and its port.
- **A check that warns and lets the user override.** Rejected: a tailored CV that states what the source does not is exactly the defect the context exists to prevent.
- **A weaker check for other languages.** Rejected: it would read as a pass.
- **Provenance per whole description.** Rejected: it cannot say which source line backs a rewritten one.

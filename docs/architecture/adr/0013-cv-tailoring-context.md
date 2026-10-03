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
  - Like `CVPDFExporter`, it imports no PrestoCV package. In the app, only `PrestoCVIntegration` translates into and out of its model ([ADR 0007](0007-each-package-owns-its-model.md)). The server's targets that import it are set by the server's ADR (#158).
  - It builds and tests on iOS, macOS and Linux.
- **It owns its model** ([ADR 0007](0007-each-package-owns-its-model.md)): a snapshot of the source CV, the advert, the letter defaults and the user's answers. The app maps its `CV` into it in `PrestoCVIntegration`. The server maps its API types into it.
- **It refines [ADR 0005](0005-remove-ai-tailoring-and-json-resume.md) without superseding it.** This is the context ADR 0005 reserved. The app reaches a tailoring through a port its own workflow owns, as ADR 0005 says; the adapter behind that port calls the server (#179). The inference port is a different port: `Tailoring` owns it, and only the server uses it (#149, #150). **The loop never runs on the device:** no app target may import `Tailoring`. The checker refuses it in `PrestoCVApp`'s sources and manifest, and in the app target's folders once they leave legacy ([ADR 0012](0012-legacy-targets-during-migration.md)).
- **A tailoring produces a CV and a cover letter.**
- **The check is a gate, not an audit.**
  - No field lifts it.
  - A failure goes back to the model at most twice. After that the tailoring fails, with every failure listed.
  - Whatever the advert asks for that the CV does not evidence becomes a question for the user, never a line of the CV.
  - The gate's failures are values with codes. The app words them for the user (R13); the prompt in `Tailoring` words them for the model, from the same codes.
- **The unit of provenance is a line of an experience's description,** called a statement. Each rewritten line names the lines of the same experience it comes from; the user's answers in scope are sources too (#153). PrestoCV's CV model does not change.
- **Any profession.** The checks stay general. Word lists that know a field's names, starting with technologies, are a floor that grows. The check never depends on them.
- **Six languages in the first version:** English, German, Spanish, French, Italian and Portuguese, each one as data, one file per language. The supported languages are exactly the ones that have a file, so adding a language adds a file. Any other language is a typed error, never a weaker check that reads as a pass. The files are resources of `TailoringModel`, one JSON file per language plus an index, read through `Bundle.module` as the rendering's heading tables are (R2, R13). A server image ships the package's resource bundle beside its binary, as it already must for those headings (#136, #162).
- **No translation in the first version.** A CV is tailored in its own language (#147).
- **Errors are typed per context** (R7) and carry codes, never text.
- **Five targets,** with these layers and allowed imports:

| Target | Layer | Responsibility | May import |
|---|---|---|---|
| `TailoringModel` | domain | the snapshot: the source CV, its statements and typed references, the advert, the letter defaults, the questions and answers, the tailored CV, the cover letter and the report; the supported languages and their word lists | Foundation |
| `AdvertAnalysis` | domain | what an advert asks for, where the CV evidences it, and its language; the questions asked before a tailoring | `TailoringModel`, Foundation |
| `ContentChecks` | domain | spans that stay true, and figures as the CV writes them | `TailoringModel`, Foundation |
| `Provenance` | domain | the gate for the tailored CV and for the cover letter | `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, Foundation |
| `Tailoring` | application | the loop, its outbound inference port (R3), the prompt, and the decoding of the model's reply | `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, `Provenance`, Foundation |

## Consequences

- **R1** lists four isolated packages: `PrestoCVCore`, `CVPDFExporter`, `CVGeneratorAI` and `CVTailoring`. [modules.md](../modules.md) and the checker's `rules.json` gain the package, and CI builds it on Linux and macOS.
- **The same checks run on the device and on the server.** The date a span is checked against is passed in (R2).
- **A model's reply is untrusted input** (R8). `Tailoring` decodes it through one anti-corruption layer. Nothing it writes reaches the tailored CV or the letter except through the gate. Its report and its questions reach the user as the model's own words, never as part of the CV or the letter.
- **Costs:**
  - a fourth model of a CV, and mappers in `PrestoCVIntegration` in both directions: the CV into the snapshot, and the result into the app's own types;
  - word lists to keep in six languages;
  - reading names in German is open until #142, so German is a typed error in the provenance check until then.
- **Enforced by:**
  - the compiler, through the target graph;
  - the checker: the allow-lists, applied to the sources and, through `--packages`, to the manifests (R1), which also keep the loop off the device; the R1, R2, R4, R7, R9, R11, R13 and R14 detectors on the five targets; and the language-mode rule on the manifest (R9);
  - the tests that each ticket of #133 adds.

## Alternatives considered

- **Highlights and entry ids in `CV`.** Rejected by the owner: PrestoCV's CV model does not change, and a line of an experience's description is enough to name a source.
- **Tailoring inside `PrestoCVCore`.** Rejected: the server would carry the authoring package and its persistence, and the contexts would share a model, against [ADR 0007](0007-each-package-owns-its-model.md).
- **Calling cv-giovanni's JavaScript from a Node service.** Rejected by the owner: one Swift core runs on the device, on the server and on a developer's machine, and the rules are ported with their tests.
- **One target for the whole context.** Rejected: the compiler would not keep the domain checks apart from the loop and its port.
- **A check that warns and lets the user override.** Rejected: a tailored CV that states what the source does not is exactly the defect the context exists to prevent.
- **A weaker check for other languages.** Rejected: it would read as a pass.
- **Provenance per whole description.** Rejected: it cannot say which source line backs a rewritten one.

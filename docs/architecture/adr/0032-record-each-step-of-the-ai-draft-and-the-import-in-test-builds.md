# 0032. Record each step of the AI draft and the import in test builds

- **Status:** Proposed
- **Date:** 2026-10-28
- **Related:** [ADR 0030](0030-log-through-one-interface-that-carries-no-cv-content.md) (amended), [ADR 0008](0008-single-composition-root.md), [ADR 0009](0009-persisted-schema-v1.md), [ADR 0022](0022-ship-legacy-app-as-v1.md), [ADR 0023](0023-ground-the-ai-draft-in-the-description.md), [ADR 0027](0027-import-a-cv-from-its-text-with-rules.md), [ADR 0028](0028-check-each-personal-claim-of-the-ai-draft-again.md), [R1](../rules.md#r1-packages-are-isolated-contexts-depend-only-along-documented-edges) (amended), [R2](../rules.md#r2-pure-layers-read-no-ambient-state), [R4](../rules.md#r4-one-composition-root), [R17](../rules.md#r17-dependencies-come-in-through-the-initialiser), issues #357, #355, #269

## Context

- **A tester's empty draft cannot be explained.** On 2026-10-28 the maintainer tried build 121.2: from an eight-line description the AI draft kept one job with no title and no duties, and wrote no summary and no skills. The logs of [ADR 0030](0030-log-through-one-interface-that-carries-no-cv-content.md) carry counts and names only, by design, and reading them needs Console on a Mac. So the same empty draft could come from an unavailable model, missing language data, a refusal, an answer that was already empty, a grounding that removed everything, or a claim check that withdrew everything.
- **The evaluation does not cover it.** It runs the model on our own examples on a Mac, not on what a tester typed.
- **The maintainer's direction (2026-10-28):** we must see what happens under the hood on a real device and where the mechanism breaks. The trace is on in TestFlight builds only; it goes through one central chain, built in the composition root with the decorators each environment needs; and in an App Store install it must be certain that no CV content leaks.
- **The App Store binary is the TestFlight binary.** A build setting cannot tell them apart: only the system's record of how the app was installed can, at run time.

## Decision

### 1. A trace of its own, apart from the logs

- **The trace lives in a package of its own, `DiagnosticTrace`**, next to `DiagnosticLogging`. It is the only place where a diagnostic value may hold text. `DiagnosticLogging` keeps its promise that nothing in it can carry CV content.
- **Two ports, not one field kind.** `DiagnosticLogger` stays as it is, with no text field. The trace has its own port, `DiagnosticTracer`: `begin(kind)` opens a run, the run records named steps and finishes with an outcome, `record(_:_:into:)` adds a step to the run whose scope the work is in, and `mirror(_:)` takes a log entry.
- **Its targets:**
  - `DiagnosticTrace`, pure: the values, the port, the decorators (`NoTracer`, `GatedTracer`, `TracingLogger`), the recorder, the gate rule, the document, the summary and the retention rule;
  - `DiagnosticTraceFiles`, an adapter: the store on the device;
  - `DiagnosticTraceDistribution`, an Apple-only adapter: reads how the app was installed;
  - `DiagnosticTraceTestSupport`, for tests.
- **A run is one AI draft or one import of pasted text.** Its steps come from a closed set of names (`input`, `availability`, `languageData`, `request`, `response`, `check`, `removal`, `timing`, `finalDraft`, `event`, `failure`, `truncated`), each with ordered values: a text, a count, a flag, a duration or a token. A text is cut at 32 KB with its length kept, and a run at about 1 MB, past which one `truncated` step counts what was left out.
- **One run holds the whole story.** `TracingLogger` sits in front of the native log and mirrors every log entry into the run the work belongs to (category `draft` to the AI draft, `import` to the import), or into the session's events when the work is in no run. The run is named by a task-local scope with three cases: in a run, in a run that records nothing (begun behind the closed gate; everything it records by kind is discarded), or in none. There is no fallback to the newest run of a kind, so work that does not name its run cannot land in another one. The log entry itself still carries no CV content.

### 2. On only in TestFlight and Debug builds, failing closed

- **A Debug build traces.** The composition root decides it under `#if DEBUG`, so a Release binary has no path to "always on". A launch argument, `-diagnosticsDistribution sandbox|production|unknown`, also under `#if DEBUG`, lets a test run the Release gate with each answer.
- **A Release build traces only for a verified TestFlight install.** The composition root asks `AppTransaction.shared` once per launch, off the main actor. The gate opens only when the transaction is verified and its environment is the sandbox. Production, Xcode, an unverified transaction, an error (an offline first launch), an unknown environment and "not answered yet" all keep it closed. Only `AppTransaction.shared` is called, never `refresh()`, which can ask the person to sign in.
- **A closed gate keeps nothing.** `GatedTracer` drops a run begun while it is closed, to its end, so no CV text is even held in memory. The store makes its folder on its first write, so an App Store install has no `Diagnostics` folder at all.

### 3. Built only in the composition root

- **The modules see the port only.** `CVGeneratorAI` and `PrestoCVImporting` take a `DiagnosticTracer` in their initialisers, with no default (R17), and never know whether a trace is on.
- **Only the composition files** (today `PrestoCV/PrestoCVApp.swift` and `PrestoCV/App/AppEnvironment.swift`, later `PrestoCVComposition`) may import `DiagnosticTraceFiles` or `DiagnosticTraceDistribution`, or make a `TracingLogger`, `GatedTracer`, `TraceRecorder`, `DistributionGate`, `TraceFileStore` or `AppTransactionDistribution`. `Tools/ArchitectureCheck` enforces it with the `compositionOnly` entry of its `rules.json`.
- **The chains, by environment:**
  - Debug: `TracingLogger` in front of the native log; the recorder behind an open gate; the file store behind the recorder;
  - TestFlight: the same chain behind the distribution gate;
  - App Store: the same chain with the gate closed, so nothing is recorded or written.
- **A test runs the real wiring.** It asks the composition root for its chains with each answer of the distribution, and runs an import that carries a marker word: with any answer but the sandbox the store receives nothing and no log entry holds the marker; with the sandbox the trace holds the marker and every step.

### 4. It stays on the device

- **The store** keeps each run in `Library/Application Support/Diagnostics/`, as one JSON document (schema 1, keys sorted, so two runs diff cleanly) and one plain-text summary made by a pure function of the run. It keeps the ten newest runs and the last 200 session events. The folder is excluded from backup, and its files use complete protection, as the CVs do ([ADR 0009](0009-persisted-schema-v1.md)). The exclusion is reapplied and verified at every launch before a write. It is deleted with the app, and a launch whose gate stays closed deletes it too, so that an App Store build over a TestFlight install keeps none of its runs. A run is told apart from another run of its kind by a task-local scope, so that two drafts in flight each keep their own steps.
- **It never slows the draft.** A step is a synchronous enqueue. The files are written by one task off the main actor, which writes only the latest state of each run and replaces each file whole, so a crash leaves the steps up to the last write. A write failure is logged through `DiagnosticLogger` and never reaches the draft.
- **Nothing leaves the device by itself.** A "Share diagnostics" entry, present only while the gate is open, lists the runs, shows the summary with a notice that it holds the text the person typed, and hands the stored files to the system share sheet. The copies to share are the stored bytes, in a temporary folder removed when the sheet closes. The app makes no network request, so the "Data Not Collected" answers stay true.

### 5. What this amends

- **[ADR 0030](0030-log-through-one-interface-that-carries-no-cv-content.md), section 2 ("No CV content, by construction"):** the logs carry no CV content. The trace of a test build may, in its own package, on the device, never in the unified log and never off the device without the person's own act.
- **[ADR 0030](0030-log-through-one-interface-that-carries-no-cv-content.md), section 4 ("Adapters are the backends"):** the trace store is a second kind of sink. It is not an adapter of `DiagnosticLogger`; it receives log entries only through `TracingLogger`, as they are.
- **[R1](../rules.md#r1-packages-are-isolated-contexts-depend-only-along-documented-edges):** the core packages may import `DiagnosticTrace` as well as `DiagnosticLogging`, and only their port targets.

The text of ADR 0030 stays as it was decided.

## Consequences

- **A tester's run can be read step by step:** what was typed, what the model was asked and answered, what each check removed, how long each stage took and what the person saw. A script can compare it with the evaluation's output.
- **The production chain cannot carry CV text into the logs,** by type: the logger has no text field, and the trace is a separate port that a closed gate empties.
- **One more local package**, its entries in `docs/architecture/modules.md` and the checker's `rules.json`, and a file-scoped rule in the checker.
- **CV text sits in plain files on a test device.** Mitigated by the protection class, the backup exclusion, the retention, the notice, and the share being the person's own act.
- **The gate fails closed.** An offline first launch hides the entry until a later launch. A tester must open the app online once.
- **No test can run a real App Store binary.** The production case rests on the gate's unit tests, the wiring test, the folder that is never made, and a UI test that forces each answer. The maintainer's TestFlight build shows the sandbox case.
- **What waits:** the trace points of the PDF import (it adds only the layout stage); the individual grounding rule that removed a value. The steps of the new draft pipeline of #355 (a request and an answer per section, what the sections wrote, the second grounding) are recorded through `DraftTrace` in the pull request that brings the pipeline. Diagnostics for every user (#269) may reuse the share plumbing and the session events, never the trace itself.

## Alternatives considered

- **A content field kind on `DiagnosticLogger`, dropped by every other logger.** The maintainer's first direction. Lost: a redacting decorator and adapters that drop the field are a promise each adapter must keep, while a logger with no text field cannot leak text at all. The central chain is kept: the composition root builds the logger and the tracer together and picks the decorators by environment.
- **The trace in `DiagnosticLogging`.** Lost: the package would no longer be unable to carry CV content, which is ADR 0030's whole point.
- **A build setting or a separate TestFlight scheme.** Lost: the App Store binary is the TestFlight binary.
- **The receipt's file name (`sandboxReceipt`).** Lost: deprecated since iOS 18.
- **Sending the trace to a server.** Lost: it would change the privacy answers and needs a backend; the person's own share is enough for the testers we have.
- **Caches for the store.** Lost: the system may empty it while an investigation runs.

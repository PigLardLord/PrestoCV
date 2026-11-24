# The diagnostic log

The import, the AI draft and the Debug launch of a UI test write what they did to one interface, `DiagnosticLogger`, which carries no CV content ([ADR 0030](architecture/adr/0030-log-through-one-interface-that-carries-no-cv-content.md)). In the app, the entry point sends every entry to the unified log of the device, under the subsystem `com.PigLardLord.prestocv`. This page says how to read that log, what it holds, and how to add a line to it.

## Reading the log

**On a Mac, from a device or a simulator:**
- Open Console, choose the device, and filter on `subsystem:com.PigLardLord.prestocv`.
- Console hides info and debug entries until you turn them on: Action menu, then Include Info Messages and Include Debug Messages.
- From Terminal, for a booted simulator:

  ```bash
  xcrun simctl spawn booted log stream --level debug --predicate 'subsystem == "com.PigLardLord.prestocv"'
  ```

**From a tester's device:**
- **A sysdiagnose:** the tester presses both volume buttons and the side button together for about a second. A few minutes later it is in Settings, Privacy & Security, Analytics & Improvements, Analytics Data, under a name that starts with `sysdiagnose_`, and the tester can send it.
- **With the device connected to a Mac:**

  ```bash
  sudo log collect --device --last 1h --output prestocv.logarchive
  log show prestocv.logarchive --info --debug --predicate 'subsystem == "com.PigLardLord.prestocv"'
  ```

**What the device keeps:** notice, error and fault entries are written to disk, so a sysdiagnose has them. Info entries stay in memory for a short while, and debug entries only reach a live stream. So anything a tester has to be able to send us is logged as a notice or above.

**Two formats, until the migration ends:** the legacy code still calls `os.Logger` directly, under the same subsystem and under `CVPDFExporter` for the exporter. Those lines read differently, and move to the interface with their code.

## What a line holds

Each entry is one line: its event, then its fields as `key=value`, in order. Console shows it as it is, with nothing hidden as `<private>`, because nothing private can reach it:

```
import.finished kind=pdf pages=2 characters=3120 sections=6 elapsed=412.6ms
```

**The event** is a `StaticString` written in code, such as `import.finished`: interpolating a value into it does not compile.

**The fields** are of a closed set of kinds:

| Kind | What it holds | Written as |
|---|---|---|
| `count` | an integer, such as the sections read | `sections=6` |
| `duration` | a `Duration`, measured with a `Stopwatch` on the injected clock | `elapsed=412.6ms` |
| `flag` | a Bool | `available=false` |
| `token` | a `StaticString` chosen in code, such as a case name the caller spells out | `kind=pdf` |
| `identifier` | a UUID, which says nothing about the person | `cv=6F1C…` |
| `error` | the type of an error, and its `logCode` when it conforms to `LoggableError`; never its description, which can hold the text that failed | `error=ImportError.noText` |

A new kind is reviewed for what it can carry, and added to the list of ADR 0030.

## The levels

| Level | Unified log | When |
|---|---|---|
| `debug` | debug | Detail for a live session. The device does not keep it. |
| `info` | info | A step finished, with counts and time. |
| `notice` | default | A decision the person would notice: a section not recognised, a claim withdrawn, the model unavailable. |
| `error` | error | A failure the person sees. |
| `fault` | fault | A state that should be impossible. |

One example of each. The first and the last are not in the code yet:

```swift
logger.debug(.importing, "import.columns", .count("columns", 2))
logger.info(.importing, "import.finished", .token("kind", "text"), .count("sections", 6), .duration("elapsed", stopwatch.elapsed))
logger.notice(.draft, "draft.claims", .count("checked", 4), .count("withdrawn", 1), .flag("unchecked", false))
logger.error(.importing, "import.failed", .token("kind", "pdf"), .error(error), .duration("elapsed", stopwatch.elapsed))
logger.fault(.draft, "draft.stage", .token("stage", "result"))
```

## What the app logs

The tables list every event the code writes; the source checks fail when the code and this page disagree.

### The import (category `import`)

| Event | Level | Fields | When |
|---|---|---|---|
| `import.file.notRead` | error | `reason` (`notReceived`, `noIdentity` or `releasedDuringRead`), or `error` (`notTheFile`, or a system error by name, such as `ENOENT`) | The file the person chose could not be read: the screen never received it, its identity could not be taken when it came, the path no longer names that regular file, or it was let go while it was read. The import then fails with `fileNotRead`. |
| `import.file.releasedAgain` | notice | none | A file was let go twice, or one never received was let go; nothing else happens. |
| `import.file.copyNotDeleted` | error | `error` (`notTheFile`, `leftAside`, or a system error by name) | A copy the system made of the chosen file, in one of the app's copy folders, could not be deleted when the last import of that file ended. One line per copy. |
| `pdf.read` | info | `pages`, `words` | PDFKit read the words of a PDF's pages. |
| `pdf.limit` | notice | `limit` | The PDF reader stopped at a bound of the reading: `bytes`, `pages`, `characters` or `words`. It throws that bound as a `LimitReached`, so `import.failed` names it too. |
| `import.sections` | info | one count per kind of section recognised, such as `experience=2` | The text was read into sections. |
| `import.unrecognised` | notice | `headings`, `unplaced` | A heading the vocabulary does not know, or text that no rule placed. |
| `import.finished` | info | `kind` (`pdf` or `text`), `pages` (a PDF only), `characters`, `sections`, `elapsed` | The draft is ready for the review. |
| `import.failed` | error | `kind`, `error`, `limit` (when a bound was reached, whether the core or the PDF reader found it: `bytes`, `pages`, `characters`, `words`, `lines`, `cells` or `steps`), `elapsed` | The import failed, and the person is told why. |
| `import.cancelled` | info | `kind`, `elapsed` | The screen went away while the import ran. |

The `import.file.*` events name no path and no file name: a file is only ever described by what happened to it.

The AI screen reads every text with the import before it asks for a draft ([ADR 0034](architecture/adr/0034-read-a-text-that-is-already-a-cv-with-the-import.md)), so the import's events, with `kind=text`, come before the draft's. When the import fails, or reads a text that is not a CV, the person is not told and the AI draft starts; the diagnostics of a TestFlight install then list a CV import before the AI draft.

### The AI draft (category `draft`)

A draft ends with one of `draft.finished`, `draft.cancelled`, `draft.refused`, `draft.rejected` or `draft.failed`; one asked for while the model cannot run ends with `draft.unavailable`.

| Event | Level | Fields | When |
|---|---|---|---|
| `draft.availability` | info, notice when not available | `available`, `reason` (when not available) | Whether the model can run: the first availability each AI draft use case reads, and each change after that. The app builds two use cases (the one that decides whether the AI draft is offered, and the AI screen's), so a launch can log the same availability twice, once from each. |
| `draft.unavailable` | notice | `reason` | A draft was asked for while the model cannot run. |
| `draft.rejected` | notice | `check` (`request`, `language` or `result`), `error`, `elapsed` (a result only) | The description broke a rule of the request, the device lacks the language data that grounding it needs (`draft.language` shows which), or the draft left after the checks broke a rule of the validation. |
| `draft.language` | info, notice when the data is missing | `supported`, `language` (when supported), `data` (`notNeeded`, `present` or `missing`) | The language of the description, and the device's language data that grounding it needs. |
| `draft.languageData` | info, notice when the data did not come | `outcome` (`available`, `notAvailable` or `cancelled`), `elapsed` | After a `draft.rejected` with `check=language`, the app asked the system for the missing data and waited for it, a minute at most. `available` is followed by a second draft; `notAvailable` means the system said no or the minute passed (`elapsed` tells which); `cancelled` means the person left first. |
| `draft.started` | info | `characters` | The model was asked. |
| `draft.retried` | notice | `stage` (`model` for the facts, `writing` for a section), `error` | A request of the model failed below the model (`serviceFailed`) and is tried once more ([ADR 0031](architecture/adr/0031-let-the-ai-draft-write-around-the-facts.md)). |
| `draft.written` | info | `summary`, `roles` (the jobs given duties), `technologies`, `softSkills` | What the requests of the sections wrote around the facts and their checks kept, before the final check reads it ([ADR 0031](architecture/adr/0031-let-the-ai-draft-write-around-the-facts.md), "A request per section"). |
| `draft.unwritten` | notice | `step` (`attribution`, `jobs`, `skills` or `summary`), `error` | A step after the facts failed or ran out of time: the draft keeps the facts and what the earlier requests wrote, and asks nothing more. |
| `draft.claims` | info, notice when one was withdrawn | `checked` (the personal items put to the check), `withdrawn`, `unchecked` (the check gave no answer, so every item is withdrawn and left blank) | The claim check judged the personal items ([ADR 0028](architecture/adr/0028-check-each-personal-claim-of-the-ai-draft-again.md)). |
| `draft.finished` | info | `elapsed` | The draft is ready. |
| `draft.refused` | notice | `elapsed` | The model's guardrails refused the description. |
| `draft.cancelled` | info | `stage`, `elapsed` | The person left, or asked again, while the draft was written. |
| `draft.failed` | error | `stage` (`model`, `grounding`, `claimCheck` or `result`; a first pass that runs out of time fails at `model` with `generationFailed`), `error`, `elapsed` | A step failed. |

### The launch of a UI test (category `launch`, Debug builds only)

| Event | Level | Fields | When |
|---|---|---|---|
| `launch.seedFailed` | error | `files` (the CV files the test handed over), `error` | The CV files a UI test hands over could not be written into the new storage folder (they are written beside it and moved to it when every file is there, so no half-seeded folder is left), so the test starts without them. |

### The trace store (category `trace`, TestFlight and Debug builds only)

| Event | Level | Fields | When |
|---|---|---|---|
| `trace.writeFailed` | error | `error` (`write`) | A run or the session's events could not be written to the device. The draft or the import goes on. |
| `trace.readFailed` | error | `error` (`corruptRun` or `write`) | A stored run or the session's events did not read back, or the folder could not be listed; the run is left out of the list. |
| `trace.shareFailed` | error | `error` (`share`) | The copies of a run to share could not be made or removed. |

### The designs (category `designs`)

Every launch brings the designs that ship with the app into the design store before the first screen, and renders a design only when it is new or changed. The first launch renders the three bundled designs; a launch after it renders none.

| Event | Level | Fields | When |
|---|---|---|---|
| `designs.synced` | info, notice when a design was left out | `installed`, `upgraded`, `unchanged`, `adopted`, `repaired` (a bundled design the store listed but could not read, written again), `rejected` (the package was not valid), `notRendered` (the test render failed), `failed` (the store could not save it), `conflicts` (a design the app did not install holds its id), `elapsed` | The bundled designs were synced into the store. A design left out does not stop the launch while the store still gives the default design. |
| `designs.syncFailed` | notice | `reason` (`bundledDesignsUnavailable` or `designStoreUnavailable`), `elapsed` | The bundled designs or the store could not be read, so nothing was synced; the launch goes on with the designs installed before, if the default design is among them. |
| `designs.interrupted` | info | `elapsed` | The launch was cancelled during the sync or while the store was read. The designs saved before it stay saved, so the next launch does not render them again. |
| `designs.unreadable` | notice | `leftOut` (the designs the store lists but cannot read), `elapsed` | Installed designs the store could not read were left out of the launch; the launch goes on with the others. |
| `designs.unavailable` | error | `failure` (`bundledDesignsUnavailable` or `designStoreUnavailable`), `elapsed` | The store gives no default design, so the launch fails with this code. |

### The share of an export (category `export`)

The export sheet writes the PDF to a file of its own for the system's share sheet, and removes it when the share sheet closes. When the app starts, it removes what an earlier launch left.

| Event | Level | Fields | When |
|---|---|---|---|
| `export.share.notWritten` | error | `error` (`notAName`, `noSpace`, `noPermission`, `readOnly`, `notFound` or `other`) | The file of a share could not be written, so the share sheet does not open. |
| `export.share.notRemoved` | error | `of` (`share` or `leftover`), `error` | The folder of a share, or one an earlier launch left, could not be removed; the next launch tries again. |

The `export.share.*` events name no path and no file name: the file's name holds the person's name.

## The trace of a test build

A TestFlight or Debug build also keeps a **trace**: each step of every AI draft and every import of pasted text, with the text it read and wrote ([ADR 0032](architecture/adr/0032-record-each-step-of-the-ai-draft-and-the-import-in-test-builds.md)). It is not this log: it lives in its own package, `DiagnosticTrace`, and never goes to the unified log.

- **When it is on:** in a Debug build, and in a Release build installed from TestFlight, which the app checks once per launch with `AppTransaction`. An App Store install, an unverified record, an offline first launch and an unknown answer all leave it off; the app then writes no file and makes no folder. A Debug build takes `-diagnosticsDistribution sandbox|production|unknown` to run the Release check with one answer.
- **What a run holds:** the input, then steps named from a closed set (`input`, `availability`, `languageData`, `request`, `response`, `check`, `removal`, `timing`, `finalDraft`, `event`, `failure`, `truncated`). Every entry of this log written while a run of its kind is open (`draft` for the AI draft, `import` for the import) appears in it as an `event` step, with the same line; the others go to the session's events.
- **What an AI draft's run holds, in order:** `input` (the description), `availability` and `languageData`; the `request` and `response` of the first pass (`call=draft`) and a `response` with `stage=model`, the draft it wrote; a `removal` with `stage=grounding`, what the rules took out of those facts; for each request of a section ([ADR 0031](architecture/adr/0031-let-the-ai-draft-write-around-the-facts.md)) a `request` and a `response` named by `call` (`job`, with its `role`, `jobRepair`, `tools`, `softSkills`, `moreSkills`, `summarySentence`, `summarySentenceRepair`), whose answer is the raw one, or `answered=false` with the error when there was none; a `response` with `stage=writing`, the summary, the duties of each job and the skills their checks kept (`wrote=false` when there was nothing to write around); a second `removal` with `stage=grounding`, what the final grounding changed or added to the facts with that writing around them; the `check` and the `removal` of the claim check; the `removal` of the result; `timing`, where `grounding` is the sum of both runs; and `finalDraft`. A draft that stops adds a `failure` and its `timing`. The log of the same draft carries none of the text.
- **Where it is:** `Library/Application Support/Diagnostics/` in the app's container: per run `run-<time>-<kind>-<id>.json` and the same name in `.txt`, a summary a person can read; and `session-events.json`. The ten newest runs and the last 200 session events are kept. The folder is excluded from backup (set again, and checked, at every launch before a file is written, so a folder an earlier launch left is covered; a failure writes nothing) and deleted with the app. A launch whose gate stays closed (an App Store build over a TestFlight install, or an answer that did not arrive) deletes the folder and the share copies. The share copies (`Share/`) hold the run's JSON and summary and the session events, with complete protection; the ones a launch finds are removed, and a copy that fails to write is removed with the rest.
- **Reading it:** the "Share diagnostics" button at the top of the CV list, shown only while the trace is on, lists the runs and previews the summary; its share button hands the two files of a run to the system share sheet, for example to AirDrop them to a Mac. Nothing leaves the device otherwise. On a simulator, the files are in the app's data container (`xcrun simctl get_app_container booted com.PigLardLord.prestocv data`).
- **Adding a step:** a type that traces takes an `any DiagnosticTracer` in its initialiser, with no default value (R17), and records with a step name and fields: `.text`, `.count`, `.flag`, `.duration` and `.token`. A test passes a `RecordingTracer`, from `DiagnosticTraceTestSupport`, and a preview a `NoTracer`.

## Adding a line

1. **Declare the category once**, in the module that owns the flow, if it has none: `extension LogCategory { static let export = LogCategory("export") }`. A module that is a step of the same flow, as the PDF reader is of the import, logs under the category of the module it serves (`public` there) and declares none; a source check fails when two files declare one name.
2. **Take the logger in the initialiser**, as `any DiagnosticLogger`, with no default value (R17). The composition root passes the one it made (R4); a test passes a `RecordingLogger`, and a preview a `SilentLogger`.
3. **Write the event with a shorthand**, and fields of the kinds above: a case name becomes a `token` through a `switch` that spells it out, and an error conforms to `LoggableError`.
4. **Test it** with `RecordingLogger` and `TickingClock`, from `DiagnosticLoggingTestSupport`: the event, its level and its fields; and, once per module, that a word put in the CV appears in no line.
5. **Add the event to the tables above.**

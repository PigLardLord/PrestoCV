# 0030. Log through one interface that carries no CV content

- **Status:** Accepted
- **Date:** 2026-10-25
- **Related:** [ADR 0002](0002-cvpdfexporter-standalone-and-portable.md), [ADR 0008](0008-single-composition-root.md), [ADR 0012](0012-legacy-targets-during-migration.md), [ADR 0022](0022-ship-legacy-app-as-v1.md), [ADR 0026](0026-keep-the-core-portable-to-android.md), [ADR 0028](0028-check-each-personal-claim-of-the-ai-draft-again.md), [R4](../rules.md#r4-one-composition-root), [R14](../rules.md#r14-no-dead-code-no-demos-in-libraries-no-test-doubles-in-production), [R17](../rules.md#r17-dependencies-come-in-through-the-initialiser), [R18](../rules.md#r18-pure-targets-stay-portable-to-android), issue #270

## Context

- **The rules already ask for an injected logger, and none exists.**
  - R14 says that logging goes through an injected logger and that there is no `print`.
  - R4 and [ADR 0008](0008-single-composition-root.md) put the logger in the composition root, next to the clock and the identifier generator.
  - [ADR 0002](0002-cvpdfexporter-standalone-and-portable.md) asks the same of the exporter.
  - No target declares a logger port.
- **The new code logs nothing.** `PrestoCVImporting` and `PrestoCVImportingPDFKit` read every CV that version 1 imports, and write no log line.
- **The AI draft logs nothing either.**
  - In version 1 it runs in the legacy target `CVGeneratorAI` ([ADR 0022](0022-ship-legacy-app-as-v1.md)), and `CVDrafting` is still empty.
  - The draft depends on things a tester cannot see: whether the model is available and why not, the language data (#270), the guardrails, and the claims withdrawn ([ADR 0028](0028-check-each-personal-claim-of-the-ai-draft-again.md)).
  - When a TestFlight tester reports a bad draft, nothing tells us which of these happened.
- **The legacy code calls `os.Logger` directly**, in eleven places:
  - the app and `PrestoCVCore` use the subsystem `com.PigLardLord.prestocv`;
  - the legacy exporter uses the subsystem `CVPDFExporter`.
  These calls cannot run on Linux or Android ([ADR 0026](0026-keep-the-core-portable-to-android.md)), and no test sees them. Changing where logs go would mean finding and rewriting every call.
- **A CV is personal data.** The values that `os.Logger` interpolates are private by default: Console shows them as `<private>`, so these logs are hard to read. Making them public would put names, employers and dates in logs that testers send to us.
- **The owner's direction (2026-10-25):** the logger is an interface, with decorators. Then a crash-reporting service, the native log or a logger of our own can be swapped in "with little effort, without having to replace or track down every log".

## Decision

### 1. One interface, in a small package of its own

A new package, `DiagnosticLogging`, depends on no other package. Its targets:

| Target | Kind | Platforms | May import |
|---|---|---|---|
| `DiagnosticLogging` | port, value types, decorators | iOS, macOS, Linux, Android | Foundation |
| `DiagnosticLoggingOSLog` | outbound adapter | iOS, macOS | `DiagnosticLogging`, `os` |
| `DiagnosticLoggingTestSupport` | test support | all | `DiagnosticLogging`, Foundation, Synchronization |

`PrestoCVCore`, `CVPDFExporter` and `CVGeneratorAI` may depend on `DiagnosticLogging`, and only on that target.
- This edge is the one exception to "no edge between the three packages". It is a leaf: it has no product types and depends on nothing, so the exporter stays reusable on its own ([ADR 0002](0002-cvpdfexporter-standalone-and-portable.md)).
- The protocol is named `DiagnosticLogger`, not `Logger`, so that it clashes with neither `os.Logger` nor swift-log's `Logger`.

```swift
public protocol DiagnosticLogger: Sendable {
    func log(_ entry: LogEntry)
}

public struct LogEntry: Sendable {
    public let level: LogLevel        // debug, info, notice, error, fault
    public let category: LogCategory  // "import", "draft", "export", …
    public let event: StaticString    // "import.finished"
    public let fields: [LogField]
}
```

- **Call sites** use the shorthands of a protocol extension, for example `logger.info(.importing, "import.finished", .count("sections", 6), .duration("elapsed", elapsed))`.
- **`log` is synchronous.** It never throws, and it never waits on I/O. An adapter that writes somewhere slow buffers the entries itself.
- **Each module declares its category once**, as a constant.

### 2. No CV content, by construction

- **The event is a `StaticString`.** Interpolating a value into it does not compile.
- **Fields are a closed set of kinds:**
  - `count` (an integer);
  - `duration`;
  - `flag` (a Bool);
  - `token` (a `StaticString` chosen in code, such as a case name the caller spells out);
  - `identifier` (a UUID, which says nothing about the person);
  - `error`.
- **An error is logged by its type**, plus its `logCode` when it conforms to `LoggableError`. Its description is never logged, because it can contain the text that failed.
- **A new field kind is reviewed for what it can carry**, and added to this list.

So a log line can be read in Console as it is, sent by a tester, or sent to any future backend, without showing anyone's CV.

### 3. Decorators and composites implement the same interface

- **`FanOutLogger([…])`** sends each entry to several loggers, for example the native log and a crash-reporting service at once.
- **`MinimumLevelLogger(minimum:next:)`** drops the entries below a level, for example to keep debug entries out of a remote service.
- **`SilentLogger`** discards everything, for previews.

A new behaviour is one more type that wraps another logger, such as sampling, adding the build number, or keeping the last entries in memory. The modules never know which chain they write to.

### 4. Adapters are the backends

- **Version 1 has one adapter: `OSLogDiagnosticLogger(subsystem:)`**, created with `com.PigLardLord.prestocv`.
  - It keeps one `os.Logger` per category, and maps the levels one to one.
  - It writes the event followed by `key=value` pairs, with `privacy: .public`. It can do that because nothing private reaches it.
  - The text is built by a pure function, which is tested on Linux.
- **Later backends are one adapter each, and each one is its own decision:**
  - an in-memory ring buffer, for a "Copy diagnostics" button that a tester can paste into feedback;
  - a bridge to swift-log on the server;
  - a crash-reporting service. A service such as Crashlytics sends data off the device and changes the privacy answers in App Store Connect, so it needs its own ADR.

### 5. The logger is injected, and made in one place

- **A type that logs takes a `DiagnosticLogger` in its initialiser**, with no default value (R17).
- **Only the composition root creates adapters and assembles the chain** (R4).
- **In version 1, the legacy app's entry point creates it once**, and the existing factory passes it to the import and to the AI draft. The construction moves into `PrestoCVComposition` with the app.

### 6. What version 1 logs: decisions and failures, not every step

**The levels:**
- `debug`: detail for a live session. The system does not keep it.
- `info`: a step finished, with counts and time.
- `notice`: a decision the user would notice, such as a section not recognised, a claim withdrawn, or the model unavailable.
- `error`: a failure the user sees.
- `fault`: a state that should be impossible.

**The import** (`PrestoCVImporting`, `PrestoCVImportingPDFKit`):
- the kind of file, its pages and characters read, and the time taken;
- an extraction failure, by kind;
- the sections recognised, by kind and count;
- the headings not recognised, and the lines left unplaced, as counts;
- a limit of the bounded reading reached.

**The AI draft** (legacy `CVGeneratorAI`):
- availability, and the reason it is not available;
- whether the language of the description is supported, and the state of its language data (#270);
- a generation started, finished or cancelled, and its time;
- guardrail refusals;
- the claims checked and the claims withdrawn, as counts;
- validation rejections, by rule.

This is the one legacy target that gets the interface before submission: it has no log at all, and it is where testers' problems are hardest to see.

**Export and the rest of the legacy code** keep their direct `os.Logger` calls, which are frozen with the legacy code ([ADR 0022](0022-ship-legacy-app-as-v1.md)). Each call moves to the interface when its code moves to the new targets.

### 7. Reading the logs

- **On a Mac:** connect the device, open Console and filter on `subsystem:com.PigLardLord.prestocv`. To see info and debug entries, turn them on in the Action menu.
- **From a tester's device:** a sysdiagnose, or `log collect` on a Mac with the device connected.
- **How to add a log line:** a short guide in the repository's docs gives the levels, the field kinds and one example per level.

## Consequences

- **Changing where logs go means changing the chain in one place.** No call site changes, and neither does the core.
- **Logs are testable.**
  - `RecordingLogger`, in `DiagnosticLoggingTestSupport`, records entries under a `Mutex`.
  - The import and draft tests check that the key events are logged.
  - They also feed a CV holding a marker word, and check that the marker appears in no entry.
- **Logs can be shared safely**, and they read in Console without a private-data profile.
- **The same interface runs on Linux, Android and the future server.**
- **A log line cannot carry a free value.** When one is needed, a new field kind is added after review. This friction is deliberate.
- **The checks:**
  - the allow-lists give `os` to `DiagnosticLoggingOSLog` only; R18 already refuses it in pure targets;
  - `Logger` is added to `dependencySuffixes`, so a default logger argument is refused (R17);
  - `OSLogDiagnosticLogger` is added to `infrastructureTypes`, so only the composition root creates it (R4);
  - the `printing` detector stays;
  - the Linux and Android jobs build `DiagnosticLogging`, and the Linux job also runs its tests.
- **[modules.md](../modules.md) gains the package**, its targets, its edge in the graph and its exception to the forbidden edges, in the pull request that builds it.
- **Two styles live side by side until the migration ends.** The eleven legacy `os.Logger` calls stay, under their two subsystems, and are listed for the migration.
- **The cost:**
  - one small package, about three hundred lines plus tests;
  - one more local package linked by the Xcode project;
  - the log lines in two flows.
- **Each entry is built even when a decorator drops it.** This costs little, because the code logs decisions, not loops.

## Alternatives considered

- **`os.Logger` directly, as the legacy code does.**
  - It is native and fast.
  - It cannot run on Linux or Android, no test sees it, and changing the backend means rewriting every call: what the owner wants to avoid.
- **swift-log as the interface.** It is the standard API on Swift servers. It has many backends, and a multiplexing handler.
  - Its messages and metadata take any string, so nothing keeps CV text out.
  - Its global bootstrap invites a process-wide singleton (R4).
  - It would be a third-party dependency in every package.
  - It remains the natural backend on the server, through an adapter.
- **One logging port per package**, as each package owns its own model.
  - No package would share a dependency.
  - But there would be three copies of the same port, and the decorators would be written three times or bridged three times.
- **A typed event enum per module**, mapped to entries in the integration layer.
  - It is the strongest typing.
  - But every new log line needs a case and a mapping. With that friction, fewer lines get written, and debugging should stay simple.
- **A crash-reporting service now.** Apple's crash reports already reach Xcode Organizer and TestFlight without an SDK. A service that sends data to a third party is a separate decision, and this interface makes it one adapter.
- **Everything now, the legacy code included.** The owner chose against it on 2026-10-25. It touches code that will be deleted, and it puts the submission date at risk.

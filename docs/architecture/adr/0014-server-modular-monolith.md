# 0014. Run the server as a modular monolith in two roles

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0002](0002-cvpdfexporter-standalone-and-portable.md), [ADR 0006](0006-enforce-architecture-mechanically.md), [ADR 0007](0007-each-package-owns-its-model.md), [ADR 0008](0008-single-composition-root.md), [ADR 0013](0013-cv-tailoring-context.md), R1, R4, R14, issues #133, #158

## Context

- The app tailors a CV to an advert with a model ([ADR 0013](0013-cv-tailoring-context.md)). The loop never runs on the device, so a server runs it, and the server holds the model providers' keys.
- It is one developer's project. There are no separate teams, and the budget is zero.
- The server runs on Cloud Run, which gives an instance CPU only while it handles a request. A tailoring cannot run after its response has gone.
- iOS suspends an app in the background, so the app cannot wait on one request until the tailoring ends.
- The server is a second executable in this repository. Two rules were written for the app alone:
  - [ADR 0008](0008-single-composition-root.md) and R4 say there is one composition root;
  - R1 and [ADR 0007](0007-each-package-owns-its-model.md) say that translation between contexts happens only in `PrestoCVIntegration`.
- The owner decided on 2026-10-02 (#158) the language and framework, the modular monolith, the two roles and services, the profiles, the environments and one composition root per executable. The split into targets, the worker's route and the per-role router, the log port, and the wording of R1 and R4 are this ADR's own architecture. cv-giovanni is a separate project and out of scope.

## Decision

- **Swift, on Hummingbird 2.** It is the language of the app and of its packages, so `CVTailoring` and `CVDocumentModel` run on the server unchanged. Hummingbird is built on Swift concurrency, and a server imports only the parts it uses.
- **A modular monolith.** One package in this repository, the `PrestoCVServer` package. Its modules are targets, and the compiler and the checker hold their boundaries, as in the app. There are no microservices.
- **One binary, two roles, two services.** `serve` answers the API and `work` runs tailorings. Hosted, each role runs as its own Cloud Run service, and both are built from one image.
  - The API records the job and hands it to a managed queue, Cloud Tasks. The queue calls the worker, the tailoring runs inside that request, and the queue retries it with backoff.
  - The worker is private. Only the queue's identity, which the erasure schedule (#166) also uses, may call it, and the platform refuses everyone else before any code runs (#161).
  - The route the queue calls to run a job lives in `ServerHTTP`. It is mounted only in the `work` role, and it is not part of the public API (`openapi.yaml`). The executable composes the router per role.
  - Only the worker holds the model providers' keys.
  - A tailoring finishes within the queue's dispatch deadline of 30 minutes. The tailoring's own time limit is set below it (#152, #161).
- **Two profiles, `hosted` and `local`.** A profile is a set of adapters that the composition root picks from configuration. The local profile is for development only. It uses in-memory stores and an in-process queue, runs both roles in one process, and refuses to start on any address but 127.0.0.1.
- **Three environments: `local`, `staging` and `production`.**
  - `local` uses the local profile. `staging` and `production` use the hosted profile, each with its own configuration, database and queue.
  - Staging accepts App Attest's development environment, so a build from Xcode can be tried on a device. Production accepts only the production environment.
  - How a change reaches each environment belongs to the infrastructure layer of #133.
- **One composition root per executable.** R4 says "one per executable". The app's root is `PrestoCVComposition`. The server's root is the `PrestoCVServer` executable target. Each root is the only code that creates infrastructure. The local profile runs both roles from one root, in one process.
- **Seven targets,** all Linux ✓, and macOS for development:

| Target | Layer | Responsibility |
|---|---|---|
| `ServerApplication` | application | The tailoring use cases and the job lifecycle (#157), and their ports, among them the job store, the job queue, the quota and the clock |
| `ServerInference` | outbound adapter | The inference providers behind `Tailoring`'s port, and the deployment's data policy (#154, #155) |
| `ServerStorePostgres` | outbound adapter | The job store and the quota store on Postgres (#160) |
| `ServerQueueCloudTasks` | outbound adapter | The job queue on Cloud Tasks (#161) |
| `ServerLocalProfile` | outbound adapter | The in-memory stores and the in-process queue of the local profile (#157, #158) |
| `ServerHTTP` | inbound adapter | The routes and middleware, mapping the generated API types to the use cases (#175, #178), and the route the queue calls |
| `PrestoCVServer` | executable and composition root | The roles, the profiles and the configuration |

- **Invariants.** They hold whatever targets are added:
  - `ServerApplication` imports only `CVTailoring` targets and Foundation: no external package and no adapter.
  - Only `ServerHTTP` imports the targets of `PrestoCVAPI`, and it imports them with `internal import`, so the generated types cannot leave it.
  - Only the `PrestoCVServer` executable target creates infrastructure.
  - Nothing in the package imports `PrestoCVApp` or `PrestoCVCore`.
- **[modules.md](../modules.md) holds the allow-lists and is authoritative.** Tickets extend them there, without a new ADR, while these invariants hold. The authentication, logging and notification targets are set by the decisions of their own tickets (#167, #168, #180).
- **External packages** are imported only by adapters and by the executable, never by `ServerApplication`. Each is pinned in the committed `Package.resolved`. A new one changes modules.md in the same pull request, so the checker's `--packages` rule holds it ([ADR 0006](0006-enforce-architecture-mechanically.md)).
- **Logging.** `ServerApplication` declares its own port for log events: typed events, never a CV, a prompt or a key (#167). The executable bridges the port to swift-log. The adapters log through an injected `Logger` once the tickets that add logging and metrics (#167, #178) extend their allow-lists with `Logging` and `Metrics` in modules.md.
- **Translation.** On the server, the API's generated types are translated to and from the tailoring model only in `ServerHTTP`, and never leave it (#175). A translation between two context packages on the server lives in a server target that modules.md names, or needs an ADR.
- **The package depends on `CVTailoring`** (and on `PrestoCVAPI` once #177 exists). It never depends on `PrestoCVApp` or `PrestoCVCore`. It may depend on the Linux targets of `CVPDFExporter` and of `CVGeneratorAI` (`CVDrafting`), which are reusable on a backend ([ADR 0002](0002-cvpdfexporter-standalone-and-portable.md)). The ticket that needs such an edge adds it to modules.md, for example #94 or #196. `PrestoCVAPITypes` and `PrestoCVAPIServer` are targets of the `PrestoCVAPI` package (#175).

## Consequences

- **R1 and R4 change.** R4 reads "One composition root per executable". R1 gains a rule for the API's generated types, which only `ServerHTTP` translates and which never leave it. R1 also says the `PrestoCVServer` package is an integration and composition package, as `PrestoCVApp` is, not one of the isolated context packages.
- **[ADR 0007](0007-each-package-owns-its-model.md) and [ADR 0008](0008-single-composition-root.md) stay in force for the app.** This ADR extends them to the server and supersedes neither.
- **modules.md lists the seven targets now.** They are created when the repository has been published (#132), under #158 and the tickets named in the table. Until the targets exist, the checker's `rules.json` declares them not yet implemented.
- **Costs:**
  - two services to deploy from one image, and a queue between them;
  - the 30-minute dispatch deadline bounds a tailoring;
  - a second composition root to read;
  - a local profile with adapters of its own, which must behave as the hosted ones do. They are adapters of a profile the executable ships, not test doubles (R14). The contract suites of #157 keep them honest: each adapter passes the suite of its port. `ServerApplication`'s own tests use these adapters, so there is no second copy of them.
- **Enforced by:**
  - the compiler, through the target graph, and `internal import` for the generated types in `ServerHTTP`;
  - the checker, once the targets exist:
    - the allow-list of each target, and `--packages` for the manifest's dependencies;
    - `requiredImportAccess` on `ServerHTTP`, so the targets of `PrestoCVAPI` are imported `internal`;
    - R4's detectors on every server target except the executable: `singleton`, and `infrastructureConstruction` for the types in `infrastructureTypes`, which gains `PostgresClient` and `HTTPClient` when the targets are created;
    - the R1 and R14 detectors on the same targets;
  - review, until the checker learns it: a static accessor such as `HTTPClient.shared`, which the detectors do not see today. Review also holds the API mappers in `ServerHTTP` deterministic, with their tests, because R2 cannot run on an adapter that creates request identifiers;
  - the contract suites of #157;
  - the loopback test of #158, which proves that the local profile refuses any other address;
  - the router test of #178, which proves that `serve` does not answer the worker's route, and the composition test of the executable's tickets, which proves that `serve` builds no inference client.

## Alternatives considered

- **One service with an internal route.** Rejected by the owner: the route is exposed to the internet, and the public service would hold the keys.
- **A request held open until the job ends.** Rejected by the owner: iOS suspends an app in the background, and the paid tailoring is lost.
- **Always-on CPU.** Rejected by the owner: it is paid while idle, and a restart loses the job.
- **A Cloud Run job per tailoring.** Rejected by the owner: it pays a cold start every time and gains nothing.
- **Microservices.** Rejected by the owner: with one developer, no separate teams and a zero budget, every hop between services costs something and buys nothing. The targets keep the boundaries instead.
- **Node, with cv-giovanni's JavaScript.** Rejected by the owner: one Swift core runs on the device, on the server and on a developer's machine ([ADR 0013](0013-cv-tailoring-context.md)).

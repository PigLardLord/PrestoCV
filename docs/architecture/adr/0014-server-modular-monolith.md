# 0014. Run the server as a modular monolith in two roles

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0006](0006-enforce-architecture-mechanically.md), [ADR 0007](0007-each-package-owns-its-model.md), [ADR 0008](0008-single-composition-root.md), [ADR 0013](0013-cv-tailoring-context.md), R1, R4, R11, R14, issues #133, #158

## Context

- The app tailors a CV to an advert with a model ([ADR 0013](0013-cv-tailoring-context.md)). The loop never runs on the device, so a server runs it, and the server holds the model providers' keys.
- It is one developer's project. There are no separate teams, and the budget is zero.
- The server runs on Cloud Run, which gives an instance CPU only while it handles a request. A tailoring cannot run after its response has gone.
- iOS suspends an app in the background, so the app cannot wait on one request until the tailoring ends.
- The server is a second executable in this repository. Two rules were written for the app alone:
  - [R4](../rules.md#r4-one-composition-root-per-executable) and [ADR 0008](0008-single-composition-root.md) say there is one composition root;
  - [R1](../rules.md#r1-packages-are-isolated-contexts-depend-only-along-documented-edges) and [ADR 0007](0007-each-package-owns-its-model.md) say that only `PrestoCVIntegration` translates between packages.
- The owner decided the server's shape on 2026-10-02 (#158). The targets below are this ADR's architecture, which follows from it. cv-giovanni is a separate project and out of scope.

## Decision

- **Swift, on Hummingbird 2.** It is the language of the app and of its packages, so `CVTailoring` and `CVDocumentModel` run on the server unchanged. Hummingbird is built on Swift concurrency, and a server imports only the parts it uses.
- **A modular monolith.** One package, `PrestoCVServer`, in this repository. Its modules are targets, and the compiler and the checker hold their boundaries, as in the app. There are no microservices.
- **One binary, two roles, two services.** `serve` answers the API and `work` runs tailorings. Hosted, each role runs as its own Cloud Run service, and both are built from one image.
  - The API records the job and hands it to a managed queue, Cloud Tasks. The queue calls the worker, the tailoring runs inside that request, and the queue retries it with backoff.
  - The worker is private. Only the queue's identity may call it, and the platform refuses everyone else before any code runs (#161).
  - The route the queue calls to run a job lives in `ServerHTTP`. It is mounted only in the `work` role, and it is not part of the public API (`openapi.yaml`). The executable composes the router per role.
  - Only the worker holds the model providers' keys.
  - A tailoring finishes within the queue's dispatch deadline of 30 minutes. The tailoring's own time limit is set below it (#152, #161).
- **Two profiles, `hosted` and `local`.** A profile is a set of adapters that the composition root picks from configuration. The local profile is for development only. It uses an in-memory store and an in-process queue, runs both roles in one process, and refuses to start on any address but 127.0.0.1.
- **Three environments: `local`, `staging` and `production`.**
  - `local` uses the local profile. `staging` and `production` use the hosted profile, each with its own configuration, database and queue.
  - Staging accepts App Attest's development environment, so a build from Xcode can be tried on a device. Production accepts only the production environment.
  - How a change reaches each environment belongs to the infrastructure layer of #133.
- **One composition root per executable.** [R4](../rules.md#r4-one-composition-root-per-executable) says "one per executable". The app's root is `PrestoCVComposition`. The server's root is the `PrestoCVServer` executable target. Each root is the only code that creates infrastructure. The local profile runs both roles from one root, in one process.
- **Seven targets,** all Linux ✓, and macOS for development. Each has a layer and the modules it may import:

| Target | Layer | May import |
|---|---|---|
| `ServerApplication` | application: the tailoring use cases and the job lifecycle (#157), and their ports (job store, job queue, quota, clock, log events) | `TailoringModel`, `Tailoring`, Foundation |
| `ServerInference` | outbound adapter: the inference providers behind `Tailoring`'s port (#154, #155) | `Tailoring`, `TailoringModel`, `AsyncHTTPClient`, Foundation |
| `ServerStorePostgres` | outbound adapter: the job store on Postgres (#160) | `ServerApplication`, `PostgresNIO`, Foundation |
| `ServerQueueCloudTasks` | outbound adapter: the job queue on Cloud Tasks (#161) | `ServerApplication`, `AsyncHTTPClient`, Foundation |
| `ServerLocalProfile` | outbound adapter: the in-memory store and the in-process queue of the local profile (#157, #158) | `ServerApplication`, Foundation |
| `ServerHTTP` | inbound adapter: the routes and middleware, mapping the generated API types to the use cases (#175, #178) | `ServerApplication`, `TailoringModel`, `PrestoCVAPITypes`, `PrestoCVAPIServer`, `Hummingbird`, `OpenAPIRuntime`, Foundation |
| `PrestoCVServer` | executable and composition root: roles, profiles, configuration | every target above, `Hummingbird`, `Logging`, `ServiceLifecycle`, Foundation |

- **More targets will follow.** The authentication, logging and notification targets are set by the decisions of their own tickets (#167, #168, #180).
- **External packages** are imported only by adapters and by the executable, never by `ServerApplication`. Each is pinned in the committed `Package.resolved`. A new one changes [modules.md](../modules.md) in the same pull request, so the checker's `--packages` rule holds it ([ADR 0006](0006-enforce-architecture-mechanically.md)).
- **Logging.** `ServerApplication` declares its own port for log events: typed events, never a CV, a prompt or a key (#167). The adapters and the executable bridge it to swift-log. The tickets that add logging and metrics (#167, #178) extend the adapters' allow-lists with `Logging` and `Metrics` in [modules.md](../modules.md).
- **Translation.** On the server, only `ServerHTTP` translates between the API's types and the tailoring model, as only `PrestoCVIntegration` does in the app ([ADR 0007](0007-each-package-owns-its-model.md)). The generated types never leave it.
- **The package depends on `CVTailoring`** (and on `PrestoCVAPI` once #177 exists). It never depends on `PrestoCVApp`, `PrestoCVCore` or `CVGeneratorAI`. It may depend on `CVPDFExporter`, which is reusable on a backend ([ADR 0002](0002-cvpdfexporter-standalone-and-portable.md)): the ticket that needs that edge adds it to [modules.md](../modules.md), for example #94. `PrestoCVAPITypes` and `PrestoCVAPIServer` are targets of the `PrestoCVAPI` package (#175).

## Consequences

- **R1 and R4 change.** R4 reads "One composition root per executable". R1 names `ServerHTTP` as the second place where translation happens, and says the server's package is an integration and composition package, as `PrestoCVApp` is, not one of the isolated context packages.
- **[ADR 0007](0007-each-package-owns-its-model.md) and [ADR 0008](0008-single-composition-root.md) stay in force for the app.** This ADR extends them to the server and supersedes neither.
- **[modules.md](../modules.md) lists the seven targets now.** They are created when the repository has been published (#132), under #158 and the tickets named in the table. Until then the checker's `rules.json` declares them not yet implemented.
- **Costs:**
  - two services to deploy from one image, and a queue between them;
  - the 30-minute dispatch deadline bounds a tailoring;
  - a second composition root to read;
  - a local profile with adapters of its own, which must behave as the hosted ones do. They are adapters of a profile the executable ships, not test doubles (R14). The contract suites of #157 keep them honest: each adapter passes the suite of its port.
- **Enforced by:**
  - the compiler, through the target graph;
  - the checker: the allow-list of each target, `--packages` for the manifest's dependencies, and the R1, R4 and R14 detectors on the production targets;
  - the contract suites of #157;
  - the loopback test of #158, which proves that the local profile refuses any other address.

## Alternatives considered

- **One service with an internal route.** Rejected by the owner: the route is exposed to the internet, and the public service would hold the keys.
- **A request held open until the job ends.** Rejected by the owner: iOS suspends an app in the background, and the paid tailoring is lost.
- **Always-on CPU.** Rejected by the owner: it is paid while idle, and a restart loses the job.
- **A Cloud Run job per tailoring.** Rejected by the owner: it pays a cold start every time and gains nothing.
- **Microservices.** Rejected: with one developer, no separate teams and a zero budget, every hop between services costs something and buys nothing. The targets keep the boundaries instead.
- **Node, with cv-giovanni's JavaScript.** Rejected by the owner: one Swift core runs on the device, on the server and on a developer's machine ([ADR 0013](0013-cv-tailoring-context.md)).

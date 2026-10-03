# 0017. Run the server on Cloud Run in the EU, keep little, and cap what it spends

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0014](0014-server-modular-monolith.md), [ADR 0015](0015-inference-providers-and-data-policy.md), [ADR 0016](0016-api-contract.md), R2, R4, R7, R12, R13, issues #133, #149, #159, #160, #161, #162, #163, #164, #165, #166, #167, #168, #170, #172, #180, #190

## Context

- [ADR 0014](0014-server-modular-monolith.md) decided the shape of the server: two roles, a queue between them, two profiles and three environments. It left open where each of them runs and how a change reaches an environment.
- A tailoring sends a person's CV to the server. The server must say what it stores, for how long, where its secrets live and what it may spend.
- It is one developer's project, and the budget is zero. Each choice below costs nothing while the project is small, and caps the cost if it stops being small.
- The consent text and the privacy policy (#190) must name where a CV goes and how long it stays there. What they say must be true of what the server does.
- The owner decided on 2026-10-02 (#159):
  - the regions and the products that run the server;
  - the database, and why the others lost;
  - what is stored, and the retention of each part;
  - the secrets, the infrastructure as code, the deploy path and the identity CI uses;
  - the four cost limits;
  - the list of processors.
- On 2026-10-03 the owner decided (#149) that no model provider's name or model identifier appears in the repository, except in the published privacy policy (#190) and the hosted deployment's runbook (#163). So this ADR writes "the hosted router" where #159 names its brand. The infrastructure vendors and products are not model providers, and the ADR names them.
- This ADR's own architecture:
  - which targets hold the stores, and how the schema is kept;
  - that erasure and the cost limits are use cases of `ServerApplication`, and how erasure is triggered;
  - what the queue carries, what a database branch holds, and which role reads which secret;
  - that the limits and the retention periods are configuration;
  - what is left to the tickets.

## Decision

**The owner's decisions.**

- **Google Cloud Run in `europe-west1` (Belgium),** with Cloud Tasks in the same region. It is in the EU, and it is a Tier 1 region. The free tier is a discount at Tier 1 prices, so in a Tier 1 region it covers its full value.
- **Postgres on Neon, in Frankfurt,** through PostgresNIO: one project, with one branch per environment. Neon's free plan stops the database after five minutes without queries and starts it again on the next query.
- **What is stored:**
  - jobs: the CV, the advert, the result, the state and the idempotency key;
  - quotas;
  - whatever authentication needs, as decided in its own layer (#168).
- **Retention:**
  - a job, with its CV and its result, is erased as soon as the app confirms it has saved the result, and 24 hours after the job ends at the latest;
  - a device unused for 90 days is erased;
  - logs never hold a CV or an advert, and keep Cloud Logging's default of 30 days.
- **Secrets in Secret Manager,** one set per environment. Each secret is readable only by the service that needs it. The model keys and the APNs key are readable by the worker alone.
- **Infrastructure as code with OpenTofu,** in `infra/`. Staging and production use the same modules, and the state lives in a bucket in the EU.
- **No long-lived keys in GitHub.** CI deploys through Workload Identity Federation.
- **How a change reaches each environment:** a merge to `main` deploys to staging, and a tag promotes the same image to production.
- **Four cost limits,** each configurable:
  1. per device: 5 tailorings a day;
  2. for everyone: 100 tailorings a day. Past that, the server answers "try again tomorrow";
  3. the hosted router key's credit limit: 5 $ a month. The provider enforces it even if our code is wrong;
  4. a Google budget alert at 1 €. It sends a warning and does not stop the spending.
- **The processors of a user's data are listed:** Google, Neon, Apple (App Attest and push notifications, #168, #180), and the model providers that each deployment's policy allows (#149). The app's privacy text names them.

**This ADR's own decisions.** The owner's decisions leave open how the code carries them out. These are consistent with [ADR 0014](0014-server-modular-monolith.md) and [ADR 0015](0015-inference-providers-and-data-policy.md).

- **(a) The stores.** The job store, the quota store and the device registry that authentication needs (#170) are adapters in `ServerStorePostgres`, behind ports that `ServerApplication` owns.
  - One schema and one migration history cover the database.
  - What else authentication keeps, and which target holds its logic, is decided by its own ADR (#168).
- **(b) The schema.** It is versioned SQL, applied only by the binary's `migrate` command, never by `serve` or `work` (#160). Its constraints live in the schema. Its rows are DTOs of the store's own, built from the types of `TailoringModel` (R12): the domain never reaches the database.
- **(c) Erasure is a use case of `ServerApplication`** (#166).
  - It erases a job once the app confirms it has saved the result, a job 24 hours after it ends, whether it succeeded, failed or expired, and a device unused for 90 days.
  - It deletes rows. It marks nothing as deleted. Run twice, it does no harm.
  - It reads the time from the injected clock (R2).
  - Two things run it. The app's confirmation, `DELETE /v1/tailorings/{id}` ([ADR 0016](0016-api-contract.md)), erases that job. A schedule, Cloud Scheduler, calls the worker for the rest.
  - The scheduled call reaches a route that, like the one the queue calls, is mounted only in `work` and is not in `openapi.yaml`. The queue's identity authenticates it, as [ADR 0014](0014-server-modular-monolith.md) decides.
  - Quota counts go with their device at the latest. When they go sooner is left to #165.
- **(d) The cost limits are checked by `ServerApplication`, before a job is recorded** (#165). The per-device limit and the limit for everyone are both checked there. Over one, the API answers 429 with when to retry.
  - The quota is counted in the same transaction that records the job. Two starts that race for the last tailoring of a day record one job. A retry with the same idempotency key returns the first job and counts nothing more.
  - What the app tells the user of a refusal is the app's (R13).
- **(e) Two limits live outside the code** (#163, #165).
  - The credit limit of the hosted router's key is set by hand at the provider, and the runbook says how. The server meets it as a provider's refusal for lack of credit, a typed error (#150) that [ADR 0015](0015-inference-providers-and-data-policy.md) keeps out of the fallback.
  - The budget alert is infrastructure code, and its notice reaches the owner.
- **(f) Every limit and every retention period is configuration.** The `PrestoCVServer` executable reads them and hands them to the use cases as values (R2, R4). The hosted defaults are the owner's: 5 tailorings a device a day, 100 for everyone, 24 hours for a job after it ends and 90 days for an idle device. The 30 days of the logs are Cloud Logging's default, and the server does not set them.
- **(g) A task carries the job's ID and nothing else** (#161). The CV and the advert are in the job store only, so erasing a job erases the CV from the one place it is kept. The queue holds no copy of it.
- **(h) A database branch holds one environment's data.** No branch is made from another environment's data. Staging starts from the schema, which `migrate` builds (#160, #163).
- **(i) Secrets.** The executable reads every secret and hands it to the adapters, as [ADR 0015](0015-inference-providers-and-data-policy.md) decides, so no adapter reads a secret store. Both roles need the database's credentials. The model keys and the APNs key are the worker's alone, so `serve` reads no provider's key.
- **(j) The processors.** The processors that `GET /v1/policy` serves are the model providers ([ADR 0015](0015-inference-providers-and-data-policy.md)), which change with a deployment's configuration. Google, Neon and Apple are fixed by this ADR. The app's privacy text and the published policy name all of them (#190), and a change of one of the three is a new ADR and a new text.
- **Left to the tickets:**
  - where a day begins, which jobs count against the limits (a job the worker refuses, a job that fails) and when a count goes sooner (#165);
  - the interval of the erasure schedule, and the pool of connections (#163, #166, #160);
  - whether `GET /v1/policy` also serves Google, Neon and Apple, which would put them under the policy's version (#190, #155).
- **No new edge between targets.** `ServerStorePostgres` already imports `PostgresNIO`, and `ServerQueueCloudTasks` imports `AsyncHTTPClient`. No target imports an SDK of Google, Neon or Apple, and `ServerApplication` imports no third-party package, so the allow-lists in [modules.md](../modules.md) do not change. [modules.md](../modules.md) describes what each target now holds.
- **It is consistent with [ADR 0014](0014-server-modular-monolith.md):** its invariants hold.

## Consequences

- **What becomes possible:**
  - a hosted server that costs nothing while it is small, and that stays under a cap if it grows;
  - a privacy text that is true: the server keeps a CV until the app has its result, and 24 hours at the latest, and no log holds one;
  - a staging that has the shape of production, because both use the same modules.
- **Costs:**
  - **Two cold starts.** Neon's idle suspend adds a delay to the first query after five quiet minutes, and Cloud Run's scale to zero adds another to the first request ([ADR 0014](0014-server-modular-monolith.md)). A resume is slow, and it is not an error (#160).
  - **Every query crosses from Belgium to Frankfurt.** Both are in the EU, and they are not the same place.
  - **The queue's deadline of 30 minutes** ([ADR 0014](0014-server-modular-monolith.md)) bounds a tailoring.
  - **The budget alert does not stop spending.** The hosted router's credit limit is the hard cap on what the router charges. No cap stops Google's bill, and the daily limits bound the tailorings that cause it.
  - **A free plan can change,** and the vendor decides when. The alert at 1 € is how the owner would notice.
  - **An erased row can outlive its erasure in Neon's restore history,** for a window that its plan sets. The runbook records the window (#163), and the privacy policy states retention with it (#190).
  - **The 24 hours are met by the schedule,** so they are met to within its interval. The privacy text counts it (#190).
  - **Setting up is partly by hand:** the secrets' values, the router's credit limit and, if Neon's provider does not hold up, Neon itself. `tofu apply` is the owner's step (#163).
- **Enforced by:**
  - the compiler, through the target graph: `ServerApplication` imports no adapter and no third-party package, so erasure and the limits are tested without a database;
  - the checker:
    - the allow-lists of [modules.md](../modules.md), and `--packages` for the manifests;
    - R4's detectors on every server target except the executable, so the database pool is created only in the root;
    - R2's detectors on `ServerApplication`, so the 24 hours, the 90 days and the start of a day read the injected clock;
    - R7's `swallowedError` on every server target, so a failed erase or a failed count is never swallowed;
  - tests:
    - the contract suites of the stores (#157), run against Postgres in a container in the Linux CI job (#160), with the quota race of two starts for the last tailoring of a day added by #165 and a retry with the same idempotency key counted once;
    - `migrate` on an empty database, and again on an up-to-date one (#160);
    - each limit and the reset at the start of a day (#165), and the hosted profile's defaults, which equal the owner's values (#165, #166);
    - erasure on confirmation, at 24 hours for each final state, and of an idle device, run twice, with the row gone and not marked (#166);
    - a task holds the job's ID and no other field of the job (#161);
    - the router test of #178, which proves that `serve` does not answer the worker's routes, the erasure route among them;
    - the marker test of #167, which proves that no CV or advert reaches anything the server emits;
  - the infrastructure, reviewed in pull requests: `tofu plan` runs in CI when `infra/` changes, `apply` is the owner's step, and production's plan differs from staging's only in its variables (#163);
  - CI (#164): it authenticates through Workload Identity Federation only, a pull request from a fork never reaches a deploy or a secret, and a tag deploys the image digest that staging ran, without a rebuild;
  - review, until a check exists: the repository holds no cloud key, in its workflows or its settings;
  - the runbook and the providers, outside the code: the credit limit is set at the provider, and the runbook lists every limit, where it is set and how to change it (#163, #165).

## Alternatives considered

- **Firestore.** Rejected by the owner: there is no Swift server SDK, it has no constraints, and it locks the project in.
- **Supabase.** Rejected by the owner: it pauses an idle project after a week.
- **Cloud SQL.** Rejected by the owner: it has no free tier.
- **A region outside the EU.** Rejected: the data stays in the EU.
- **A long-lived service-account key in GitHub.** Rejected by the owner: CI deploys through Workload Identity Federation.

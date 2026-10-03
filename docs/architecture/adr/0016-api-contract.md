# 0016. Generate both sides of the API from one versioned spec

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0007](0007-each-package-owns-its-model.md), [ADR 0013](0013-cv-tailoring-context.md), [ADR 0014](0014-server-modular-monolith.md), [ADR 0015](0015-inference-providers-and-data-policy.md), R1, R3, R7, R8, R14, issues #133, #175, #176, #177, #178, #179, #182

## Context

- The app calls the server over HTTP, and the two are built and released apart. They need the same types, the same errors and the same rules for change, and they need them written once.
- Two hand-written copies of every type drift. A drift between an app and a server is found by a user, in the field.
- Users do not update at once. Old versions of the app stay installed after the server has changed.
- The app is native and the server is Swift on Hummingbird ([ADR 0014](0014-server-modular-monolith.md)). The same generator serves both sides.
- Earlier decisions already assume a contract:
  - the app maps its CV into the tailoring model, and the server maps its API types into it ([ADR 0013](0013-cv-tailoring-context.md));
  - `ServerHTTP` is the one place that holds the generated types, and the route the queue calls is not part of the public API ([ADR 0014](0014-server-modular-monolith.md));
  - `GET /v1/policy` serves the data policy ([ADR 0015](0015-inference-providers-and-data-policy.md)).
- A tailoring costs money and carries a person's CV, so what the API accepts and refuses must be written down and checked.
- The owner decided on 2026-10-02 (#175) the spec-first approach, the package and its three targets, the committed generated code, the versions in the path, the error format, the minimum app version, the refusal of browser clients, how the app learns that a tailoring has ended, the public reference and the endpoints. This ADR's own architecture is: the layers and platforms of the targets, who may import them, the app's adapter, how the checker treats generated code, and the spec's role as documentation.

## Decision

- **Spec-first.** `openapi.yaml`, in OpenAPI 3.1, is the source of the API. The generator, swift-openapi-generator, produces the types, the server's handlers on the Hummingbird transport, and the app's client on the URLSession transport.
- **One package, `PrestoCVAPI`,** holds the spec and three targets generated from it: `PrestoCVAPITypes`, `PrestoCVAPIServer` and `PrestoCVAPIClient`.
- **The generated code is committed.** Its changes show up in pull requests, builds stay fast, and Xcode has no plugin to enable. CI regenerates the code and fails when the committed code no longer matches the spec (#177).
- **The generated types never leave their adapters** ([ADR 0007](0007-each-package-owns-its-model.md)).
  - On the server, `ServerHTTP` maps them to the use cases ([ADR 0014](0014-server-modular-monolith.md)).
  - In the app, the client sits behind a port that `PrestoCVIntegration` owns (R3).
- **Versions are in the path:** `/v1`. Within a version, a change only adds. CI compares the spec with the one on `main` and refuses one that breaks it. A break needs a new version in the path (#177).
- **Errors are problem+json** (RFC 9457), with stable, documented `type` URIs (#176).
  - The server turns its typed errors into problems in one place, and the app turns the problems it knows into the workflow's typed errors (R7).
  - A problem carries a code and never user-facing text. The app words it (R13).
- **A minimum app version.** The server refuses an app older than the configured minimum, with a typed error that tells the user to update. Old versions stay installed in the field.
- **No browser clients.** Any request that carries an `Origin` header is refused, in every profile.
- **A request is untrusted input** (R8). The spec states the bounds of every string, list and number (#176). `ServerHTTP` is the one boundary that validates a request into the tailoring model, or refuses it with a problem.
- **The app learns that a tailoring has ended by polling and by a push notification** (#180, #181). The device's push token is part of the API, so the app can set it and clear it.
- **The API reference is public,** generated from the spec and published on GitHub Pages (#182).
- **The endpoints:**
  - `GET /health`;
  - challenges, registration and sessions (#168);
  - the device's push token, which can be set and cleared;
  - `GET /v1/policy`: the data policy, for the app's consent text ([ADR 0015](0015-inference-providers-and-data-policy.md), #155);
  - `POST /v1/tailorings`, `GET /v1/tailorings/{id}` and `DELETE /v1/tailorings/{id}`. The `DELETE` is also how the app confirms it has saved the result (#166).

  No endpoint analyses an advert: the app does that on the device (#153). The spec describes the public API only. The route that the queue calls is not in it ([ADR 0014](0014-server-modular-monolith.md)).

**This ADR's own architecture.**

- **(a) The package.** `PrestoCVAPI` is a package of its own, in this repository. It depends on no PrestoCV package, so the app and the server can both depend on it. Its three targets hold generated code only.

| Target | Layer | Platforms | Responsibility |
|---|---|---|---|
| `PrestoCVAPITypes` | generated | iOS, macOS, Linux ✓ | The schemas, and the input and output of each operation |
| `PrestoCVAPIServer` | generated | macOS, Linux ✓ | The protocol that the server implements, and its registration on a transport |
| `PrestoCVAPIClient` | generated | iOS, macOS | The client, which calls each operation through a transport. It builds on Linux too if its transport does, and #177 decides |

- **(b) Who may import them.**
  - On the server, only `ServerHTTP`, with `internal import` ([ADR 0014](0014-server-modular-monolith.md)). It imports `PrestoCVAPITypes` and `PrestoCVAPIServer`, and never the client.
  - In the app, only one outbound adapter target of the `PrestoCVApp` package, `PrestoCVAPIAdapter` (planned, #179).
    - It implements the port of the tailoring workflow, which `PrestoCVIntegration` owns. The port speaks the workflow's language: the tailoring model and typed errors, no generated type, no HTTP status.
    - It imports `PrestoCVAPITypes` and `PrestoCVAPIClient` with `internal import`, and never the server's protocol. It maps the tailoring model to the request and the result back (exhaustively, [ADR 0007](0007-each-package-owns-its-model.md)), and the problems to the workflow's typed errors.
    - It is a target of its own because R3 puts an adapter in its own target, and so that `PrestoCVIntegration` depends on neither the client nor its transport.
    - The composition root creates it and hands it its transport, which is infrastructure (R4). Which of the runtime's modules the adapter and the root import to do so is #179's to settle, in [modules.md](../modules.md), within this ADR's invariants.
  - No other production target outside the package imports `PrestoCVAPI`. Test targets are held by the allow-lists of their own.
- **(c) Generated code and the checker.**
  - The three targets hold only generated code. A header marks each file, and nobody edits one by hand (#177).
  - They are held by their import allow-lists and by the regeneration in CI, which fails when a file differs from the generator's output. They are not held by the detectors of R2, R7, R9, R13 and R14, which generated code cannot be made to satisfy.
  - The checker gains a `generated` target kind for them (#177). The allow-lists apply to it, and the detectors do not. Until then, [modules.md](../modules.md) lists the targets and `rules.json` declares them not yet implemented.
  - The package's manifest is held like every manifest: Swift 6, no unsafe flags (R9).
- **(d) The spec is the documentation.** Every endpoint, schema, field and error `type` has a description in the spec, and a linter fails on one that has none (#176). The public reference is generated from those descriptions and says nothing the spec does not (#182, #183).

## Consequences

- **One contract for both sides.** A type, an error and a version are written once. A change to the spec changes the server's protocol and the client together, and a handler or a caller that does not follow fails to compile.
- **The reference cannot go stale.** It is generated from the spec, so a document-against-code check has nothing to compare for the API (#183).
- **modules.md lists the `PrestoCVAPI` package, its three targets and what may import them,** and gains the `PrestoCVAPIAdapter` row. The checker's `rules.json` declares the four targets not yet implemented until #177 and #179 create them. `PrestoCVComposition`'s allowed imports stay as they are until the adapter exists.
- **Costs:**
  - The generator's output is reviewed in pull requests. A generator upgrade can change every generated file, and the diff is read like code. The generator and the packages the generated code imports are pinned.
  - A breaking change needs a new version in the path. The server cannot drop a version while an app that uses it is in the field, which is what the minimum app version is for.
  - Generated code escapes the detectors. Its quality is the generator's, and the checks below hold it instead.
  - The client builds on Linux only if its transport does.
  - The spec gets longer and more exact, because its descriptions are the reference.
- **Enforced by:**
  - the compiler:
    - the target graph, and the generated protocol, so every operation of the spec has a handler;
    - `internal import` in `ServerHTTP` and in `PrestoCVAPIAdapter`, so no generated type appears in their public API;
  - the checker, once the targets exist:
    - the allow-lists of [modules.md](../modules.md), which let only `ServerHTTP` and `PrestoCVAPIAdapter` import a target of `PrestoCVAPI`;
    - `requiredImportAccess` on both, so the generated targets are imported `internal` (R1);
    - `--packages`, for the manifests' dependencies;
    - the detectors that every adapter target carries, on `PrestoCVAPIAdapter`;
  - CI (#177): the regeneration diff, and the comparison of the spec with the one on `main`, which fails when a field is removed;
  - the linter on the spec's descriptions (#176);
  - tests:
    - the request and the result round-trip through the generated types, for a CV in each of the six languages (#176);
    - router tests for each endpoint and for each error `type` the spec documents (#178);
    - the adapter against a fake server, for each outcome and each error (#179);
  - review, for the generator's diff.

## Alternatives considered

- **Hand-written types on both sides.** Rejected: two copies drift, and nothing tells the app that the server has changed.
- **Code-first, with the spec generated from the server.** Rejected by the owner: the spec is the source, and the code follows it.
- **Generating at build time, with the plugin, and not committing the output.** Rejected by the owner: changes to the generated code would not show in pull requests, builds would be slower, and Xcode would need the plugin enabled.
- **GraphQL, or a custom RPC.** Rejected: the generator and the public reference come with OpenAPI.
- **Browser clients.** Rejected by the owner: the only caller is the app, so a request that carries an `Origin` header is refused in every profile.

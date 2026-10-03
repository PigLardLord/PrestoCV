# 0016. Generate both sides of the API from one versioned spec

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0007](0007-each-package-owns-its-model.md), [ADR 0013](0013-cv-tailoring-context.md), [ADR 0014](0014-server-modular-monolith.md), [ADR 0015](0015-inference-providers-and-data-policy.md), R1, R3, R4, R7, R8, R9, R13, R14, issues #133, #153, #155, #166, #168, #174, #175, #176, #177, #178, #179, #180, #181, #182, #183, #190

## Context

- The app calls the server over HTTP, and the two are built and released apart. They need the same types, the same errors and the same rules for change, and they need them written once.
- Two hand-written copies of every type drift. A drift between an app and a server is found by a user, in the field.
- Users do not update at once. Old versions of the app stay installed after the server has changed.
- The app is native and the server is Swift on Hummingbird ([ADR 0014](0014-server-modular-monolith.md)). The same generator serves both sides.
- Earlier decisions already assume a contract:
  - the app maps its CV into the tailoring model, and the server maps its API types into it ([ADR 0013](0013-cv-tailoring-context.md));
  - `ServerHTTP` is the one place that holds the generated types, and the route the queue calls is not part of the public API ([ADR 0014](0014-server-modular-monolith.md));
  - `GET /v1/policy` serves the data policy and its version ([ADR 0015](0015-inference-providers-and-data-policy.md)).
- A tailoring costs money and carries a person's CV, so what the API accepts and refuses must be written down and checked.
- The owner decided on 2026-10-02 (#175):
  - the spec-first approach, the package and its three targets, and the committed generated code;
  - that the generated types never leave their adapters;
  - the versions in the path, the error format, the minimum app version, and the refusal of browser clients;
  - how the app learns that a tailoring has ended;
  - the spec as the API's documentation, and the public reference;
  - the endpoints.
- This ADR's own decisions:
  - the layers and platforms of the targets;
  - who may import them, and the app's one adapter, which is its only client of the API;
  - how the checker treats generated code;
  - that `ServerHTTP` validates a request, because the generated code does not enforce the spec's bounds;
  - how problems map to the app's typed errors, and that a problem carries a code and no user-facing text;
  - what a breaking change is;
  - that `GET /health` is exempt from the minimum-version check.

## Decision

**The owner's decisions.**

- **Spec-first.** `openapi.yaml`, in OpenAPI 3.1, is the source of the API. The generator, swift-openapi-generator, produces the types, the server's protocol and its registration on a transport, and the app's client. `ServerHTTP` implements the protocol on the Hummingbird transport. The app runs the client on the URLSession transport that its composition root creates.
- **One package, `PrestoCVAPI`,** holds the spec and three targets generated from it: `PrestoCVAPITypes`, `PrestoCVAPIServer` and `PrestoCVAPIClient`.
- **The generated code is committed.** Its changes show up in pull requests, builds stay fast, and Xcode has no plugin to enable. CI regenerates the code and fails when the committed code no longer matches the spec (#177).
- **The generated types never leave their adapters** ([ADR 0007](0007-each-package-owns-its-model.md)).
  - On the server, `ServerHTTP` maps them to the use cases ([ADR 0014](0014-server-modular-monolith.md)).
  - In the app, the client sits behind a port that `PrestoCVIntegration` owns (R3).
- **Versions are in the path:** `/v1`. Within a version, a change only adds. CI compares the spec with the one on `main` and refuses one that breaks it. A break needs a new version in the path (#177).
- **Errors are problem+json** (RFC 9457), with stable, documented `type` URIs (#176).
- **A minimum app version.** The server refuses an app older than the configured minimum, with a typed error that tells the user to update. Old versions stay installed in the field.
- **No browser clients.** Any request that carries an `Origin` header is refused, in every profile.
- **The app learns that a tailoring has ended by polling and by a push notification** (#180, #181). The device's push token is part of the API, so the app can set it and clear it.
- **The spec is the documentation.** Every endpoint, schema, field and error `type` has a description in the spec, and a linter fails on one that has none (#176). The API reference is public: it is generated from those descriptions, says nothing the spec does not, and is published on GitHub Pages (#182, #183).
- **The endpoints:**
  - `GET /health`;
  - challenges, registration and sessions (#168);
  - the device's push token, which can be set and cleared;
  - `GET /v1/policy`: the data policy, its processors and its version, for the app's consent text ([ADR 0015](0015-inference-providers-and-data-policy.md), #155, #190);
  - `POST /v1/tailorings`, `GET /v1/tailorings/{id}` and `DELETE /v1/tailorings/{id}`. The `DELETE` is also how the app confirms it has saved the result (#166).

  No endpoint analyses an advert: the app does that on the device (#153). The spec describes the public API only. The route that the queue calls is not in it ([ADR 0014](0014-server-modular-monolith.md)).

**This ADR's own decisions.**

- **(a) The package.** `PrestoCVAPI` is a package of its own, in this repository. It depends on no PrestoCV package, so the app and the server can both depend on it. Its three targets hold generated code only. `openapi.yaml` sits in the package and is excluded from every target: it is not a SwiftPM resource, so no binary carries it.

| Target | Layer | Platforms | Responsibility |
|---|---|---|---|
| `PrestoCVAPITypes` | generated | iOS, macOS, Linux ✓ | The schemas, and the input and output of each operation |
| `PrestoCVAPIServer` | generated | macOS, Linux ✓ | The protocol that the server implements, and its registration on a transport |
| `PrestoCVAPIClient` | generated | iOS, macOS, Linux ✓ | The client, which calls each operation through the transport it is given |

- **(b) Who may import them.**
  - On the server, only `ServerHTTP`, with `internal import` ([ADR 0014](0014-server-modular-monolith.md)). It imports `PrestoCVAPITypes` and `PrestoCVAPIServer`, and never the client.
  - In the app, only one outbound adapter target of the `PrestoCVApp` package, `PrestoCVAPIAdapter` (planned, #179).
    - **It is the app's only client of the API,** for every endpoint the app calls: the tailorings, the policy, the push token, and the challenges, registration and sessions. It signs the encoded body of a start through an attestation port that `PrestoCVIntegration` owns and the App Attest adapter of #174 implements, and it opens and renews the session. The attestation adapter never calls the API.
    - It implements the ports that reach the server, which `PrestoCVIntegration` owns. They speak the workflow's language: the tailoring model and typed errors, no generated type, no HTTP status.
    - It imports `PrestoCVAPITypes` and `PrestoCVAPIClient` with `internal import`, and never the server's protocol. It maps the tailoring model to the request and the result back (exhaustively, [ADR 0007](0007-each-package-owns-its-model.md)), and the problems to the workflow's typed errors.
    - It is a target of its own because R3 puts an adapter in its own target, and so that `PrestoCVIntegration` depends neither on the client nor on its transport.
    - The composition root creates it, and creates the URLSession transport that the client runs on, which is infrastructure (R4). The root is the one target that imports `OpenAPIURLSession`. `PrestoCVAPIAdapter` carries R4's detectors, and the checker's `infrastructureTypes` lists `URLSessionTransport` once the adapter exists. Until `URLSessionTransport` is listed in `infrastructureTypes`, review holds it.
    - It also imports the runtime's modules, `OpenAPIRuntime` and `HTTPTypes`, which the middleware that signs a start and sends the session needs. How the transport reaches its initialiser is #179's. If that needs more, #179 extends the allow-list in [modules.md](../modules.md), without a new ADR, while this ADR's invariants hold.
  - No other production target outside the package imports `PrestoCVAPI`. Test targets are held by the allow-lists of their own.
- **(c) Generated code and the checker.**
  - The three targets hold only generated code. A header marks each file, and nobody edits one by hand (#177).
  - They are held by their import allow-lists and by the regeneration in CI, which fails when a file differs from the generator's output.
  - One detector runs on them, R1's `exportedImport`, because generated code satisfies it and R1 bans `@_exported import` everywhere. No other detector runs on them, R11's `platformCondition` included: the generator wraps its Foundation imports in `#if os(Linux)`, and nobody may edit generated code, so a finding there could never be fixed. Their import allow-lists still apply.
  - The checker gains a `generated` target kind for them (#177). Until then, [modules.md](../modules.md) lists the targets and `rules.json` declares them not yet implemented.
  - The package's manifest is held like every manifest: Swift 6, no unsafe flags (R9).
  - The generator is pinned in a tool package of its own, not in `PrestoCVAPI`'s manifest, so that it and its dependencies never enter the dependency graph of the app and the server (#177).
- **(d) A request is untrusted input** (R8).
  - The spec states the bounds of every string, list and number (#176). The generated code does not enforce `maxLength`, `maxItems`, `minimum`, `maximum` or `pattern`.
  - So `ServerHTTP` is the one boundary that validates a request into the tailoring model, or refuses it with a problem. A test proves that the spec's bounds equal the bounds of the model's validators. It lives in `ServerHTTP`'s tests (#178), because it needs `TailoringModel`, which `PrestoCVAPI` does not import, and it reads the spec by its path (#176 states the bounds).
- **(e) Problems.**
  - The server turns its typed errors into problems in one place (#178). The adapter turns each documented `type` into a typed error of its workflow (R7).
  - A problem's `type` URI is its code. `title` and `detail` are for developers: a problem carries no user-facing text, and the app words its own (R13).
  - A `type` URI is an identifier that outlives the hosting of the reference (#182): the page may move, and the `type` does not change.
  - Every operation declares a `default` problem+json response, so a client decodes any error as a problem.
  - An unknown `type`, or a response that the spec does not document for that operation, becomes a generic typed error in the adapter. It is never a success and never a crash.
- **(f) What a breaking change is,** seen from an app in the field, which cannot be updated at once.
  - Breaking: removing or renaming an operation, a field, a problem `type` or a value the app sends; requiring more of a request or narrowing what it may carry; making a required field of a response optional; any change that an old client cannot decode.
  - Not breaking: adding an operation, an optional request field, a response field or a problem `type`.
  - **An optional request field reaches the server first.** The server that accepts it ships first, and the app that sends it ships after.
  - **A new value in a response enum breaks old clients unless the enum is open.** So the spec declares a response enum as `anyOf` its known values and a plain string, as the generator supports, and the adapter maps a value it does not know to a typed "unknown" case (R7). A new value is then not a break.
  - A response schema allows additional properties, so an old client ignores a field it does not know.
- **(g) The policy's version and the aliases,** as [ADR 0015](0015-inference-providers-and-data-policy.md) decides them. The contract carries them.
  - `GET /v1/policy` serves the requirements, the processors and the version derived from them.
  - The start request carries the version that the app showed the user. A different one is refused with a documented problem `type`, which the adapter maps to a "consent again" typed error of the workflow (#190).
  - A result names a provider and a model only by the alias that the configuration gives them, never by a name or an identifier (#176). The spec's examples use invented names.
- **(h) The minimum app version, in detail.**
  - The check runs on every route except `GET /health`, so a probe never fails on a version.
  - The header's format, how the app's version is compared with the minimum, and how a retired path version is refused are left to #176 and #177.

## Consequences

- **One contract for both sides.** A type, an error and a version are written once. A change to the spec changes the server's protocol and the client together, and a handler or a caller that does not follow fails to compile.
- **The reference cannot go stale.** It is generated from the spec, so a document-against-code check has nothing to compare for the API (#183).
- **R1 and R4 change.**
  - R1 gains the app's side: the rule that ADR 0014 wrote for `ServerHTTP` now also names `PrestoCVAPIAdapter`, in its text and in its `requiredImportAccess` check.
  - R4's list of infrastructure gains the API's transport in the app.
- **modules.md lists the `PrestoCVAPI` package, its three targets and what may import them,** and gains the `PrestoCVAPIAdapter` row. It also lists what `PrestoCVComposition` imports, explicitly. The checker's `rules.json` declares the four targets not yet implemented until #177 and #179 create them, and keeps `PrestoCVComposition`'s allowed imports as they are until the adapter exists. The checker lets `rules.json` be stricter than modules.md.
- **rules.md's scope paragraph and modules.md's introduction name the generated targets** next to the test and tool targets, once the kind exists (#177).
- **Assigned to #177:**
  - the `generated` kind and its self-test, with the two scope paragraphs;
  - the entry of `PrestoCVAPI`'s manifest in `rules.json`, and `PrestoCVAPI` in the `--packages` list of `check.sh`;
  - the generator's tool package;
  - the comparison with the spec on `main`, and the rule for what breaks it;
  - the package in the project's test commands.

  The test that the bounds agree is not one of them: it lives in `ServerHTTP`'s tests (#178), and reads the spec by its path.
- **Costs:**
  - The generator's output is reviewed in pull requests. A generator upgrade can change every generated file, and the diff is read like code.
  - A breaking change needs a new version in the path. The server cannot drop a version while an app that uses it is in the field, which is what the minimum app version is for.
  - Apart from R1's `exportedImport`, no detector holds generated code, so its quality is the generator's, and the checks below hold it instead.
  - The bounds are written twice, in the spec and in the model's validators, and a test keeps them equal.
  - The spec gets longer and more exact, because its descriptions are the reference.
- **Enforced by:**
  - the compiler:
    - the target graph, and the generated protocol, so every operation of the spec has a handler;
    - `internal import` in `ServerHTTP` and in `PrestoCVAPIAdapter`, so no generated type appears in their public API;
  - the checker, once the targets exist:
    - the allow-lists of [modules.md](../modules.md), which let only `ServerHTTP` and `PrestoCVAPIAdapter` import a target of `PrestoCVAPI`, and only the composition root import `OpenAPIURLSession`;
    - `requiredImportAccess` on both, which the checker reports as R5's `importAccess`, so the generated targets are imported `internal`;
    - `--packages`, for the manifests' dependencies;
    - the detectors that every adapter target carries, on `PrestoCVAPIAdapter`, and R4's with `URLSessionTransport` in `infrastructureTypes`;
  - CI (#177): the regeneration diff, and the comparison of the spec with the one on `main`, which fails on a breaking change as (f) defines it, a removed field among them;
  - the linter on the spec's descriptions (#176);
  - tests:
    - the request and the result round-trip through the generated types, for a CV in each of the six languages (#176);
    - the spec's bounds equal the bounds of the model's validators, in `ServerHTTP`'s tests, which read the spec by its path (#178; #176 states the bounds);
    - router tests for each endpoint and for each error `type` the spec documents, and one that proves that every problem a middleware emits is documented for each operation the middleware covers (#178);
    - the adapter against a fake server, for each outcome and each error, an unknown `type`, an undocumented status and an unknown enum value among them (#179);
  - review, for the generator's diff, and for R4 on the adapter until `URLSessionTransport` is in `infrastructureTypes`.

## Alternatives considered

- **Hand-written types on both sides.** Rejected: two copies drift, and nothing tells the app that the server has changed.
- **Code-first, with the spec generated from the server.** Rejected by the owner: the spec is the source, and the code follows it.
- **Generating at build time, with the plugin, and not committing the output.** Rejected by the owner: changes to the generated code would not show in pull requests, builds would be slower, and Xcode would need the plugin enabled.
- **GraphQL, or a custom RPC.** Rejected: the generator and the public reference come with OpenAPI.
- **Browser clients.** Rejected by the owner (#175).

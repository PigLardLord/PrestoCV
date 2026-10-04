# 0018. Authenticate the app's installations with App Attest, not accounts

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0014](0014-server-modular-monolith.md), [ADR 0016](0016-api-contract.md), [ADR 0017](0017-hosting-storage-and-cost.md), R1, R2, R3, R4, R7, R8, R11, R13, R14, issues #133, #158, #166, #167, #168, #169, #170, #171, #172, #173, #174, #176, #179, #180

## Context

- A tailoring costs money and carries a person's CV ([ADR 0013](0013-cv-tailoring-context.md), [ADR 0017](0017-hosting-storage-and-cost.md)). The server must know that a caller is a genuine copy of the app, and it must count tailorings per caller, because the first cost limit is 5 a device a day.
- PrestoCV has no accounts. The server should hold no email, no name and no password to know who is calling.
- Apple's App Attest fits. The app creates a key in the Secure Enclave and has Apple attest it. The server verifies the attestation. From then on the key signs challenges and requests, and a counter makes each signature single-use.
- App Attest does not exist on macOS 26 ([WWDC26, session 201](https://developer.apple.com/videos/play/wwdc2026/201/)), and it does not exist in the Simulator. The local profile has no Apple behind it either.
- Earlier ADRs already assume it, and leave its architecture to this one:
  - [ADR 0014](0014-server-modular-monolith.md): staging accepts App Attest's development environment, and the authentication, logging and notification targets are "set by the decisions of their own tickets (#167, #168, #180)";
  - [ADR 0016](0016-api-contract.md): the spec has endpoints for challenges, registration and sessions, and `PrestoCVAPIAdapter` signs a start through an attestation port that `PrestoCVIntegration` owns;
  - [ADR 0017](0017-hosting-storage-and-cost.md): the device registry's adapters are in `ServerStorePostgres` and `ServerLocalProfile`, its port is "a port of `ServerApplication` or of the target that #168 decides", a device unused for 90 days is erased, and Apple is one of the processors.
- The owner decided on 2026-10-02 (#168):
  - that the caller is an installation, authenticated by App Attest and nothing else, with the minimum operating systems that implies;
  - the flow: challenge, attestation, assertion, session token, and an assertion over the body of a start;
  - the environments, what App Attest does not prove, and the minimal authorization;
  - the limit on unauthenticated endpoints, the checks of iOS 27 and macOS 27, and the erasure of an idle device.
- The owner decided on 2026-10-04 that `GET /health` is limited per address like every other unauthenticated endpoint, and that the attestation captured from a development build may be committed as a test fixture.
- This ADR's own architecture:
  - the server targets that carry authentication, and what each imports;
  - the identity type that jobs and authentication share, and who owns the registry's port;
  - how an address is hashed, and who checks the start's assertion against which bytes and which key;
  - the app's attestation adapter, where it keeps the key, and what the app does where there is no App Attest;
  - the development token, end to end, and who checks what.

## Decision

**The owner's decisions.**

- **App Attest, nothing else.** Tailoring requires App Attest: iOS 26 and later, and macOS 27 and later. App Attest does not exist on macOS 26. The rest of the app keeps its current minimums. There is no Sign in with Apple and no account fallback.
- **The caller is an installation of the app,** not a user. Apple's App Attest proves that it is a genuine copy of PrestoCV.
- **The flow:**
  1. The server gives out a one-time challenge, valid for 5 minutes.
  2. The app creates a key in the Secure Enclave and has Apple attest it. The server verifies the attestation (#169) and records the device: key ID, public key, counter and environment.
  3. To open a session, the app signs a challenge with its key (an *assertion*). The server checks the signature and that the counter has gone up (#170), then issues a session token.
  4. **The session token is a JWT signed with Ed25519, valid for 15 minutes** (#171). The server verifies it without the database. Its key carries an ID so it can be rotated, and the algorithm is fixed, so any other is refused.
  5. **Starting a tailoring, which costs money, also needs a fresh assertion over the request's body.** This proves that this particular request comes from the genuine app and was not altered. Because the counter must keep going up, a replayed assertion fails.
- **Environments (#158).** Staging accepts App Attest's development environment, so a build from Xcode can be tried on a device. Production accepts only the production environment. The local profile and the Simulator use a development token (#173), which no hosted profile accepts.
- **What App Attest does not prove** is that each device is a different person. The cost limits ([ADR 0017](0017-hosting-storage-and-cost.md)) cover that.
- **Authorization stays minimal.** There are no roles and no admin API over HTTP. A device sees only its own jobs, and anyone else gets "not found", not "forbidden".
- **Unauthenticated endpoints are limited per address,** without storing any address (#172). On 2026-10-04 the owner confirmed that no endpoint is exempt: `GET /health` is limited too. It still touches no database.
- **The new checks Apple adds on iOS 27 and macOS 27** (`launch_validation_category`, `bundle_version`, and the key-access policy on the Mac) are verified whenever they are present. Apple's fraud-metric receipt is left for later, if abuse appears.
- **A device unused for 90 days is erased** (#166). If the app comes back, it registers again.
- **The captured attestation may be committed** (#169, 2026-10-04). A real attestation from a development build is a test fixture. The app ID it carries is already public in the Xcode project, it holds no secret, and its key is a development key that is discarded after the capture.

**This ADR's own decisions.** The owner's decisions leave open which targets carry them out. These are consistent with [ADR 0014](0014-server-modular-monolith.md), [ADR 0016](0016-api-contract.md) and [ADR 0017](0017-hosting-storage-and-cost.md): their invariants hold, and the targets below are added to [modules.md](../modules.md).

- **(a) `ServerAuth` is the server's authentication layer.** It is an application-layer target, and [ADR 0014](0014-server-modular-monolith.md)'s invariant for `ServerApplication` applies to it: it imports no third-party package and no adapter. It holds:
  - **the use cases:**
    - **issue a challenge;**
    - **register a device:** consume the challenge, verify the attestation, then record the device. A key ID that the registry knows is never registered again, so a counter is never reset;
    - **open a session:** the request names the key ID it signs with, which is only how the registry finds the device. Consume the challenge, verify the assertion against the public key the registry holds, apply the counter rule, then issue a token;
    - **authenticate a request:** the session verifier checks the token's signature, algorithm and key ID and returns its claims. `ServerAuth` compares `exp` and `iat` with the injected clock, refuses a token whose App Attest environment claim the deployment does not accept, and returns the caller's `DeviceID` with how it was authenticated: by a session token, or by the verifier of the development token, which only the local profile installs;
    - **check the assertion over the bytes of a start's body,** with the key of the device that the session token names (see (g));
    - **limit the unauthenticated requests per address** (see (h));
  - **the ports it owns (R3):**
    - the challenge store. Consuming a challenge is atomic and happens before any verification, so of two requests that race for one challenge, exactly one proceeds;
    - the device registry, which holds what the flow records and when the device was created and last used;
    - the session signer and the session verifier;
    - the verifier of attestations and assertions, which covers the parts that need a cryptographic package;
    - the address hasher and the counts of unauthenticated requests per address (#172);
    - the verifier of the development token (see (f));
  - **the counter rule:** an assertion's counter must be greater than the stored one. The registry port accepts a counter only if it is greater, and stores it in the same transaction that accepts the assertion, so of two assertions that arrive at once with the same counter, exactly one is accepted (#170). The rule is in the port's contract, and each adapter passes the same suite;
  - **typed errors** (R7). None of them echoes an attestation, an assertion or a token. An unknown or erased device gets the one that tells the app to register again (#170).

  It uses the clock and the identifier generator that `ServerApplication` owns, so there is one of each (R2, R3). Challenges and token identifiers come from that generator, and its production adapter draws from the system's secure random source. Its log events are the typed events of `ServerApplication`'s port, and none carries a token, an assertion, an attestation or an address (#167).
- **(b) The caller's identity type is `DeviceID`, and `ServerApplication` owns it.** `ServerAuth` imports `ServerApplication`, and `ServerApplication` never imports `ServerAuth`.
  - Jobs, quotas and retention are `ServerApplication`'s, and they need a name for the caller and nothing of how it was proven. A job records its owner's `DeviceID`, and the quota counts per `DeviceID`.
  - **An idempotency key is unique per `DeviceID`,** and a known key returns its job only to its owner. Another device that sends the same key records its own job.
  - `ServerAuth` produces `DeviceID`s. The use cases of `ServerApplication` take one as an argument, and read it from no request and no task-local value.
  - **The other way round is rejected:** `ServerApplication` would depend on the authentication layer, and `ServerAuth` could no longer use `ServerApplication`'s clock and identifier generator without a cycle. A target for one type would add a target and no boundary.
  - What a `DeviceID` wraps, and how it relates to the key ID the registry stores, is #170's.
- **(c) The registry's port is `ServerAuth`'s, and `ServerApplication` keeps the ports that erasure and the push token go through.**
  - [ADR 0017](0017-hosting-storage-and-cost.md) (a) leaves the registry's port to this ADR: "a port of `ServerApplication` or of the target that #168 decides". It is `ServerAuth`'s, since `ServerAuth` holds the logic that uses it. `ServerApplication` cannot call it.
  - Erasing a device unused for 90 days, and sweeping the challenges and the counts of hashed addresses that have expired, are the schedule's run, a use case of `ServerApplication` ([ADR 0017](0017-hosting-storage-and-cost.md) (a), (c)). So `ServerApplication` owns the ports that run calls:
    - one erases the devices not used since a date, with the jobs and the quota counts they own;
    - the others sweep what has expired before a time: the challenges (#170) and the counts of addresses (#172).
  - **The device's push token** (#180) is set by the app and cleared when APNs rejects it. Both are use cases of `ServerApplication`, so `ServerApplication` owns a port for it: set, clear and read the token of a `DeviceID`. The registry's row holds it, and the store's adapter implements that port beside the registry.
  - The use cases need no more of authentication than a `DeviceID` and a time. The adapters of the stores implement these ports beside the registry, the challenge store and the counts, so one transaction does each.
  - `ServerApplication`'s Get and Delete compare the job's owner with the caller's `DeviceID`. A job that another device owns, and a job that does not exist, both get the same "not found".
- **(d) The server's adapters,** each in a target of its own. Each third-party package stays in the adapters that need it, and `JWTKit` also in the executable, which creates what the adapter runs on:
  - **`ServerAttestApple`** implements `ServerAuth`'s verifier of attestations and assertions for Apple's App Attest. It imports `ServerAuth` and the cryptographic packages that #169 chooses: `Crypto`, `X509` and `SwiftASN1`.
    - It decodes an attestation object with a small CBOR decoder of its own, checks the certificate chain against Apple's App Attest root, and runs the checks of #169, among them the iOS 27 and macOS 27 extensions when they are present. It verifies an assertion's signature and the app ID.
    - It is the boundary for Apple's bytes (R8): a cap on size, on nesting depth and on the number of certificates first, then a typed error for anything it does not understand, never a crash, never an echo of the input (R7).
    - Apple's root is fixed in this target and passed to the verifier as a parameter, so tests use a root of their own. The app ID and the App Attest environments the deployment accepts come from configuration.
  - **`ServerSessionJWT`** implements the session signer and the session verifier. It imports `ServerAuth` and `JWTKit`. A token is a JWT signed with Ed25519, and the adapter accepts EdDSA only, so any other algorithm, `none` included, is refused. Each key has an ID, and two keys verify during a rotation (#171). It checks the signature, the algorithm and the key ID and returns the claims. It never reads a clock: `ServerAuth` compares the times.
  - **`ServerAddressHash`** implements the address hasher. It imports `ServerAuth` and `Crypto`, and nothing else.
  - **`ServerStorePostgres`** gains the registry, the challenge store and the per-address counts, and implements the ports of `ServerApplication` that erasure, the sweeps and the push token go through. The tables of authentication share the one schema and the one migration history that [ADR 0017](0017-hosting-storage-and-cost.md) (a) gives the server's own tables, so one `migrate` builds them all. It imports `ServerAuth`, a new edge. Authentication keeps nothing else.
  - **`ServerLocalProfile`** gains the in-memory versions of the same ports, and the verifier of the development token. It imports `ServerAuth`, a new edge. The in-memory ports are adapters of a profile the executable ships, not test doubles (R14), and each passes the contract suite of its port (#170). The hosted profile installs its in-memory counts for `GET /health` alone (see (h)). The verifier is not a store: it has tests of its own (#173).
  - **`ServerHTTP`** holds the middleware. It imports `ServerAuth`, a new edge. It limits the unauthenticated requests, authenticates the bearer token and checks the assertion of a start, through `ServerAuth`'s use cases (see (g)). It carries the caller to its handlers in a task-local value, and passes it to each use case as an argument (#171). The 401, the 429 and the other problems it emits are documented in the spec for the operations it covers ([ADR 0016](0016-api-contract.md) (e)).
  - **The executable** creates what is infrastructure (R4):
    - it reads the session signing keys and the secret of the address hash from Secret Manager, and hands them in. It builds `JWTKit`'s key collection from the signing keys and hands it to `ServerSessionJWT`, so it imports `JWTKit`. Each environment has its own keys, one set per environment (#171);
    - only `serve` reads them, and they are readable by its identity alone ([ADR 0017](0017-hosting-storage-and-cost.md) (j)): the worker authenticates no device, because only the queue's identity may call it;
    - it reads the App Attest configuration and the development token's file, and hands them in;
    - in the local profile, there is no Secret Manager: it generates the signing keys and the address-hash secret at start and keeps them in memory;
    - it refuses to start when a hosted configuration accepts a development token, and when production accepts App Attest's development environment (#173, #169).
- **(e) The app's side is one new target, `PrestoCVAppAttest`.** It is an outbound adapter in the `PrestoCVApp` package.
  - **The port belongs to `PrestoCVIntegration`** ([ADR 0016](0016-api-contract.md)). It has three operations:
    - create a key, which returns its key ID;
    - attest a key against a challenge;
    - assert over the bytes it is given, which are a challenge, or a start's encoded body. It returns the assertion and the ID of the key that made it, so `PrestoCVAPIAdapter` can name the key in a session request without storing it.

    It speaks the workflow's language, and it has typed errors of its own, among them "unavailable" (no App Attest here) and "invalid key" (Apple says the key is no longer valid). `PrestoCVIntegration` carries R11's `platformCondition` like the other layers, so the port's owner holds no platform check.
  - **`PrestoCVAppAttest` implements the port and never calls the API.** `PrestoCVAPIAdapter` fetches the challenge, registers the device, opens and renews the session, and signs the encoded body of a start through the port. So the adapter's allow-list holds no target of `PrestoCVAPI` and no other adapter.
  - **`PrestoCVAPIAdapter`'s middleware signs the encoded bytes of a start and sends exactly those bytes.** It serialises every assertion of a device, renewals of the session included, so the counter goes up in the order the server sees (#179). It renews a session on a 401, or from a lifetime the server gives, and never by comparing its own clock with the token's `exp`.
  - **`PrestoCVAppAttest` imports** `PrestoCVIntegration`, `DeviceCheck`, `CryptoKit` (the assertion signs a hash of the bytes), `Security` (the Keychain) and Foundation.
  - **Its platforms:** it builds on iOS 26 and macOS 26, like the rest of the app. The App Attest adapter is marked available from iOS 26 and macOS 27. Every file is wrapped entirely in its platform condition, so the package still builds on Linux (R11).
    - R11 lets an adapter hold platform conditions, so its detector does not run on this target, and it does not check that a file is wrapped. The Linux CI job does: it builds `PrestoCVApp`, so a file that imports `DeviceCheck` outside its condition fails there.
  - **The key's ID is kept in the Keychain, inside the adapter,** available only on this device. Only this adapter stores it, and the port hands it out with each key and each assertion, so a port to store it would be a seam with one consumer (R3). The adapter reaches Apple's service and the Keychain through seams of its own, internal to the target, so that a fake of each tests it (#174).
  - **Where there is no App Attest,** the app offers no tailoring and says why (R13: the view words it, #174), and the port never returns a fake success (R14).
    - `PrestoCVAppAttest` holds a second adapter of the port, which throws the typed "unavailable" error. It sits outside the `@available` mark and inside the file wrap, so the target builds on macOS 26 and the adapter is in a target of its own (R3).
    - On macOS 26 the composition root's `#available` check installs it.
    - In the Simulator, or on a device whose service reports it unsupported, the App Attest adapter gates on `isSupported` and throws the same error.
- **(f) The development token, end to end** (#173). It is for the local profile and the Simulator, which have no Apple behind them.
  - **It stands in for the whole chain:** the challenge, the registration, the session token and the assertion over a start's body. The app sends it as the bearer token and nothing else.
  - **On the server,** the verifier of the development token is a port of `ServerAuth`. Its one adapter is in `ServerLocalProfile`, which compares in constant time and reads no file: the executable reads the token's file and hands the token in. `ServerAuth` authenticates the token as one fixed `DeviceID`, which no key ID can equal.
  - **A start skips its assertion because of how the caller was authenticated,** by the development token's verifier, which only the local profile installs. It never skips it because of a `DeviceID`'s value.
  - **The server's image is one binary,** so the verifier's code is present in a hosted image. What keeps a hosted profile from accepting it is the composition, which installs the verifier only in the local profile, the refusal to start when a hosted configuration asks for it, and a test (#173). In a hosted profile the token is not a valid JWT, and it gets 401.
  - **In the app,** the composition root reads the token from the Xcode scheme's environment in a debug build only, since only the root reads ambient state (R2, R4).
    - In a debug build that has a token and whose server is the local profile's address, the root installs the token path in place of the attestation, and hands it the token. The root sends the token only to the local profile's loopback address, and the only server that accepts it listens on 127.0.0.1 alone ([ADR 0014](0014-server-modular-monolith.md)), so nothing beyond the machine can use it.
    - The token path sends no push token (#173, #180): the development device has none.
    - In any other case the root installs the App Attest adapter, or the "unavailable" one where there is no App Attest. So the Simulator tailors only against the local profile.
    - A release build has no code path that sends the token, and #173's CI check proves it. Which target holds the token path is #173's and #179's, inside the allow-lists of [modules.md](../modules.md).
- **(g) Who checks what:**

| What | Where | How |
|---|---|---|
| The unauthenticated requests: `GET /health`, challenges, registration and opening a session | `ServerHTTP`'s middleware, first | Each is limited per address through `ServerAuth` (#172). Over a limit the API answers 429 with when to retry |
| `GET /health` | `ServerHTTP` | Needs no token, and touches no database: its counts live in the instance's memory, so a probe never wakes the database and a suspended database never fails it |
| The token | `ServerHTTP`'s middleware, through `ServerAuth`'s authenticate-a-request use case | The session verifier checks the signature, the algorithm and the key ID, without the database. `ServerAuth` checks `exp`, `iat` and the environment claim against the injected clock and the deployment. A missing or invalid token gets 401 |
| A start's assertion | `ServerHTTP`'s middleware, after the token | The middleware reads the raw body once, under its size cap (R8), and gives `ServerAuth` those bytes and the assertion. The verifier checks the signature over the bytes as received, before any decoding, with the key of the device that the token names. A key or a key ID that the request names is never used. The registry accepts the counter only if it is greater, in one transaction. The handler then decodes that same buffer. A device the registry does not know gets the error that tells the app to register again |
| A job's owner | `ServerApplication`'s Get and Delete | The job's owner is compared with the caller's `DeviceID`; another device's job gets "not found" |

  Which operation needs which kind of check is #171's, and how the spec carries the token and the assertion is #176's. The assertion covers the body's bytes and nothing else: the idempotency and version headers are outside it.
- **(h) The unauthenticated requests are limited per address, and no address is stored in clear** (#172). The counts and the hasher are ports of `ServerAuth`, with a Postgres adapter and an in-memory one for the counts, and `ServerAddressHash` for the hasher.
  - **The hash is keyed.** It is an HMAC, under a daily key that is derived from a secret and the day. The day comes from `ServerAuth`'s injected clock and is an argument of the hasher: the adapter reads no clock. The executable reads the secret from Secret Manager, and it is never stored beside the counts. A salt would not be enough: an IPv4 address has few values, so a hash with a known salt can be reversed.
  - **An address reaches the counts only as that hash,** and never reaches a log or the database in clear. The platform's own request logs, which carry the address, are excluded in `infra/` ([ADR 0017](0017-hosting-storage-and-cost.md) (k)). The sweep of expired counts is in (c).
  - **`GET /health` is counted in memory.** In the hosted profile the executable installs the in-memory adapter of the counts, which `ServerLocalProfile` holds, for `GET /health` alone, so a probe never touches the database. Each instance counts what it sees, and the instance caps ([ADR 0017](0017-hosting-storage-and-cost.md) (g)) bound the total.
  - What address the middleware trusts, and how an IPv6 address is grouped, are #172's.
- **(i) Invariants of [ADR 0014](0014-server-modular-monolith.md) hold.** `ServerApplication` imports no third-party package and no adapter, and it imports no `ServerAuth` either. Among the package's production targets, only `ServerHTTP` imports the targets of `PrestoCVAPI`. Only the executable creates infrastructure, so the signing keys, the address-hash secret and the development token's file are read there and handed in.

## Consequences

- **What becomes possible:**
  - no account, and no personal data to know who is calling. The registry holds a key ID, a public key, a counter, an environment, timestamps and, once the app gives one, a push token. None of them names a person, and no address is stored in clear;
  - a cost that is tied to genuine installations: the per-device limit counts against a key that Apple attested for a genuine copy of the app;
  - a session that costs no query to verify, and a start that cannot be replayed or altered.
- **Costs:**
  - **A user on macOS 26 cannot tailor.** The app says why, and the rest of the app works as before.
  - **The real flow needs a device.** The Simulator has no App Attest, so it runs on the development token, against the local profile only. A build from Xcode on a device runs the real flow against staging.
  - **App Attest has per-device limits of its own, and it depends on Apple's service.** A registration can fail for either. It is not an error of the server, and the app tries again later.
  - **One device is not one person.** A person with two devices has two daily counts. The limit for everyone ([ADR 0017](0017-hosting-storage-and-cost.md)) bounds the total.
  - **A device that keeps reinstalling can spend the day's 100 tailorings alone.** Each new key is a new device with a new daily count, and Apple's own limits are the only brake. The fraud-metric receipt, which the owner left for later, is the mitigation to add if abuse appears.
  - **The counter orders a device's assertions.** Two starts from one device that arrive out of order lose the one with the lower counter, so concurrent starts from a device serialise, and the refused one is signed again. A retry of a start is signed again as well, and the idempotency key returns the first job ([ADR 0017](0017-hosting-storage-and-cost.md)).
  - **A start's assertion covers the body and nothing else.** The idempotency key and the version headers are outside it.
  - **A lost key means registering again.** A reinstall, a restore to another device, a key that Apple invalidates and a return after the 90-day erasure each leave the app with a key the server does not know. The app creates a new key, which is a new device, with a new daily count and no access to the old device's jobs, which the retention erases.
  - **A session token is not revoked.** It is valid for 15 minutes whatever happens to its device. An erased device cannot start a tailoring in that time, because a start needs an assertion and the registry no longer knows the device.
  - **The development token is a secret on a developer's machine,** in a file outside the repository. A debug build holds a code path that a release must not, and CI checks it (#173).
  - **Five more targets, new edges between them, and more third-party packages to pin:** `Crypto`, `X509` and `SwiftASN1` in `ServerAttestApple`, `Crypto` in `ServerAddressHash`, and `JWTKit`. The checker's `--packages` rule holds them, and each is pinned in the committed `Package.resolved`.
  - **`PrestoCVAppAttest` is empty on Linux,** since every file is wrapped in its platform condition, so Linux builds it and cannot test it. Its tests run on the Apple hosts.
- **Assigned to #169:** its verifier is written in `ServerAttestApple`, not in `ServerAuth`, and its tests live there. Its fixture is the owner's decision of 2026-10-04, above.
- **Enforced by:**
  - the compiler, through the target graph:
    - `ServerAuth` imports no adapter and no third-party package, so the use cases are tested without a database and without Apple;
    - `ServerApplication` cannot import `ServerAuth`;
    - the app's attestation adapter imports no target of `PrestoCVAPI`, and no other adapter;
  - the checker, once the targets exist:
    - the allow-lists of [modules.md](../modules.md): `X509` and `SwiftASN1` only in `ServerAttestApple`, `Crypto` there and in `ServerAddressHash`, `JWTKit` only in `ServerSessionJWT` and the executable, `DeviceCheck` only in `PrestoCVAppAttest`, and `ServerAuth` imported only by the adapters, the middleware and the executable;
    - `--packages` for the manifests' dependencies;
    - R2's detectors on `ServerAuth` refuse `Date()`, `UUID()` and ambient state. That every challenge and every token identifier comes from the injected generator is review's;
    - R4's detectors on every server target except the executable refuse the infrastructure types in `rules.json` and the ambient accessors. That no adapter reads a key from a secret store or from the environment is review's;
    - R7's `swallowedError` on the new targets;
    - R11's `platformCondition` on `ServerAuth` and on `PrestoCVIntegration`, as on the other layers, so no platform check enters them. It does not run on `PrestoCVAppAttest`, which R11 lets hold platform conditions;
  - CI, for what the checker does not see:
    - the Linux job, which builds `PrestoCVApp`, so a file of `PrestoCVAppAttest` that imports `DeviceCheck` outside its platform condition fails there;
    - #173's check that fails if a release build contains the development-token code path;
  - tests:
    - #169: a certificate chain built for the tests, a valid attestation, and each check failing on its own; an assertion with a wrong signature, and one with another app ID; the decoder fuzzed on Linux with a committed corpus, and its bounds on size, depth and certificates; a real attestation from a development build as a fixture;
    - #170: the contract suite of the registry and the challenge store, which both adapters pass: a counter that did not go up, two assertions racing, an unknown device, a used or expired challenge, two requests racing for one challenge, and a known key ID that is not registered again and whose counter is not reset. The race against Postgres runs in a container in the Linux CI job ([ADR 0017](0017-hosting-storage-and-cost.md), #160). The use cases' tests fake the verifier;
    - #171: an expired token, a token signed by an unknown key, the wrong algorithm, `none` included, a rotation with two keys, a token whose App Attest environment claim the deployment does not accept, each kind of operation, an assertion that does not match the body, a valid token with another device's assertion, which is refused, the same JSON with different bytes, which is refused, and a job of another device, which gets "not found";
    - #157 and #165: an idempotency key is unique per `DeviceID`, and a known key returns its job only to its owner;
    - #172: each limit, on challenges, registration and opening a session, the change of the daily key, a request over the limit, `GET /health` limited too and touching no database, and no address in a log or in the database in clear;
    - #173: the development token's file permissions, a wrong token, and a hosted configuration that tries to accept it, which the executable refuses at start;
    - the executable: production that accepts App Attest's development environment is refused at start (#169);
    - #174 and #179: the attestation adapter against a fake of Apple's service, for each step and each failure; `PrestoCVAPIAdapter` against a fake of the port;
  - review, for what the above do not see: that no adapter other than `ServerAttestApple`, `ServerSessionJWT` and the development token's verifier in `ServerLocalProfile` decides whether a credential is valid, and that a development build on a device completes the whole flow against staging (#174).

## Alternatives considered

- **Accounts, with Sign in with Apple.** Rejected by the owner: the caller is an installation, there are no accounts, and there is no Sign in with Apple and no account fallback.
- **Anonymous API keys embedded in the app.** Rejected: anyone can extract a key from the binary or from the traffic, and a key proves nothing about the caller.
- **DeviceCheck's two bits only.** Rejected: they give a device two bits of state and no proof for each request, so a start's body could not be bound to the genuine app.
- **Long-lived sessions.** Rejected: the owner decided that a session token is valid for 15 minutes.
- **An HMAC secret per device, without attestation.** Rejected: nothing shows that the secret lives in a genuine copy of the app, and a script could register as many devices as it likes.
- **A session only, with no assertion over a start's body.** Rejected: the owner decided that a start, which costs money, also needs a fresh assertion over its body.
- **Hashing an address with a salt that changes every day.** Rejected: an IPv4 address has few values, so a hash with a known salt can be reversed. The key is a secret that the database never holds.
- **The verifier inside `ServerAuth`.** Rejected: `ServerAuth` is an application layer, and it imports no third-party package. The cryptographic packages belong to an adapter.
- **The address hash in `ServerAttestApple`.** Rejected: it is not Apple's, and a target should change for one reason.
- **The identity type in `ServerAuth`, imported by `ServerApplication`.** Rejected in (b).
- **The registry's port in `ServerApplication`.** Rejected: `ServerApplication` owns the jobs, and authentication would grow inside it. It keeps only the ports that erasure, the sweeps and the push token go through, which name a `DeviceID` or a time and nothing of how a device was proven.
- **The "unavailable" adapter in `PrestoCVIntegration`.** Rejected: an adapter belongs in an adapter target (R3), and `PrestoCVAppAttest` already builds where it must run.
- **The key's ID behind a port.** Rejected: only the attestation adapter stores it, and the port hands it out.

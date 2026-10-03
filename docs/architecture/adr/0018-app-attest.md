# 0018. Authenticate the app's installations with App Attest, not accounts

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0014](0014-server-modular-monolith.md), [ADR 0016](0016-api-contract.md), [ADR 0017](0017-hosting-storage-and-cost.md), R1, R2, R3, R4, R7, R8, R11, R14, issues #133, #158, #166, #168, #169, #170, #171, #172, #173, #174, #179

## Context

- A tailoring costs money and carries a person's CV ([ADR 0013](0013-cv-tailoring-context.md), [ADR 0017](0017-hosting-storage-and-cost.md)). The server must know that a caller is a genuine copy of the app, and it must count tailorings per caller, because the first cost limit is 5 a device a day.
- PrestoCV has no accounts. The server should hold no email, no name and no password to know who is calling.
- Apple's App Attest fits. The app creates a key in the Secure Enclave and has Apple attest it. The server verifies the attestation. From then on the key signs challenges and requests, and a counter makes each signature single-use.
- App Attest does not exist on macOS 26 ([WWDC26, session 201](https://developer.apple.com/videos/play/wwdc2026/201/)), and it does not exist in the Simulator. The local profile has no Apple behind it either.
- Earlier ADRs already assume it, and leave its architecture to this one:
  - [ADR 0014](0014-server-modular-monolith.md): staging accepts App Attest's development environment, and the authentication targets are "set by the decisions of their own tickets (#168)";
  - [ADR 0016](0016-api-contract.md): the spec has endpoints for challenges, registration and sessions, and `PrestoCVAPIAdapter` signs a start through an attestation port that `PrestoCVIntegration` owns;
  - [ADR 0017](0017-hosting-storage-and-cost.md): the device registry's adapters are in `ServerStorePostgres` and `ServerLocalProfile`, its port is "a port of `ServerApplication` or of the target that #168 decides", a device unused for 90 days is erased, and Apple is one of the processors.
- The owner decided on 2026-10-02 (#168):
  - that the caller is an installation, authenticated by App Attest and nothing else, with the minimum operating systems that implies;
  - the flow: challenge, attestation, assertion, session token, and an assertion over the body of a start;
  - the environments, what App Attest does not prove, and the minimal authorization;
  - the limit on unauthenticated endpoints, the checks of iOS 27 and macOS 27, and the erasure of an idle device.
- This ADR's own architecture:
  - the server targets that carry authentication, and what each imports;
  - the identity type that jobs and authentication share, and who owns the registry's port;
  - the app's attestation adapter, where it keeps the key, and what the app does where there is no App Attest;
  - who checks what, and where the development token sits.

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
- **Unauthenticated endpoints are limited per address,** without storing any address (#172).
- **The new checks Apple adds on iOS 27 and macOS 27** (`launch_validation_category`, `bundle_version`, and the key-access policy on the Mac) are verified whenever they are present. Apple's fraud-metric receipt is left for later, if abuse appears.
- **A device unused for 90 days is erased** (#166). If the app comes back, it registers again.

**This ADR's own decisions.** The owner's decisions leave open which targets carry them out. These are consistent with [ADR 0014](0014-server-modular-monolith.md), [ADR 0016](0016-api-contract.md) and [ADR 0017](0017-hosting-storage-and-cost.md): their invariants hold, and the targets below are added to [modules.md](../modules.md).

- **(a) `ServerAuth` is the server's authentication layer.** It is an application-layer target, and [ADR 0014](0014-server-modular-monolith.md)'s invariant for `ServerApplication` applies to it: it imports no third-party package and no adapter. It holds:
  - **the use cases:** issue a challenge, register a device (verify an attestation, then record the device), open a session (verify an assertion over a challenge, then issue a token), and check the assertion over the body of a start;
  - **the ports it owns (R3):**
    - the challenge store;
    - the device registry, which holds what the flow records and what #170 adds: the push token (#180), and when the device was created and last used;
    - the session signer and the session verifier;
    - the verifier of attestations and assertions, which covers the parts that need a cryptographic package;
    - the counts of unauthenticated requests per address (#172);
    - the verifier of the development token (see (f));
  - **the counter rule:** an assertion's counter must be greater than the stored one. The registry port accepts a counter only if it is greater, and stores it in the same transaction that accepts the assertion, so of two assertions that arrive at once with the same counter, exactly one is accepted (#170). The rule is in the port's contract, and each adapter passes the same suite;
  - **typed errors** (R7). None of them echoes an attestation, an assertion or a token. An unknown or erased device gets the one that tells the app to register again (#170).

  It uses the clock and the identifier generator that `ServerApplication` owns, so there is one of each (R2, R3). The identifier generator's production adapter draws from the system's secure random source, since challenges and token identifiers must not be guessable. Its log events are the typed events of `ServerApplication`'s port, and none carries a token, an assertion, an attestation or an address (#167).
- **(b) The caller's identity type is `DeviceID`, and `ServerApplication` owns it.** `ServerAuth` imports `ServerApplication`, and `ServerApplication` never imports `ServerAuth`.
  - Jobs, quotas and retention are `ServerApplication`'s, and they need a name for the caller and nothing of how it was proven. A job records its owner's `DeviceID`, and the quota counts per `DeviceID`.
  - `ServerAuth` produces `DeviceID`s. The use cases of `ServerApplication` take one as an argument, and read it from no request and no task-local value.
  - **The other way round is rejected:** `ServerApplication` would depend on the authentication layer, and `ServerAuth` could no longer use `ServerApplication`'s clock and identifier generator without a cycle. A target for one type would add a target and no boundary.
  - What a `DeviceID` wraps, and how it relates to the key ID the registry stores, is #170's.
- **(c) The registry's port is `ServerAuth`'s, and `ServerApplication` keeps the ports that erasure calls.**
  - [ADR 0017](0017-hosting-storage-and-cost.md) (a) leaves the registry's port to this ADR: "a port of `ServerApplication` or of the target that #168 decides". It is `ServerAuth`'s, since `ServerAuth` holds the logic that uses it. `ServerApplication` cannot call it.
  - Erasing a device unused for 90 days, and sweeping the challenges and the counts of hashed addresses that have expired, are the schedule's run, a use case of `ServerApplication` ([ADR 0017](0017-hosting-storage-and-cost.md) (a), (c)). So `ServerApplication` owns the ports that run calls:
    - one erases the devices not used since a date, with the jobs and the quota counts they own;
    - the others sweep what has expired before a time: the challenges (#170) and the counts of addresses (#172).
  - The use case needs no more of authentication than a time. The adapters of the stores implement these ports beside the registry, the challenge store and the counts, so one transaction does each.
  - `ServerApplication`'s Get and Delete compare the job's owner with the caller's `DeviceID`. A job that another device owns, and a job that does not exist, both get the same "not found".
- **(d) The server's adapters,** each in a target of its own, so each third-party package stays inside the one adapter that needs it:
  - **`ServerAttestApple`** implements `ServerAuth`'s verifier of attestations and assertions for Apple's App Attest. It imports `ServerAuth` and the cryptographic packages that #169 chooses.
    - It decodes an attestation object with a small CBOR decoder of its own, checks the certificate chain against Apple's App Attest root, and runs the checks of #169, among them the iOS 27 and macOS 27 extensions when they are present. It verifies an assertion's signature and the app ID.
    - It is the boundary for Apple's bytes (R8): a size cap first, then a typed error for anything it does not understand, never a crash, never an echo of the input (R7).
    - Apple's root is fixed in this target and passed to the verifier as a parameter, so tests use a root of their own. The app ID and the App Attest environments the deployment accepts come from configuration.
  - **`ServerSessionJWT`** implements the session signer and the session verifier. It imports `ServerAuth` and `JWTKit`. A token is a JWT signed with Ed25519, and the adapter accepts EdDSA only, so any other algorithm, `none` included, is refused. Each key has an ID, and two keys verify during a rotation (#171).
  - **`ServerStorePostgres`** gains the registry, the challenge store and the per-address counts, and implements the ports of `ServerApplication` that erasure and the sweeps go through. The tables of authentication share the one schema and the one migration history that [ADR 0017](0017-hosting-storage-and-cost.md) (a) gives the server's own tables, since #168 has no reason to decide otherwise. It imports `ServerAuth`, a new edge. Authentication keeps nothing else.
  - **`ServerLocalProfile`** gains the in-memory versions of the same ports, and the development token's verifier. It imports `ServerAuth`, a new edge. They are adapters of a profile the executable ships, not test doubles (R14). Each passes the contract suite of its port (#170).
  - **`ServerHTTP`** holds the middleware that checks the bearer token and the body's assertion, through `ServerAuth`'s ports. It imports `ServerAuth`, a new edge. It carries the caller to its handlers in a task-local value, and passes it to each use case as an argument (#171). The 401 and the other problems it emits are documented in the spec for the operations it covers ([ADR 0016](0016-api-contract.md) (e)).
  - **The executable** creates what is infrastructure (R4): it reads the session signing keys from Secret Manager, builds `JWTKit`'s key collection from them and hands it to `ServerSessionJWT`, so it imports `JWTKit`. It reads the App Attest configuration and the development token's file, and hands them in. Only `serve` reads the signing keys, and they are readable by its identity alone ([ADR 0017](0017-hosting-storage-and-cost.md) (j)): the worker authenticates no device, because only the queue's identity may call it.
- **(e) The app's side is one new target, `PrestoCVAppAttest`.** It is an outbound adapter in the `PrestoCVApp` package.
  - **The port belongs to `PrestoCVIntegration`** ([ADR 0016](0016-api-contract.md)): create a key, attest it against a challenge, sign a body. It speaks the workflow's language, and it has typed errors of its own, among them "unavailable" (no App Attest here) and "invalid key" (Apple says the key is no longer valid).
  - **`PrestoCVAppAttest` implements the port and never calls the API.** `PrestoCVAPIAdapter` fetches the challenge, registers the device, opens and renews the session, and signs the encoded body of a start through the port. So the adapter's allow-list holds no target of `PrestoCVAPI` and no other adapter.
  - **It imports** `PrestoCVIntegration`, `DeviceCheck`, `CryptoKit` (the assertion signs a hash of the body), `Security` (the Keychain) and Foundation.
  - **Its platforms are iOS 26 and later, and macOS 27 and later.** The adapter is marked available from those versions, and every file is wrapped entirely in its platform condition, so the package still builds on Linux (R11). The checker's `platformCondition` detector holds it.
  - **The key's ID is kept in the Keychain, inside the adapter,** available only on this device. Only this adapter uses it, so a port for it would be a seam with one consumer (R3). The adapter reaches Apple's service and the Keychain through seams of its own, internal to the target, so that a fake of each tests it (#174).
  - **Where there is no App Attest,** the app offers no tailoring and says why (R13: the view words it, #174), and the port never returns a fake success (R14).
    - On macOS 26 the composition root's `#available` check installs an adapter that throws the typed "unavailable" error. It lives in `PrestoCVIntegration`, beside the port it implements: it holds no platform code and no infrastructure, and it must run where `PrestoCVAppAttest` cannot.
    - In the Simulator, or on a device whose service reports it unsupported, `PrestoCVAppAttest` gates on `isSupported` and throws the same error.
  - **The Simulator and the local profile use the development token** (#173). In a debug build the composition root reads it from the Xcode scheme's environment, since only the root reads ambient state (R2, R4), and hands it to the code that sends it. A release build has no code path that sends it, and #173's CI check proves it.
- **(f) The development token on the server** is a port of `ServerAuth`: the verifier of the development token. Its one adapter is in `ServerLocalProfile`, which compares in constant time and reads no file: the executable reads the token's file and hands the token in (#173). The server's image is one binary, so that code is present in a hosted image. What keeps a hosted profile from accepting it is the composition, which installs the verifier only in the local profile and refuses to start when a hosted configuration asks for it, and a test (#173).
- **(g) Who checks what:**

| What | Where | How |
|---|---|---|
| The token's signature, algorithm, key ID and expiry | `ServerHTTP`'s middleware | Through `ServerAuth`'s session verifier, without the database. A missing or invalid token gets 401 |
| The assertion over a start's body | `ServerHTTP`'s middleware, after the token | The body, under its size cap (R8), and the assertion go to `ServerAuth`. The verifier checks the signature, and the registry accepts the counter only if it is greater, in one transaction. A device the registry does not know gets the error that tells the app to register again |
| A job's owner | `ServerApplication`'s Get and Delete | The job's owner is compared with the caller's `DeviceID`; another device's job gets "not found" |
| The public endpoints | `ServerHTTP`, through `ServerAuth` | Health, challenges and registration need no token. Challenges and registration are limited per address (#172) |

  Which operation needs which kind of check is #171's, and how the spec carries the token and the assertion is #176's.
- **(h) The per-address counts of #172** are a port of `ServerAuth`, with a Postgres adapter and an in-memory one. An address reaches them only as a hash with a salt that changes every day, and never reaches a log or the database in clear. The platform's own request logs, which carry the address, are excluded in `infra/` ([ADR 0017](0017-hosting-storage-and-cost.md) (k)). The sweep of expired counts is in (c). Where the hash is computed is #172's, inside the allow-lists of [modules.md](../modules.md), which #172 may extend without a new ADR while [ADR 0014](0014-server-modular-monolith.md)'s invariants hold.
- **(i) Invariants of [ADR 0014](0014-server-modular-monolith.md) hold.** `ServerApplication` imports no third-party package and no adapter, and it imports no `ServerAuth` either. Among the package's production targets, only `ServerHTTP` imports the targets of `PrestoCVAPI`. Only the executable creates infrastructure, so the signing keys and the development token's file are read there and handed in.

## Consequences

- **What becomes possible:**
  - no account, and no personal data to know who is calling. The registry holds a key ID, a public key, a counter, an environment, timestamps and, once the app gives one, a push token. None of them names a person, and no address is stored;
  - a cost that is tied to genuine installations: the per-device limit counts against a key that Apple attested for a genuine copy of the app;
  - a session that costs no query to verify, and a start that cannot be replayed or altered.
- **Costs:**
  - **A user on macOS 26 cannot tailor.** The app says why, and the rest of the app works as before.
  - **The real flow needs a device.** The Simulator has no App Attest, so it runs on the development token. A build from Xcode on a device runs the real flow against staging.
  - **App Attest has per-device limits of its own, and it depends on Apple's service.** A registration can fail for either. It is not an error of the server, and the app tries again later.
  - **One device is not one person.** A person with two devices has two daily counts. The limit for everyone ([ADR 0017](0017-hosting-storage-and-cost.md)) bounds the total.
  - **The counter orders a device's assertions.** Two starts from one device that arrive out of order lose the one with the lower counter, so concurrent starts from a device serialise, and the refused one is signed again. A retry of a start is signed again as well, and the idempotency key returns the first job ([ADR 0017](0017-hosting-storage-and-cost.md)).
  - **A lost key means registering again.** A reinstall, a restore to another device and a key that Apple invalidates each leave the app with a key the server does not know. The new key is a new device, with a new daily count and no access to the old device's jobs, which the retention erases. The limit for everyone bounds the extra count.
  - **A session token is not revoked.** It is valid for 15 minutes whatever happens to its device. An erased device cannot start a tailoring in that time, because a start needs an assertion and the registry no longer knows the device.
  - **The development token is a secret on a developer's machine,** in a file outside the repository. A debug build holds a code path that a release must not, and CI checks it (#173).
  - **Four more targets, new edges between them, and more third-party packages to pin:** the cryptographic packages in `ServerAttestApple`, and `JWTKit`. The checker's `--packages` rule holds them, and each is pinned in the committed `Package.resolved`.
  - **`PrestoCVAppAttest` is empty on Linux,** since every file is wrapped in its platform condition, so Linux builds it and cannot test it. Its tests run on the Apple hosts.
- **Assigned to #169:** its verifier is written in `ServerAttestApple`, not in `ServerAuth` as the ticket first says, and its tests live there.
- **Enforced by:**
  - the compiler, through the target graph:
    - `ServerAuth` imports no adapter and no third-party package, so the use cases and the counter rule are tested without a database and without Apple;
    - `ServerApplication` cannot import `ServerAuth`;
    - the app's attestation adapter imports no target of `PrestoCVAPI`, and no other adapter;
  - the checker:
    - the allow-lists of [modules.md](../modules.md): the cryptographic packages only in `ServerAttestApple`, `JWTKit` only in `ServerSessionJWT` and the executable, `DeviceCheck` only in `PrestoCVAppAttest`, and `ServerAuth` imported only by the adapters, the middleware and the executable;
    - `--packages` for the manifests' dependencies;
    - R2's detectors on `ServerAuth`, so time and identifiers come from the injected clock and generator;
    - R4's detectors on every server target except the executable, so keys and files are read only in the root;
    - R7's `swallowedError` on the new targets;
    - R11's `platformCondition` on `PrestoCVAppAttest`, and the Linux CI job, which builds the package with that target empty;
  - tests:
    - #169: a certificate chain built for the tests, a valid attestation, and each check failing on its own; the decoder fuzzed on Linux with a committed corpus; a real attestation from a development build as a fixture, with no personal data;
    - #170: a valid assertion, a wrong signature, a counter that did not go up, two assertions racing, an unknown device, and a used or expired challenge, all in the contract suite that both registry adapters pass;
    - #171: an expired token, a token signed by an unknown key, the wrong algorithm, `none` included, a rotation with two keys, each kind of operation, an assertion that does not match the body, and a job of another device, which gets "not found";
    - #172: each limit, the change of salt, a request over the limit, and no address in a log or in the database in clear;
    - #173: the development token's file permissions, a wrong token, and a hosted configuration that tries to accept it;
    - #174 and #179: the attestation adapter against a fake of Apple's service, for each step and each failure; `PrestoCVAPIAdapter` against a fake of the port;
  - CI (#173): a check that fails if a release build contains the development-token code path;
  - review, for what the above do not see: that no adapter other than `ServerAttestApple` and `ServerSessionJWT` decides whether a credential is valid, that the identifier generator draws from the system's secure random source, and that a development build on a device completes the whole flow against staging (#174).

## Alternatives considered

- **Accounts, with Sign in with Apple.** Rejected by the owner: the caller is an installation, there are no accounts, and there is no Sign in with Apple and no account fallback.
- **Anonymous API keys embedded in the app.** Rejected: anyone can extract a key from the binary or from the traffic, and a key proves nothing about the caller.
- **DeviceCheck's two bits only.** Rejected: they give a device two bits of state and no proof for each request, so a start's body could not be bound to the genuine app.
- **Long-lived sessions.** Rejected by the owner: a session token is valid for 15 minutes.
- **An HMAC secret per device, without attestation.** Rejected: nothing shows that the secret lives in a genuine copy of the app, and a script could register as many devices as it likes.
- **A session only, with no assertion over a start's body.** Rejected by the owner: a start costs money, so each start proves itself.
- **The verifier inside `ServerAuth`.** Rejected: `ServerAuth` is an application layer, and it imports no third-party package. The cryptographic packages belong to an adapter.
- **The identity type in `ServerAuth`, imported by `ServerApplication`.** Rejected in (b).
- **The registry's port in `ServerApplication`.** Rejected: `ServerApplication` owns the jobs, and authentication would grow inside it. It keeps only the ports that erasure calls, which name a time and nothing of how a device was proven.
- **The key's ID behind a port.** Rejected: only the attestation adapter uses it.

# 0015. Reach models through configured providers, held to the deployment's data policy

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0013](0013-cv-tailoring-context.md), [ADR 0014](0014-server-modular-monolith.md), R2, R3, R4, R7, R8, issues #133, #149, #150, #154, #155

## Context

- A tailoring sends a user's CV to a model. Which model sees it, and what its provider does with it, is a decision of each deployment.
- That decision is written in the deployment's configuration and checked by the server. It is never taken on trust.
- [ADR 0013](0013-cv-tailoring-context.md) puts the outbound inference port in `Tailoring`, which owns the loop. [ADR 0014](0014-server-modular-monolith.md) puts the adapters behind it in `ServerInference`, and lets only the worker hold the providers' keys. Neither says which providers exist, how one is chosen, or what a deployment may demand of them.
- The app's consent text (#190) and `GET /v1/policy` (#175) need a policy that is true of what the server does.
- The owner decided on 2026-10-02 (#149) the provider pattern, the first adapter and its dialects, the registry and what it lists, the enforcement of the deployment's policy, the choice of the model by the server, what is known before a run, and that provider names and model identifiers stay out of the repository. Where the data policy's types and its rule live, how `ServerInference` and the executable share the work, and who reads the secrets are this ADR's own architecture.

## Decision

- **A provider pattern.** The tailoring loop talks to one port, the inference port of `Tailoring` (#150). Providers are adapters behind it, on the server.
- **The first adapter speaks the chat-completions API that most providers and local model servers share** (#154). That one adapter reaches a hosted router of many providers, a model served on the same machine, and most commercial APIs.
  - An endpoint's quirks are its **dialect**: its routing preferences, for example, or whether it supports structured output. The configuration sets it.
  - A native adapter is written only for a provider with no compatible endpoint.
  - The hosted router is one provider among others, not the architecture.
- **A registry built from configuration** (#155). It lists the providers in order of preference. For each one it holds:
  - its endpoint;
  - the *name* of the secret that holds its key, never the key;
  - the models it may use;
  - what it can do: structured output and context size;
  - **its data policy**: whether it keeps prompts, whether it trains on them, and which region it runs in.
- **The deployment's policy is enforced.** The deployment states what it requires, for example no retention and EU only. The server refuses to start when a configured provider does not meet it. A failing provider falls back to the next one, but only within the policy.
- **The server picks the model,** from the configuration. The app never names one, so a model can change without an app release.
- **Known before a run:** which provider will answer, and what it charges. The app can read the policy, so what it tells the user matches what happens.
- **Names stay out of the repository.** Provider names and model identifiers live in the deployment's configuration. Tests use invented ones.
- **The data policy's types and its rule live in `ServerApplication`.** This is this ADR's own architecture.
  - The types are what a provider declares (whether it keeps prompts, whether it trains on them, its region) and what a deployment requires.
  - The one rule, "a provider meets a policy", exists once: the provider keeps prompts only where the policy allows it, trains on them only where the policy allows it, and runs in a region the policy accepts. It is pure and tested without I/O (R2).
  - They sit beside the data-policy port that `GET /v1/policy` reads (#155, #175). `ServerHTTP` imports `ServerApplication` and not `ServerInference`, so it reaches the policy through that port (R3).
- **`ServerInference` holds the registry, the selection and the fallback.** It implements `Tailoring`'s inference port and `ServerApplication`'s data-policy port.
  - The registry applies the rule of `ServerApplication` when it is built, so a provider that does not meet the policy is not in it and no fallback can reach one.
  - At run, the first provider that is available answers. When it is unavailable or rate-limited, the next one that meets the policy answers instead (#155).
  - The registry's declarations and the data-policy port need no client and no key. The `serve` role can answer `GET /v1/policy` while only the `work` role holds the keys ([ADR 0014](0014-server-modular-monolith.md)).
- **The `PrestoCVServer` executable reads the configuration and refuses to start,** with an error that names the cause, when a provider does not meet the policy, when a secret cannot be read, or when a model is not allowed (#155). Nothing is skipped silently: a configuration that leaves a provider's declaration incomplete stops the start too.
  - The refusal is a typed error (R7). It carries a code and the names the operator wrote in the configuration, never a key. The executable words it for the operator.
  - Every role checks the policy and the models. Only the role that holds the keys, `work` or both roles in the local profile, reads the secrets.
- **Secrets are read by the executable,** the composition root, and handed to the adapters. An adapter never reads the environment or a secret store itself (R2, R4). The executable also creates each provider's HTTP client (R4).
- **No allow-list changes.** `ServerInference` already imports `ServerApplication`, `Tailoring`, `TailoringModel` and `AsyncHTTPClient`, and the executable imports it. [modules.md](../modules.md) describes what each target now holds.

## Consequences

- **What becomes possible:**
  - a model served on the same machine for development, with no hosted key;
  - switching, reordering or adding providers without an app release, and without code where an endpoint speaks the shared API;
  - a consent text tied to the policy (#190): the server does not start unless every provider meets what the policy says.
- **Costs:**
  - **A provider's policy is declared by the deployment's operator, and the declaration can be wrong.** The server holds the declaration, not the provider's real behaviour. The check is only as true as what the operator wrote.
  - **A fallback can change the price,** and which provider answered. The reply names the provider and the model (#150), and the loop records them for every attempt (#152).
  - **A wrong configuration stops the server** instead of running with a weaker policy. That is deliberate.
  - **Each dialect is code to keep** current with its endpoint.
- **Enforced by:**
  - the compiler, through the target graph: `ServerApplication` imports no adapter, and `ServerHTTP` reaches the policy only through its port;
  - the checker:
    - the allow-lists of [modules.md](../modules.md);
    - R4's detectors on every server target except the executable, so a provider's client is created only in the root;
    - R2's detectors on `ServerApplication`, so the rule reads no ambient state;
    - R7's `swallowedError` on every server target;
  - tests (#154, #155):
    - the "meets" rule, one case for each of its three points;
    - each refusal at start: a provider that does not meet the policy, a secret that cannot be read, a model that is not allowed, an incomplete declaration;
    - fallback within the policy, and never outside it;
    - the adapter against recorded responses for each dialect, with no network in CI;
    - no prompt, answer or key reaches the log;
  - the composition test that [ADR 0014](0014-server-modular-monolith.md) names, which also proves that `serve` reads no secret;
  - the evaluation harness (#156), which runs a prompt or a model change before it ships. It is run by hand, because it calls real providers;
  - review, until the checker learns it: that no provider name or model identifier enters the repository.

## Alternatives considered

- **One hard-wired hosted router.** Rejected by the owner: the router is one provider among others, not the architecture.
- **A native adapter per provider.** Rejected: the shared API covers most providers, so a native adapter is written only for one with no compatible endpoint.
- **Letting the app choose the model.** Rejected: a model change would need an app release, and the app could not keep the deployment's policy.
- **Trusting a provider's own policy without declaring it.** Rejected: the deployment must state what it requires and check each provider against it. The check is the server's, not the provider's.

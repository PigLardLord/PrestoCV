# 0015. Reach models through configured providers, held to the deployment's data policy

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0013](0013-cv-tailoring-context.md), [ADR 0014](0014-server-modular-monolith.md), R2, R3, R4, R7, R8, issues #133, #149, #150, #154, #155, #156, #176, #190

## Context

- A tailoring sends a user's CV to a model. Which model sees it, and what its provider does with it, is a decision of each deployment.
- That decision is written in the deployment's configuration and checked by the server. It is never taken on trust.
- [ADR 0013](0013-cv-tailoring-context.md) puts the outbound inference port in `Tailoring`, which owns the loop. [ADR 0014](0014-server-modular-monolith.md) puts the adapters behind it in `ServerInference`, and lets only the worker hold the providers' keys. Neither says which providers exist, how one is chosen, or what a deployment may demand of them.
- The app's consent text (#190) and `GET /v1/policy` (#175) need a policy that is true of what the server does.
- The owner decided on 2026-10-02 (#149):
  - the provider pattern, the first adapter and its dialects;
  - the registry and what it lists;
  - the enforcement of the deployment's policy;
  - the choice of the model by the server, and what is known before a run;
  - that provider names and model identifiers live in the deployment's configuration.
- On 2026-10-03 the owner restricted that last rule (#149, owner decision of 2026-10-03). The names appear nowhere in the repository except the published privacy policy (#190) and the hosted deployment's runbook (#163). The server may still serve the real names it reads from its configuration, as the consent text needs them.
- This ADR's own architecture:
  - where the data policy's types and its rule live;
  - how `ServerInference` and the executable share the work;
  - which role reads the secrets, and that the executable reads them, not an adapter.
- This ADR also refines the owner's wording:
  - a provider declares the regions it *may* run in, not the one it runs in, because a router chooses among several;
  - structured output is a capability of a model (*whether* it is supported), while the dialect is *how* an endpoint is asked for it;
  - what a provider declares is its *declaration*, and *data policy* is what a deployment requires.

## Decision

- **A provider pattern.** The tailoring loop talks to one port, the inference port of `Tailoring` (#150). Providers are adapters behind it, on the server.
- **The first adapter speaks the chat-completions API that most providers and local model servers share** (#154). That one adapter reaches a hosted router of many providers, a model served on the same machine, and most commercial APIs.
  - An endpoint's quirks are its **dialect**: its routing preferences, for example, or how it is asked for structured output. The configuration sets it.
  - A router's dialect derives its routing preferences from the deployment's policy. A recorded-request test proves that every request carries them (#154).
  - A native adapter is written only for a provider with no compatible endpoint.
  - The hosted router is one provider among others, not the architecture.
- **A registry built from configuration** (#155). It lists the providers in order of preference. For each one it holds:
  - its dialect and its endpoint;
  - the *name* of the secret that holds its key, never the key. A provider that needs no key, such as a model on the same machine, declares so explicitly;
  - the models it may use and, for each model it may use, whether it supports structured output and its context size;
  - **its declaration**: whether it keeps prompts, whether it trains on them, and which regions it may run in. A router's declaration covers the upstreams its routing preferences allow (#154): it keeps prompts, trains on them or runs in a region if it or any of those upstreams does;
  - its name, as the published privacy policy names it (#190);
  - an alias, the only name of a provider or model in a result, a log or a report (#156, #176).
- **The deployment's policy is enforced.** The deployment states what it requires, for example no retention and EU only. The server refuses to start when a configured provider does not meet it. A failing provider falls back to the next one, but only within the policy.
- **The server picks the model,** from the configuration. The app never names one, so a model can change without an app release.
- **Known before a run:** which provider will answer, and what it charges.
  - The worker knows both before it sends the CV: the first available provider in the registry's order, and its price.
  - Where the price comes from, configured per provider and model or stated by the endpoint before the call, is left to #155 and #150.
  - A fallback can change both (see Costs).
  - The app can read the policy and the processors it names, so what it tells the user matches what happens.
- **Names stay out of the repository, with two exceptions.** Provider names and model identifiers appear nowhere in the repository except the published privacy policy (#190) and the hosted deployment's runbook (#163). Tests and configuration examples use invented names. The server may still serve the real names it reads from its configuration, as the consent text needs them (#190).
- **The data policy's types and its rule live in `ServerApplication`.** This is this ADR's own architecture.
  - The types are what a provider declares and what a deployment requires. "Keeps prompts" means that it keeps the request or its answer, for any purpose or any time. The regions are the ones it may run in.
  - `GET /v1/policy` serves the deployment's requirements and its processors, named as the published privacy policy names them (#190). The processors are the providers of the registry.
  - The one rule, "a provider meets a policy", exists once: the provider keeps prompts only where the policy allows it, trains on them only where the policy allows it, and runs only in regions the policy accepts. A provider stricter than the policy meets it. The rule is pure and tested without I/O (R2).
  - They sit beside the data-policy port that `GET /v1/policy` reads (#155, #175), and beside a use case that reads the policy and that the endpoint calls. `ServerHTTP` imports `ServerApplication` and not `ServerInference`, so it reaches the policy through that use case (R3).
- **`ServerInference` holds the registry, the selection and the fallback.** It implements `Tailoring`'s inference port and `ServerApplication`'s data-policy port.
  - Building the registry fails with the refusal below when a provider does not meet the policy, so no running registry holds one and no fallback can reach one.
  - At run, the first provider that is available answers. When it is unavailable or rate-limited, the next one that meets the policy answers instead (#155). No other error triggers a fallback. A refusal for lack of credit (#165) does not.
  - The adapter decodes the endpoint's envelope into the port's reply and errors, with a size cap. The model's text is decoded once, in `Tailoring` (R8).
  - The registry's declarations and the data-policy port need no client and no key. The `serve` role can answer `GET /v1/policy` while only the `work` role holds the keys ([ADR 0014](0014-server-modular-monolith.md)).
- **The `PrestoCVServer` executable reads the configuration and refuses to start,** with an error that names the cause, when a provider does not meet the policy, when a secret cannot be read, or when a model is not allowed (#155). Nothing is skipped silently: a provider whose declaration is incomplete stops the start too.
  - The refusal is a typed error (R7). It carries a code, the aliases and the secret names the operator wrote in the configuration, never a key. The executable words it for the operator.
  - Both roles read one configuration. Every role checks the policy and the models. Only the role that holds the keys, `work` or both roles in the local profile, reads the secrets. This split is this ADR's own architecture.
- **Secrets are read by the executable,** the composition root, and handed to the adapters. An adapter never reads the environment or a secret store itself (R4). In the role that holds the keys, the executable also creates the providers' HTTP client, one per process (R4).
- **The policy has a version.** It is derived from everything that `GET /v1/policy` serves, the requirements and the processors, so both roles derive the same one. A provider swap that still meets the requirements changes it, and the user is asked again.
  - The start request carries the version the app showed the user. Start refuses a different one, and the job records it.
  - The worker refuses to run a job under a version other than the one it recorded, because the user consented to that one.
  - #155, #176 and #190 implement it.
- **Left to #155:** which model a fallback provider uses, whether "allowed" is decided per provider, whether a provider's capabilities choose which provider answers, and (with #157) what a job the worker refuses becomes and whether it counts against the quota (#165).
- **No new edge between targets.** `ServerInference` imports `AsyncHTTPClient` and `ServerApplication`, and the executable imports `ServerInference` and `AsyncHTTPClient`, so it can create that client. [modules.md](../modules.md) describes what each target now holds.
- **It is consistent with [ADR 0014](0014-server-modular-monolith.md):** its invariants hold.

## Consequences

- **What becomes possible:**
  - a model served on the same machine for development, with no hosted key;
  - switching, reordering or adding providers without an app release, and without code where an endpoint speaks the shared API in a dialect already written;
  - a consent text tied to the policy and its version (#190): the server does not start unless every provider meets the requirements, and a change of what the text says asks the user again.
- **Costs:**
  - **A provider's declaration is written by the operator, and it can be wrong.** The server holds the declaration, not the provider's real behaviour. The check is only as true as what the operator wrote. The processors' names are written by the operator too: a deploy check, or the runbook (#163), keeps them in step with the privacy policy.
  - **A fallback can change the provider that answers and its price.** The reply names the provider and the model (#150), and the loop records them for every attempt (#152); the result carries only their aliases (#176).
  - **A wrong configuration stops the server** instead of running with a weaker policy. That is deliberate.
  - **A provider swap asks every user for consent again,** even when it still meets the requirements, because the version covers the processors.
  - **Each dialect is code to keep** current with its endpoint.
  - **A prompt or a model change needs a run of the evaluation harness (#156) before it ships.** It is run by hand, because it calls real providers and costs money.
- **Enforced by:**
  - the compiler, through the target graph: `ServerApplication` imports no adapter, and `ServerHTTP` cannot reach `ServerInference`;
  - the checker:
    - the allow-lists of [modules.md](../modules.md);
    - R4's detectors on every server target except the executable, so a provider's client is created only in the root;
    - R2's detectors on `ServerApplication`, so the rule reads no ambient state;
    - R7's `swallowedError` on every server target;
  - tests (#154, #155):
    - the "meets" rule: each of its three points, passing and failing, including that a provider stricter than the policy meets it;
    - each refusal at start: a provider that does not meet the policy, a secret that cannot be read, a model that is not allowed, an incomplete declaration;
    - fallback within the policy, never outside it, and no fallback on a refusal for lack of credit;
    - the policy's version: derived from everything the endpoint serves, so a provider swap changes it; a start that carries another one is refused; a worker refuses a job recorded under another one;
    - the adapter against recorded responses for each dialect, with no network in CI, and every request to a router carrying the routing preferences of the policy;
    - no prompt, answer or key reaches the log;
  - the composition test that [ADR 0014](0014-server-modular-monolith.md) names, which also proves that `serve` reads no secret;
  - review, until the checker learns it: no server target but the executable reads the environment or a secret store;
  - review: `GET /v1/policy` calls the use case that reads the policy, not the port;
  - review, until the checker learns it: no provider name or model identifier anywhere in the repository except the published privacy policy and the hosted deployment's runbook. A mechanical check can only be an allow-list of invented names or a list of real names held outside the repository.

## Alternatives considered

- **One hard-wired hosted router.** Rejected by the owner: the router is one provider among others, not the architecture.
- **A native adapter per provider.** Rejected by the owner: the shared API covers most providers, so a native adapter is written only for one with no compatible endpoint.
- **Letting the app choose the model.** Rejected by the owner: a model change would need an app release, and the app could not keep the deployment's policy.
- **Trusting a provider's own policy without declaring it.** Rejected by the owner: the deployment must state what it requires and check each provider against it. The check is the server's, not the provider's.

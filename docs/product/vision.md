# Product vision

**PrestoCV writes your CV with you, fast, and never puts anything in it you did not say or confirm.**

This page states what PrestoCV is for, the principles every change follows, how it pays for itself, and the order of the releases. The tickets of epic #190 and the ADRs refer to it. When a decision changes it, the decision updates this page in the same pull request.

## For whom

Most people write their CV on a computer, and they find it slow and boring. PrestoCV is for people who need a good CV today, starting with those the market serves badly:

- **Job seekers in Germany and Italy who work in care, retail, hospitality, the trades, or are looking for a first job.** Their CVs are short, but the expected skills, licences and certificates are specific to each job and each country.
- **New arrivals.** They have to write a CV in a language and to conventions that are not their own (Lebenslauf, Italian CV).
- **Technical profiles who want speed.** They know their stack, and they want the CV written and adapted to each job ad in minutes.

## How it works

1. The person says who they are, for example "iOS developer, 10 years": in a free text, by scanning a document, or by answering the coach's questions, in writing or by voice.
2. PrestoCV proposes what such a person most likely knows and did: skills and technologies, and for each employer the likely responsibilities.
3. The person confirms or rejects each proposal.
4. A finished CV appears.
5. The person adapts it to a job ad.

This is the target. Version 1 offers a blank CV, an example, or, on devices with Apple Intelligence, a draft written from the person's own description. The proposals of steps 2 and 3 arrive with v1.1 (skills) and v1.2 (responsibilities per employer). Adapting the CV to a job ad, step 5, arrives with v1.2. Scanning a document and the written chat with the coach arrive with v1.1, the coach's own voice with v1.2. See [Releases](#releases).

## Principles

1. **Propose, never invent.** AI and data may suggest; only what the person wrote or confirmed enters the CV. Every fact keeps its origin. [ADR 0023](../architecture/adr/0023-ground-the-ai-draft-in-the-description.md) enforces this for the v1 AI draft.
2. **Free for everyone, forever.** Writing, saving, examples, suggestions and the PDF are free. There is no account, no paywall and no ads.
3. **Private by default.** Everything works on the device. Nothing leaves it without the person's explicit consent.
4. **Open source.** The code is under Apache-2.0. The name and the icon are protected as trademarks.
5. **European.** Six languages, the ESCO classification, and local conventions such as the German Lebenslauf and the Italian CV.
6. **Honest store listing.** AI is described as what it is and where it runs.
7. **Scale with use, pay with revenue.** PrestoCV must keep working, and keep its costs covered, if many people start using it at once.
   - **No fixed costs before revenue.** Until the app earns money, it runs on free tiers: the device, static hosting, and the free build minutes of the Apple Developer Program.
   - **Every cost grows only with use that pays for it.** A model call in the cloud happens only for a person who bought credits, or who uses their own key.
   - **Content that is the same for everyone is static,** served from a static host or a CDN, so a thousand times more people cost almost nothing more. This covers the skill packs, the support and privacy pages, and the examples.
   - **A server, when one is needed, is stateless and scales automatically, down to zero.** It protects itself with device attestation, per-device quotas and rate limits. Nothing in it needs a person to scale it by hand.
   - **Every backend decision states its scaling and cost.** An ADR for a backend component says how it scales, what it costs with no users, 1,000 users and 100,000 users, and what limits it when the money runs out.

## Business

- **The core is free.**
- **Optional in-app purchases** buy stronger cloud models, as credit packs or a non-renewing pass. Their price covers the model and server costs they cause.
- **Bring your own key.** Technical users can use their own key for free. It unlocks nothing that is sold.
- **A tip jar.**
- **Success is measured in adoption, not revenue.** Revenue has to cover the costs of running, maintaining and developing PrestoCV; anything beyond that is a bonus.

## Releases

| Release | What it brings | Server | Running cost |
|---|---|---|---|
| **v1** | Today's app, made right. | None | None |
| **v1.1** | A guided start with ESCO skill suggestions that the person confirms, offline on every device, from a free text, a scanned document or a written chat with the coach. | None: the skill packs are static files, regenerated in batches and synced in the background. | Hosting is free. Generating the packs is a one-off batch, repeated only for packs whose inputs changed. |
| **v1.1.x** | Whole CVs of each trade (the summary, the lines of each job and the skills), written in advance and filled with the facts of the person's text that code checks and the person confirms, offline on every device. | None: the CVs ship inside the app. | One run of the pipeline writes them. |
| **v1.2** | Experience suggestions and tailoring to a job ad, on Apple's models (on the device and Private Cloud Compute), and the coach's voice, on the device. | None | None |
| **v2** | The cloud tier: employer lookup, job-market demand, stronger models. | A stateless, autoscaling backend with device attestation and quotas. | It grows with paid use only. |

## Sources

- The maintainer's decisions of 2026-10-16, 2026-10-17 and 2026-10-18, of 2026-11-06 on the ways in, and of 2026-11-18 and 2026-11-19 on the whole CVs of each trade ([ADR 0036](../architecture/adr/0036-build-the-draft-from-prepared-lines-of-each-trade.md)).
- The product review of 2026-10-16.
- The market analysis of 2026-10-17.
- The ESCO spike (#229).

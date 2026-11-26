# 0040. Sell tips through the App Store only

- **Status:** Accepted
- **Date:** 2026-11-26
- **Related:** issues #197 (business model), #213 (tip jar), #505 (Settings row), #569 (a link on the US storefront), #269 (EU trader status); [ADR 0008](0008-single-composition-root.md), [ADR 0030](0030-log-through-one-interface-that-carries-no-cv-content.md)

## Context

- **PrestoCV is free, and every feature works without paying** (#197). Some people want to say thank you to the developer, and #213 asks for a way to do it: three tips of €1.99, €4.99 and €9.99, with a thank-you. #505 places it in Settings, as the row "Support PrestoCV".
- **Apple's rules for a payment made inside the app.** The App Review Guidelines ask that a payment made inside an app go through In-App Purchase (3.1.1), and they keep collecting donations for approved nonprofits (3.2.2). PrestoCV's developer is a person, not a nonprofit, so what the app sells is a tip, not a donation. On the US storefront only, the guidelines also allow a link to another way of paying.
- **Selling makes the developer a trader** under the EU Digital Services Act (#269). The App Store then shows the developer's trader details on the product page in the EU. The status is switched in App Store Connect when the tips ship.
- **Selling needs the Paid Applications Agreement** and the developer's bank and tax details in App Store Connect. They block the sale, not the code.
- **The maintainer decided on 2026-11-26:** the tips ship inside version 1.1; they are named "Small tip", "Medium tip" and "Large tip"; a tip gives no mark or badge; the screen's introduction is neutral; the link to another way of paying on the US storefront is not in 1.1 and is listed for 1.2 (#569).

## Decision

- **Tips are three consumable In-App Purchases,** at the price points of €1.99, €4.99 and €9.99, bought with StoreKit 2 from one screen, reached from the "Support PrestoCV" row of Settings. The App Store shows each person the price of their own storefront.
- **A tip unlocks nothing.** No feature, design, badge, mark or text changes after a tip, and no code asks whether a person has tipped. So nothing is stored about a tip, and there is nothing to restore.
- **The word is "tip" in every language** (de Trinkgeld, es propina, fr pourboire, it mancia, pt gorjeta), never "donation". The screen says that a tip unlocks nothing and that it is a payment to the developer, not a donation.
- **No link, button or text in the app leads to another way of paying,** on any storefront, in version 1.1. The US storefront link of #569 amends this decision first, in its own ADR or an amendment of this one.
- **The tips are offered only on their own screen.** No prompt, banner, reminder or badge elsewhere asks for one.
- **Every purchase is finished with the store** by the adapter: the ones left unfinished at launch, the ones that arrive while the app runs, and the one just bought. An unverified purchase is finished too and grants nothing. The app's log holds counts and outcome codes only, never a price, a product name or an account detail ([ADR 0030](0030-log-through-one-interface-that-carries-no-cv-content.md)).
- **Where the code goes:** the port `TipSelling` and its values in `PrestoCVWorkflowPorts`; the StoreKit adapter in its own target, `PrestoCVTipsStoreKit`, built for Apple platforms only and made by the composition root ([ADR 0008](0008-single-composition-root.md)); the screen's state in a view model of `PrestoCVPresentation`. `modules.md` records the target and its imports in the pull request that adds it.

## Consequences

- **Nothing in the app depends on a tip,** so there is no paywall to review, no receipt to check and no server to run.
- **The view model's tests pin the outcome of each purchase** (thanked, cancelled, waiting for approval, failed, purchases turned off, no store), with a fake port; the adapter's tests count the finished purchases; the UI tests drive the screen through a Debug fixture, because a UI test cannot drive Apple's purchase sheet.
- **The architecture checker keeps StoreKit out of the ports and the view model:** their allowed imports do not list it, and only the composition root may make the adapter.
- **The wording is checked by review,** in the six languages, on each pull request that adds a tip string; the string checks run as for every new text.
- **The developer's work in App Store Connect comes first:** the agreement, the bank and tax details, the three products with their store texts and a review screenshot, and the trader status when version 1.1 ships. If the agreement or the bank are not ready, version 1.1 waits.
- **Apple keeps its commission** on every tip.

## Alternatives considered

- **A link to a sponsorship page for everyone.** Outside the US storefront, the guidelines do not allow it in the app, and the review would refuse the version. On the US storefront it is allowed, and it is #569, for 1.2.
- **A supporter mark or an extra unlocked by a tip.** The maintainer chose no mark, and #197 keeps every feature free. Anything unlocked would also need storage and a restore.
- **A subscription or a one-time "supporter" purchase.** A renewal or a restore that unlocks nothing confuses people and adds work.
- **The word "donation".** It suggests a nonprofit, which the guidelines reserve for approved organisations.
- **No tips in version 1.1.** The maintainer wants them in 1.1, with about two or three more days of work before the submission.

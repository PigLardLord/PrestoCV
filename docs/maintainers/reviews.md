# How pull requests are reviewed

Every pull request is reviewed by reviewer agents, language models that read the change and report findings, in rounds, until nothing blocking is left. This document says how those rounds run, so that anyone can see how a change was checked before it merged. The maintainer decides every merge.

## Rounds

- **Commit first.** A review reads commits, not the working tree.
- **The whole change is read twice at most:** by the first reviews and by the final gate. In between, each round reads only what changed since the last reviewed commit, recorded as `refs/reviewed/<branch>` in the local clone; the pull request lists the reviewed commits, so that the review can go on from another clone.
- **Dimension reviews come first:** security, concurrency, accessibility and code quality, only for the dimensions the change touches. An adversarial round, which challenges the approach and its assumptions, comes after them.
- **Rounds are batched.** Every finding of a round is dealt with before the next round starts.
- **A round that finds nothing blocking leads to the final gate,** a review of the whole change.
- **Three rounds without convergence stop the loop.** The open findings go to the maintainer, who decides what happens to them.

## Reviewers

- **Dimension reviews and checks of fixes** use a mid-tier model.
- **The final gate** uses the strongest model available.
- **No priority tier:** reviews never run on a faster, costlier tier.

## Findings

- **Each finding is checked against the code before it is fixed.** A finding that does not apply is answered with the reason.
- **A defect is fixed with a test that fails without the fix** (R10), in a new commit; reviewed commits are never amended.
- **A finding left for later** becomes an issue, and the pull request links it.
- **Only open questions reach the maintainer:** a doubt the reviewers cannot settle from the code and the documents, such as a product choice.

## Code ported from the prototype

Code ported from the validation prototype (`Prototypes/ADRValidation/`) is new code. It gets the full review, the final gate included, in the pull request that ports it (see the migration strategy in [docs/architecture/README.md](../architecture/README.md)).

## What the pull request records

The rounds that ran, their verdicts and the findings deferred to issues. It names no coding assistant and no model, as for every file, commit and issue ([CONTRIBUTING.md](../../CONTRIBUTING.md#commits)): a round is "review round 3", the gate is "the final gate".

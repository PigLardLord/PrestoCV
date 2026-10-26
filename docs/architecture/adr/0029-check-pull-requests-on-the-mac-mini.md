# 0029. Check pull requests on the Mac mini

- **Status:** Accepted
- **Date:** 2026-10-25
- **Related:** [ADR 0024](0024-run-apple-ci-and-releases-on-xcode-cloud.md) (amended), [ADR 0022](0022-ship-legacy-app-as-v1.md), issue #337

## Context

- **What ADR 0024 decided.** Three Xcode Cloud workflows. The Pull Request workflow ran the `CI` test plan on an iPhone and an iPad simulator, and `ci_scripts/ci_post_xcodebuild.sh`, on every pull request and on every push to one.
- **What it cost.** The plan has 25 compute hours a month for the whole team. From 13 October to 25 October, 75 pull request runs took 17.25 hours (about 14 minutes each), 80% of the hours spent; the 24 runs of the Main workflow took 3.82 hours. Apple bills about 1.09 times the sum of the actions' durations.
- **What happened.** On 25 October, from 14:55 UTC, runs of the Pull Request and the Main workflows were cancelled within seconds, with no action started, while the estimate of the hours spent stood at 86%. Apple's API shows neither the usage nor the cause. A merge needs its check to run, so a budget that runs out stops the merges, and it stops the release builds as well.
- **What the owner has.** A Mac mini and a MacBook Pro with Xcode 27 and the simulators, already used for every test run before a push (`mac-test.sh`), whose hours are free.

## Decision

**The owner decided on 2026-10-25** that the pull request check runs on the Mac mini, and that the Xcode Cloud Pull Request workflow is disabled. This amends the Pull Request workflow in ADR 0024, whose text stays as it was decided. The Main and Release workflows are unchanged.

**The flow.** A script run on the Mac mini for a pull request:
1. refuses, and writes no status, when the pull request is not open, is not to `main`, or its head commit does not contain the latest `origin/main`;
2. writes the GitHub commit status `Mac mini · CI` as `pending` on the head commit;
3. runs the `CI` test plan on the iPhone and iPad simulators, and `ci_scripts/ci_post_xcodebuild.sh` of the head commit with `CI_XCODEBUILD_ACTION=build-for-testing`, so that the package tests, the source checks, the architecture check and the other steps of the post script run from the repository's own script;
4. writes `success` when both device runs counted tests and the post script ran its steps with none failing, `failure` when a part failed, and `error` when the run broke or was stopped.

**The merge rule.** A pull request merges when its branch contains the latest `main`, every check of the `CI` GitHub workflow is green, and `Mac mini · CI` is `success` on the exact head commit. A pull request whose changed files are all in `docs/` or match `*.md` does not need the Mac status. The retired Xcode Cloud status `PrestoCV | Pull Request` is ignored by name. The merge step enforces the rule, because the repository's plan has no rulesets and no branch protection.

**Xcode Cloud** keeps the Main workflow (archive and TestFlight after a merge) and the Release workflow (tests, archive and TestFlight for a tag). Its hours go only to those.

## Consequences

- **The hours are spent on merges and releases only.** About 10 minutes per merge to `main` and a Test action plus an archive per release, instead of 14 minutes per push to a pull request.
- **The status comes from a person's machine.** The check works only when the Mac mini is on, and nothing but the script writes the status. A branch that no one ran the script for has no `Mac mini · CI`, so it cannot merge (code changes). The merge step is the only enforcement: it refuses a pull request without the green status on its head.
- **The check trusts the code it checks.** The post script and the checks it runs come from the head commit, as they did on Xcode Cloud, so a pull request that changes them changes what its own `success` proves. The review of such a change is what covers it; the status does not.
- **R16 is no longer exercised by the pull request check.** The tests that run without the repository (the Release workflow's Test action, `docs/release/xcode-cloud.md`) exist to find a test that reads a file of the repository. Those tests now run when a release is tagged, not on each pull request, and the checker's own R16 rule stays. A failure found at release time points to the commits since the last release.
- **The check does not run on the iOS 26.5 simulators.** It runs on the newest runtime. The oldest supported release runs separately, once per pull request.
- **Nothing is signed or uploaded from the Mac mini.** Signing and TestFlight stay on Xcode Cloud, so no key or certificate goes to GitHub or to the Mac, as in ADR 0024.
- **The Linux checks do not change.** They stay GitHub Actions, and their result still counts in the merge rule.

## Alternatives considered

- **Keep the Xcode Cloud Pull Request workflow and buy more hours.** Rejected by the owner: the check would use 80% of the hours again, with every push, and the release builds would depend on what is left.
- **Run the pull request check on the Xcode Cloud workflow only for code changes.** Rejected: a workflow start condition on file paths still starts a run per push, and the code pushes are the 75 runs.
- **A self-hosted GitHub Actions runner on the Mac mini.** Rejected: it brings back the runner that ADR 0024 retired, with a token on the Mac and a runner process that must stay registered, to do what one script does.
- **GitHub's hosted macOS runners.** Rejected as in ADR 0024: they offer Xcode 27 only as a preview.

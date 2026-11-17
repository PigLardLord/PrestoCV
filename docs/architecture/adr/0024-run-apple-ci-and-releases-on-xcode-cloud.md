# 0024. Run the Apple CI and the releases on Xcode Cloud

- **Status:** Accepted
- **Date:** 2026-10-14
- **Related:** [ADR 0006](0006-enforce-architecture-mechanically.md), [ADR 0022](0022-ship-legacy-app-as-v1.md), issue #240

## Context

- **What ADR 0006 asks.** Its item 4 has a macOS job next to the Linux job. That job runs the checker with the module and package checks, which see the Apple-only branches of the package manifests, the checker's self-test, the package tests, and the tests of the app and of the exporter's native renderer contract on the iOS simulator.
- **How it ran.** On a self-hosted runner on the owner's Mac (issue #28), which had to be online for every pull request. The release to TestFlight ran on a second self-hosted runner, and its signing needed an App Store Connect API key stored as a secret on GitHub.
- **Why not GitHub's macOS runners.** Their images offer Xcode 27, which the project needs, only as a preview.
- **What Apple offers.** Xcode Cloud has Xcode 27, signs with its own cloud-managed signing, uploads to TestFlight, and includes 25 compute hours a month with the Apple Developer Program.

## Decision

**The owner decided on 2026-10-14** to build, test and release the Apple targets on Xcode Cloud, and to stop using a self-hosted runner. This amends item 4 of ADR 0006, whose text stays as it was decided. The Linux job is unchanged.

**The flow.** Three Xcode Cloud workflows, whose exact settings are in `docs/release/xcode-cloud.md`:
- **Pull Request:** a pull request to `main` runs the tests on an iPhone and an iPad simulator, and the Apple checks below. GitHub shows the result in the pull request.
- **Main:** a merge to `main` runs the same, then archives and uploads a build to TestFlight for the internal testers.
- **Release:** a GitHub Release with a tag `v<version>`, or a push to a branch `release/<version>`, tests that commit, archives that version and uploads it to TestFlight. The owner then submits the build for App Review by hand. Nothing submits it automatically.

**Where each check of ADR 0006's macOS job runs now:**

| Check | Runs in |
|---|---|
| The architecture check, with the module and package checks, and the baseline compared with the target branch's | `ci_scripts/ci_post_xcodebuild.sh`, after `build-for-testing` |
| The checker's self-test, with the case that must fail on macOS | the same script and step |
| The package tests of `PrestoCVCore`, `CVPDFExporter` and `CVGeneratorAI` | the same script and step |
| The builds of `PrestoCVApp` and `CVPDFExporterExamples` | the same script and step |
| The app tests on the iOS simulator | the Test action, `CI` test plan, on an iPhone and now also an iPad |
| The exporter's native renderer contract on the iOS simulator | the same action and plan, which holds the exporter's simulator test targets |
| The archive checks of `Tools/Release/check-archive.sh` | `ci_scripts/ci_post_xcodebuild.sh`, after an archive; a failure stops the build before TestFlight |
| The self-test of the archive checks, on fake archives | `ci_scripts/ci_post_xcodebuild.sh`, after `build-for-testing`, so a pull request finds a wrong rule before main's archive does |
| The Linux checks | GitHub Actions, unchanged (amended 2026-11-17 by [ADR 0029](0029-check-pull-requests-on-the-mac-mini.md): their steps run on a Linux computer, and the workflow only by hand) |

The post script runs every step and fails at the end. The app is iOS only in version 1 (ADR 0022), so no job builds it for macOS, as the self-hosted job did not either.

## Consequences

- **The configuration is outside the repository.** The workflows live in App Store Connect, set up by the owner with an Apple ID. `docs/release/xcode-cloud.md` is their only description, and nothing tests that the two agree. The scripts and the test plans are in the repository, so a change to them is reviewed in a pull request.
- **The compute budget is 25 hours a month.** Every pull request and every merge to `main` spends some of it. `PrestoCVUITests`, the app's UI tests, which take most of an hour, are left out of the `CI` plan for that reason. The checker is built from source on every build, because Xcode Cloud keeps no build cache between builds.
- **No signing secrets on GitHub.** Xcode Cloud signs the build itself, so no key and no certificate is in the repository or in GitHub's settings.
- **Required checks.** A pull request can merge without the Apple checks unless the owner makes the Xcode Cloud checks required in a GitHub ruleset. `docs/release/xcode-cloud.md` says how.
- **A new simulator test target** of `CVPDFExporter` goes into both test plans, as well as into the `ExporterTests` scheme, or it does not run in CI.
- **Every distributed build is tested.** The Main and Release workflows run the `CI` test plan, with its package tests and architecture check, as a Test action that is required to pass, before the archive is distributed. A tag on a commit that never went through a pull request is tested too. The cost is one Test action per release.

## Alternatives considered

- **Keep the self-hosted runners.** Rejected by the owner: they need the owner's Mac online, and the release needs an API key stored on GitHub.
- **GitHub's hosted macOS runners.** Rejected: they offer Xcode 27 only as a preview, and releasing from them needs the same signing secrets.

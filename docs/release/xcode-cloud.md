# Releasing with Xcode Cloud

Xcode Cloud tests version 1, archives it, signs it and uploads it to TestFlight (ADR 0022, ADR 0024). The workflows are set up in Xcode and App Store Connect with the owner's Apple ID, so they are not in the repository. This page holds the settings to enter, the one-time setup, and the steps of a release. The repository holds the rest:

| Path | What it does |
|---|---|
| `ci_scripts/ci_pre_xcodebuild.sh` | Before an archive: sets `MARKETING_VERSION` from the tag `v<version>` or the branch `release/<version>`. Any other ref keeps the project's version. A tag `v…` or branch `release/…` that does not name a version such as `1.2` or `1.2.3` fails the build. It edits only the CI checkout. The build number is Xcode Cloud's. |
| `ci_scripts/ci_post_xcodebuild.sh` | After an archive: runs `Tools/Release/check-archive.sh`, and a failure stops the build before TestFlight. After `build-for-testing`: runs the package tests of `PrestoCVCore`, `CVPDFExporter` and `CVGeneratorAI`, the architecture check and its self-test (which see the Apple-only branches of the package manifests), and `swift build` of `PrestoCVApp` and `CVPDFExporterExamples`. Every step runs and the script fails at the end. On a pull request the checker compares the baseline with `origin/<target branch>`; a checkout without that branch is compared with an empty baseline. |
| `TestPlans/PrestoCV.xctestplan` | The scheme's default plan: `PrestoCVTests`, the exporter's simulator test targets, and `PrestoCVUITests`. |
| `TestPlans/CI.xctestplan` | The same without `PrestoCVUITests`, which are Xcode's template launch tests: they take most of an hour and check nothing, so they would spend the free compute hours. |
| `PrestoCV.xcodeproj/project.xcproj` | `DEVELOPMENT_TEAM`, in the project's build settings: the one place that holds the Team ID. |

Xcode Cloud finds the scripts because `ci_scripts/` is next to `PrestoCV.xcodeproj`. They need no setting in a workflow.

Both plans hold the four simulator test targets of the `CVPDFExporter` package, `CVDesignCatalogTests`, `CVDesignCatalogFileStoreTests`, `CVRenderingTests` and `CVRenderingWebKitSupportTests`: the native renderer contract on the simulator, so it runs in the same Test action on the iPhone and the iPad. They are the targets of the package's `ExporterTests` scheme, which stays for running them from the package. A new simulator test target of that package goes into the scheme and into both plans.

## Workflows

Create the three workflows with these settings. Anything not listed keeps its default.

### Pull Request

| Section | Setting |
|---|---|
| General | Name: `Pull Request` |
| Environment | Xcode: Latest Release (Xcode 27). macOS: Latest Release. |
| Start condition | Pull Request Changes. Source branch: All Branches. Destination branch: `main`. Auto-cancel builds: on. |
| Action 1 | Test. Scheme `PrestoCV`, test plan `CI`, platform iOS. Destinations: iPhone 17 Pro and iPad Pro 13-inch, both on the latest iOS release. Requirement: Required to pass. |
| Post-actions | None. |

GitHub shows the result in the pull request.

Keep the destinations on the latest iOS. The exporter's WebKit tests are recorded on iOS 26.5, and on the iOS 26.2 simulator runtime two of their cases fail: the `object` and `embed` loads of a page escape the web view's content rules.

### Main

| Section | Setting |
|---|---|
| General | Name: `Main` |
| Environment | Xcode: Latest Release (Xcode 27). macOS: Latest Release. |
| Start condition | Branch Changes. Branch: `main` only. |
| Action 1 | Test. Same as the Pull Request workflow: scheme `PrestoCV`, test plan `CI`, iPhone 17 Pro and iPad Pro 13-inch on the latest iOS. Requirement: Required to pass. |
| Action 2 | Archive. Scheme `PrestoCV`, platform iOS. The scheme archives with the Release configuration. Deployment preparation: TestFlight (Internal Testing Only). |
| Post-actions | TestFlight Internal Testing, with the group of internal testers. |

A build from `main` is for the internal testers only. It cannot be submitted to App Review.

### Release

| Section | Setting |
|---|---|
| General | Name: `Release` |
| Environment | Xcode: Latest Release (Xcode 27). macOS: Latest Release. |
| Start conditions | Two, and either one starts the workflow. Tag Changes: custom, the tag name begins with `v`. Branch Changes: custom, the branch name begins with `release/`. |
| Action 1 | Test. Same as the Pull Request workflow: scheme `PrestoCV`, test plan `CI`, iPhone 17 Pro and iPad Pro 13-inch on the latest iOS. Requirement: Required to pass. |
| Action 2 | Archive. Scheme `PrestoCV`, platform iOS. The scheme archives with the Release configuration. Deployment preparation: TestFlight and App Store. |
| Post-actions | TestFlight Internal Testing, with the group of internal testers. |

The Release workflow tests the exact commit it archives. Its Test action is required to pass, so a failing test, package test or architecture check fails the build, and nothing reaches TestFlight, even for a tag on a commit that never went through a pull request. It archives the version the tag or branch names, so a tag `v1.2.3` or a branch `release/1.2.3` gives version 1.2.3. Nothing submits a build for App Review: the owner does it by hand.

## Require the checks on GitHub

1. Open a pull request to `main` once, so that Xcode Cloud reports its checks. GitHub offers a check in the ruleset only after it has run once.
2. In the repository: Settings → Rules → Rulesets → New ruleset → New branch ruleset. Target the branch `main`.
3. Turn on Require status checks to pass, and add:
   - the Xcode Cloud checks of the `Pull Request` workflow;
   - the check of the Linux job of the `CI` workflow, `Linux · architecture check`.
4. Save the ruleset.

A pull request then cannot merge until the tests pass on the iPhone and the iPad and the architecture check passes.

Check once that a failing test stops a build: open a pull request that breaks one test, and confirm that the Pull Request workflow fails. In the Main and Release workflows, the Test action must show Required to pass in the workflow editor; then the archive is never distributed after a failed test.

## One-time setup

1. In Xcode 27, open Settings → Accounts and add your Apple ID (the account of the Apple Developer Program) and your GitHub account.
2. Clone `PigLardLord/PrestoCV` and open `PrestoCV.xcodeproj`.
3. Check that `DEVELOPMENT_TEAM` in `PrestoCV.xcodeproj/project.xcproj` is your Team ID, and that the app record "PrestoCV: CV & Resume Maker" for `com.PigLardLord.prestocv` exists in App Store Connect (My Apps → +).
4. Choose Product → Xcode Cloud → Create Workflow, and choose the `PrestoCV` product.
5. When Xcode asks for access to the source code, grant it: it opens GitHub, where you install the Xcode Cloud app for `PigLardLord/PrestoCV` only.
6. Set the first workflow to the settings above, then add the other two (the workflow list is in the Report navigator, Cloud tab, and in App Store Connect under Xcode Cloud).
7. Create the group of internal testers in App Store Connect (TestFlight → Internal Testing) before the first Main or Release build, so that the post-action has a group to choose.

## Cutting a release

1. On GitHub, open Releases → Draft a new release. Type the tag `v1.2.3`, choose Create new tag on publish, and target `main`. Title it `v1.2.3`, then publish.
   - Or push a branch: `git switch -c release/1.2.3 && git push origin release/1.2.3`. Each push to that branch builds the same version again.
2. Xcode Cloud starts the `Release` workflow. Follow it in Xcode (Report navigator, Cloud tab) or in App Store Connect under Xcode Cloud. If the build fails with a message from `ci_pre_xcodebuild`, the tag or branch does not name a version: fix the name and start again.
3. Wait for the build in TestFlight. App Store Connect has to process it first, which takes a few minutes. Install it on a device and test it.
4. In App Store Connect, open the app's version 1.2.3 (create it with + if it does not exist), choose the build, and click Add for Review, then submit it to App Review.

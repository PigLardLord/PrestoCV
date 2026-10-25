# Releasing with Xcode Cloud

Xcode Cloud tests version 1 before a store build, archives it, signs it and uploads it to TestFlight (ADR 0022, ADR 0024). It does not check pull requests: the Mac mini does, with the check described below (ADR 0029). The workflows are set up in Xcode and App Store Connect with the owner's Apple ID, so they are not in the repository. This page holds the settings to enter, the pull request check, the one-time setup, and the steps of a release. The repository holds the rest:

| Path | What it does |
|---|---|
| `ci_scripts/ci_pre_xcodebuild.sh` | Before an archive: sets `MARKETING_VERSION` from the tag `v<version>` or the branch `release/<version>`. Any other ref keeps the project's version. A tag `v…` or branch `release/…` that does not name a version such as `1.2` or `1.2.3` fails the build. It edits only the CI checkout. The build number is Xcode Cloud's. |
| `ci_scripts/ci_post_xcodebuild.sh` | After an archive: runs `Tools/Release/check-archive.sh`, and a failure stops the build before TestFlight. After `build-for-testing`: runs the package tests of `PrestoCVCore`, `CVPDFExporter` and `CVGeneratorAI`, the source checks of `Tools/SourceChecks`, the architecture check and its self-test (which see the Apple-only branches of the package manifests), the self-test of `Tools/Release/check-archive.sh` (`Tools/Release/check-archive-selftest.sh`), and `swift build` of `PrestoCVApp` and `CVPDFExporterExamples`. Every step runs and the script fails at the end: it names each failed step in a line `ci_post_xcodebuild: FAILED: <step>`, and ends with `ci_post_xcodebuild: <action> ran N steps, F failed`. The Test action of the Release workflow runs it, and so does the pull request check. Given `CI_PULL_REQUEST_TARGET_BRANCH`, the checker compares the baseline with `origin/<target branch>`; a checkout without that branch is compared with an empty baseline. |
| `TestPlans/PrestoCV.xctestplan` | The scheme's default plan: `PrestoCVTests`, the exporter's simulator test targets, and `PrestoCVUITests`. |
| `TestPlans/CI.xctestplan` | The same without `PrestoCVUITests`, which are Xcode's template launch tests: they take most of an hour and check nothing, so no check runs them. |
| `PrestoCV.xcodeproj/project.xcproj` | `DEVELOPMENT_TEAM`, in the project's build settings: the one place that holds the Team ID. |

Xcode Cloud finds the scripts because `ci_scripts/` is next to `PrestoCV.xcodeproj`. They need no setting in a workflow.

Both plans hold the four simulator test targets of the `CVPDFExporter` package, `CVDesignCatalogTests`, `CVDesignCatalogFileStoreTests`, `CVRenderingTests` and `CVRenderingWebKitSupportTests`: the native renderer contract on the simulator, so it runs in the same Test action on the iPhone and the iPad. They are the targets of the package's `ExporterTests` scheme, which stays for running them from the package. A new simulator test target of that package goes into the scheme and into both plans, and gets R16 in `Tools/ArchitectureCheck/rules.json`.

## Tests run without the repository

The Test action of the Release workflow runs in two steps, on different machines:

1. **The build host** has the repository. It runs `xcodebuild build-for-testing` with the plan, then `ci_scripts/ci_post_xcodebuild.sh`, so the package tests, the source checks and the architecture check run there.
2. **The test machines** have only what the build made: the `.xctestrun` file and the products. They run `xcodebuild test-without-building` on the iPhone and the iPad. The repository is not there, and neither is the build host's build folder.

So a test in a plan finds its files in a bundle, never through `#filePath` ([R16](../architecture/rules.md#r16-tests-that-a-test-plan-runs-read-only-bundles)):

| What a test reads | Where it reads it |
|---|---|
| The example CVs and the other resources the app ships | The app bundle, through `Bundle(for:)` with a class of the app |
| A package's test resources, such as the markup contract page of `CVDesignCatalogTests` and the golden files of `CVRenderingTests` | `Bundle.module`, declared in the package's manifest |
| A document an app test compares with the app: `docs/design/app-icon.md` | The test bundle; the project copies it into `PrestoCVTests` |
| The string catalog's source, the Swift sources, the project file and the privacy manifest | Nowhere in a plan. `Tools/SourceChecks` checks them, on the build host and on the Linux job |

A test that read the source tree passed on a Mac, next to the sources, and failed on Xcode Cloud: that was #246. The architecture checker refuses `#filePath` and `#file` in every target that a plan runs, and a plan target without R16. The pull request check runs the tests next to the sources, so it cannot show this failure: the checker, which that check runs, and the Release workflow's Test action are what guard it.

## The pull request check

A pull request to `main` is checked on the Mac mini ([ADR 0029](../architecture/adr/0029-check-pull-requests-on-the-mac-mini.md)). The result is a GitHub commit status on the pull request's head commit, with the context `Mac mini · CI` (the separator is U+00B7, a middle dot). A script writes it; it lives with the owner's other tooling for the Mac mini, outside the repository, and does this:

1. It refuses, and writes no status, when the head commit does not contain the latest `origin/main`: bring `main` onto the branch locally first.
2. It writes `pending` on the head commit, then runs on the Mac mini:
   - the `CI` test plan on the iPhone 17 Pro and the iPad Pro 13-inch simulators of the newest iOS runtime, the two destinations the Test action had;
   - `ci_scripts/ci_post_xcodebuild.sh` of the head commit, with `CI_XCODEBUILD_ACTION=build-for-testing` and `CI_PULL_REQUEST_TARGET_BRANCH=main`: the package tests, the source checks, the architecture check against the baseline of the latest `origin/main`, its self-test, the self-test of the archive check, and the builds of `PrestoCVApp` and `CVPDFExporterExamples`. It is the repository's own script, so the steps cannot drift from it.
3. It writes `success` only when both device runs counted tests and the script ran its steps with none failing. A failing part gives `failure`, and its description names the part. A run that broke or was stopped gives `error`. A part that did not run never gives `success`.

The check does not run the tests without the repository (see above), nor the iOS 26.5 simulators. The tests do not depend on the iOS release, so it runs on the newest one. When a new release fails it, the platform changed under the app, and the fix goes in a pull request of its own; the failure is not noise to retry. The oldest release the app supports, iOS 26.5, runs on a Mac once per pull request, apart from the check.

A pull request merges when:
- its branch contains the latest `main`;
- every check of the `CI` GitHub workflow is green (`Linux · architecture check`, `Android · build of the portable targets`);
- `Mac mini · CI` is green on that exact head commit. A push moves the head, so the status of an earlier commit counts for nothing.

A pull request whose changed files are all in `docs/` or match `*.md` needs only the `CI` workflow's checks. The old status `PrestoCV | Pull Request` of the disabled Xcode Cloud workflow is ignored, red or green. The merge step reads the statuses of the head commit and refuses to merge when one is not green: the repository's plan has no rulesets and no branch protection, so GitHub enforces nothing here (see "Enforce the checks" below).

## Workflows

Create the Main and Release workflows with these settings. Anything not listed keeps its default.

### Pull Request (disabled)

The Pull Request workflow exists in App Store Connect and is disabled. Keep it disabled: the Mac mini checks pull requests. A run took about 14 minutes, 75 runs used 80% of a month's 25 compute hours, and each one repeated what the Mac mini runs before every push. Main and Release are what the hours are for. Turning the workflow on again, with the settings below, spends them on pull requests again, which changes ADR 0029.

| Section | Setting |
|---|---|
| General | Name: `Pull Request` |
| Environment | Xcode: Latest Release (Xcode 27). macOS: Latest Release. |
| Start condition | Pull Request Changes. Source branch: All Branches. Destination branch: `main`. Auto-cancel builds: on. Files and Folders: don't start a build if all changed files match `docs/` or `*.md`. |
| Action 1 | Test. Scheme `PrestoCV`, test plan `CI`, platform iOS. Destinations: iPhone 17 Pro and iPad Pro 13-inch (M5), both on the latest iOS release of the selected Xcode. Requirement: Required to pass. |
| Post-actions | None. |

### Main

| Section | Setting |
|---|---|
| General | Name: `Main` |
| Environment | Xcode: Latest Release (Xcode 27). macOS: Latest Release. |
| Start condition | Branch Changes. Branch: `main` only. |
| Action 1 | Archive. Scheme `PrestoCV`, platform iOS. The scheme archives with the Release configuration. Deployment preparation: TestFlight (Internal Testing Only). |
| Post-actions | TestFlight Internal Testing, with the group of internal testers. |

A build from `main` is for the internal testers only. It cannot be submitted to App Review. Main has no Test action: a pull request merges only when its branch contains the latest `main` and `Mac mini · CI` is green on that exact head (a pull request that changes only `docs/` or `*.md` files needs only the `CI` workflow's checks), so the tree that reaches `main` has already been tested. Each merge to `main` starts a Main run of about 10 minutes of the 25 compute hours a month.

### Release

| Section | Setting |
|---|---|
| General | Name: `Release` |
| Environment | Xcode: Latest Release (Xcode 27). macOS: Latest Release. |
| Start conditions | Two, and either one starts the workflow. Tag Changes: custom, the tag name begins with `v`. Branch Changes: custom, the branch name begins with `release/`. |
| Action 1 | Test. Scheme `PrestoCV`, test plan `CI`, platform iOS. Destinations: iPhone 17 Pro and iPad Pro 13-inch (M5), both on the latest iOS release of the selected Xcode. Requirement: Required to pass. |
| Action 2 | Archive. Scheme `PrestoCV`, platform iOS. The scheme archives with the Release configuration. Deployment preparation: TestFlight and App Store. |
| Post-actions | TestFlight Internal Testing, with the group of internal testers. |

The Release workflow tests the exact commit it archives. Its Test action is required to pass, so a failing test, package test or architecture check fails the build, and nothing reaches TestFlight, even for a tag on a commit that never went through a pull request. This is the one Xcode Cloud run that tests the tree on machines without the repository. It archives the version the tag or branch names, so a tag `v1.2.3` or a branch `release/1.2.3` gives version 1.2.3. Nothing submits a build for App Review: the owner does it by hand.

## Enforce the checks

The repository's plan has no rulesets and no branch protection, so GitHub lets a pull request merge whatever its checks say. The merge step is what enforces them: before it merges, it reads the statuses of the pull request's head commit, and it refuses unless the rule in "The pull request check" holds. A check it cannot read counts as not green.

To merge a pull request, bring the latest `main` onto its branch locally (a rebase), resolve the conflicts, run the tests again on a Mac, push the branch, run the pull request check on that head, and merge when `Mac mini · CI` is green. The check runs on the Mac mini, not on Xcode Cloud, so a push to an open pull request spends no compute hours.

If the plan gains rulesets, add `Linux · architecture check`, `Android · build of the portable targets` and `Mac mini · CI` as required status checks of a ruleset on `main` (GitHub offers a status in the ruleset after it has been reported once). A docs-only pull request never gets `Mac mini · CI`, so the script that writes it would have to write `success` for it too.

Check once that a failing test stops a merge: open a draft pull request that breaks one test, run the check on it, and confirm that it ends `failure` and that the merge step refuses. In the Release workflow, the Test action must show Required to pass in the workflow editor; then the archive is never distributed after a failed test.

## One-time setup

1. In Xcode 27, open Settings → Accounts and add your Apple ID (the account of the Apple Developer Program) and your GitHub account.
2. Clone `PigLardLord/PrestoCV` and open `PrestoCV.xcodeproj`.
3. Check that `DEVELOPMENT_TEAM` in `PrestoCV.xcodeproj/project.xcproj` is your Team ID, and that the app record "PrestoCV: CV & Resume Maker" for `com.PigLardLord.prestocv` exists in App Store Connect (My Apps → +).
4. Choose Product → Xcode Cloud → Create Workflow, and choose the `PrestoCV` product.
5. When Xcode asks for access to the source code, grant it: it opens GitHub, where you install the Xcode Cloud app for `PigLardLord/PrestoCV` only.
6. Set the first workflow to the settings of Main, then add Release (the workflow list is in the Report navigator, Cloud tab, and in App Store Connect under Xcode Cloud). Do not create a Pull Request workflow.
7. Create the group of internal testers in App Store Connect (TestFlight → Internal Testing) before the first Main or Release build, so that the post-action has a group to choose.

## Cutting a release

1. On GitHub, open Releases → Draft a new release. Type the tag `v1.2.3`, choose Create new tag on publish, and target `main`. Title it `v1.2.3`, then publish.
   - Or push a branch: `git switch -c release/1.2.3 && git push origin release/1.2.3`. Each push to that branch builds the same version again.
2. Xcode Cloud starts the `Release` workflow. Follow it in Xcode (Report navigator, Cloud tab) or in App Store Connect under Xcode Cloud. If the build fails with a message from `ci_pre_xcodebuild`, the tag or branch does not name a version: fix the name and start again.
3. Wait for the build in TestFlight. App Store Connect has to process it first, which takes a few minutes. Install it on a device and test it.
4. In App Store Connect, open the app's version 1.2.3 (create it with + if it does not exist), choose the build, and click Add for Review, then submit it to App Review. The texts of the product page and the notes for App Review are in [store-listing.md](store-listing.md).

## Reproducing a test build on a Mac

When the Test action fails while building, run the build it runs, on a Mac with Xcode 27, from the repository root:

```bash
xcodebuild build-for-testing -scheme PrestoCV -project PrestoCV.xcodeproj \
  -destination 'platform=iOS Simulator,id=<iPhone 17 Pro>' -destination 'platform=iOS Simulator,id=<iPad Pro 13-inch (M5)>' \
  -testPlan CI -derivedDataPath <empty directory> \
  CODE_SIGN_IDENTITY=- AD_HOC_CODE_SIGNING_ALLOWED=YES COMPILER_INDEX_STORE_ENABLE=NO
```

`xcrun simctl list devices available` gives the ids. Take the simulators of the latest iOS runtime, which the Release workflow and the pull request check use, and of iOS 26.5, the oldest the app supports; if a runtime has none of that model, create one with `xcrun simctl create "iPhone 17 Pro" "iPhone 17 Pro" <runtime id>`, the runtime id from `xcrun simctl list runtimes`. To run the tests as well, use `test` instead of `build-for-testing`: that runs them next to the sources, which the test machines do not have (see the next section).

| Argument | Why |
|---|---|
| `build-for-testing`, `-testPlan CI`, both destinations | They build what the Test action builds: the app, the plan's test bundles and every package target they use, for the iPhone and the iPad. |
| `-derivedDataPath` | An empty directory, as on Xcode Cloud, so nothing built earlier hides a failure. |
| `CODE_SIGN_IDENTITY=-`, `AD_HOC_CODE_SIGNING_ALLOWED=YES` | Ad hoc signing, as Xcode Cloud signs a test build, whatever the project's or the Mac's signing settings. |
| `COMPILER_INDEX_STORE_ENABLE=NO` | No index, as on Xcode Cloud. The build is faster. |

Ad hoc signing matters because it signs every bundle the plan builds: the app, the test bundles and the resource bundle of each package target, and `codesign` checks the layout of each one. The package tests cannot show a layout that `codesign` rejects in an iOS bundle ([R15](../architecture/rules.md#r15-resource-bundles-have-a-layout-every-platform-can-sign)): on macOS, `swift test` makes deep bundles, with the resources under `Contents/Resources`, and on Linux nothing is signed. Only the signed iOS build shows it, as `CodeSign …/CVPDFExporter_CVRendering.bundle` followed by `bundle format unrecognized, invalid, or unsuitable` (#240). Xcode 27.1 also signs a simulator build ad hoc when the two settings are left out, so that build fails the same way; passing them keeps the build the same as Xcode Cloud's whatever the Mac's settings.

## Reproducing a test run on a Mac

When a test passes on a Mac and fails on Xcode Cloud, it may read something the test machines do not have. To run the tests as the test machines run them, build into a folder outside the checkout, then move the products and rename the checkout, so that neither the paths in `#filePath` nor the build folder are where they were:

```bash
xcodebuild build-for-testing -scheme PrestoCV -project PrestoCV.xcodeproj \
  -destination 'platform=iOS Simulator,id=<iPhone 17 Pro>' -destination 'platform=iOS Simulator,id=<iPad Pro 13-inch (M5)>' \
  -testPlan CI -derivedDataPath ../dd CODE_SIGN_IDENTITY=- AD_HOC_CODE_SIGNING_ALLOWED=YES COMPILER_INDEX_STORE_ENABLE=NO
mv ../dd/Build/Products ../products && cd .. && mv PrestoCV PrestoCV.away
xcodebuild test-without-building -xctestrun products/PrestoCV_CI_*.xctestrun \
  -destination 'platform=iOS Simulator,id=<iPhone 17 Pro>' -destination 'platform=iOS Simulator,id=<iPad Pro 13-inch (M5)>'
mv PrestoCV.away PrestoCV
```

Here the checkout is `PrestoCV`; use the name of yours.

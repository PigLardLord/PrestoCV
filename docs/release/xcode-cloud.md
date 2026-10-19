# Releasing with Xcode Cloud

Xcode Cloud tests version 1, archives it, signs it and uploads it to TestFlight (ADR 0022, ADR 0024). The workflows are set up in Xcode and App Store Connect with the owner's Apple ID, so they are not in the repository. This page holds the settings to enter, the one-time setup, and the steps of a release. The repository holds the rest:

| Path | What it does |
|---|---|
| `ci_scripts/ci_pre_xcodebuild.sh` | Before an archive: sets `MARKETING_VERSION` from the tag `v<version>` or the branch `release/<version>`. Any other ref keeps the project's version. A tag `v…` or branch `release/…` that does not name a version such as `1.2` or `1.2.3` fails the build. It edits only the CI checkout. The build number is Xcode Cloud's. |
| `ci_scripts/ci_post_xcodebuild.sh` | After an archive: runs `Tools/Release/check-archive.sh`, and a failure stops the build before TestFlight. After `build-for-testing`: runs the package tests of `PrestoCVCore`, `CVPDFExporter` and `CVGeneratorAI`, the source checks of `Tools/SourceChecks`, the architecture check and its self-test (which see the Apple-only branches of the package manifests), and `swift build` of `PrestoCVApp` and `CVPDFExporterExamples`. Every step runs and the script fails at the end. On a pull request the checker compares the baseline with `origin/<target branch>`; a checkout without that branch is compared with an empty baseline. |
| `TestPlans/PrestoCV.xctestplan` | The scheme's default plan: `PrestoCVTests`, the exporter's simulator test targets, and `PrestoCVUITests`. |
| `TestPlans/CI.xctestplan` | The same without `PrestoCVUITests`, which are Xcode's template launch tests: they take most of an hour and check nothing, so they would spend the free compute hours. |
| `PrestoCV.xcodeproj/project.xcproj` | `DEVELOPMENT_TEAM`, in the project's build settings: the one place that holds the Team ID. |

Xcode Cloud finds the scripts because `ci_scripts/` is next to `PrestoCV.xcodeproj`. They need no setting in a workflow.

Both plans hold the four simulator test targets of the `CVPDFExporter` package, `CVDesignCatalogTests`, `CVDesignCatalogFileStoreTests`, `CVRenderingTests` and `CVRenderingWebKitSupportTests`: the native renderer contract on the simulator, so it runs in the same Test action on the iPhone and the iPad. They are the targets of the package's `ExporterTests` scheme, which stays for running them from the package. A new simulator test target of that package goes into the scheme and into both plans, and gets R16 in `Tools/ArchitectureCheck/rules.json`.

## Tests run without the repository

The Test action runs in two steps, on different machines:

1. **The build host** has the repository. It runs `xcodebuild build-for-testing` with the plan, then `ci_scripts/ci_post_xcodebuild.sh`, so the package tests, the source checks and the architecture check run there.
2. **The test machines** have only what the build made: the `.xctestrun` file and the products. They run `xcodebuild test-without-building` on the iPhone and the iPad. The repository is not there, and neither is the build host's build folder.

So a test in a plan finds its files in a bundle, never through `#filePath` ([R16](../architecture/rules.md#r16-tests-that-a-test-plan-runs-read-only-bundles)):

| What a test reads | Where it reads it |
|---|---|
| The example CVs and the other resources the app ships | The app bundle, through `Bundle(for:)` with a class of the app |
| A package's test resources, such as the markup contract page of `CVDesignCatalogTests` and the golden files of `CVRenderingTests` | `Bundle.module`, declared in the package's manifest |
| A document an app test compares with the app: `docs/design/app-icon.md` | The test bundle; the project copies it into `PrestoCVTests` |
| The string catalog's source, the Swift sources, the project file and the privacy manifest | Nowhere in a plan. `Tools/SourceChecks` checks them, on the build host and on the Linux job |

A test that read the source tree passed on a Mac, next to the sources, and failed on Xcode Cloud: that was #246. The architecture checker refuses `#filePath` and `#file` in every target that a plan runs, and a plan target without R16.

## Workflows

Create the three workflows with these settings. Anything not listed keeps its default.

### Pull Request

| Section | Setting |
|---|---|
| General | Name: `Pull Request` |
| Environment | Xcode: Latest Release (Xcode 27). macOS: Latest Release. |
| Start condition | Pull Request Changes. Source branch: All Branches. Destination branch: `main`. Auto-cancel builds: on. |
| Action 1 | Test. Scheme `PrestoCV`, test plan `CI`, platform iOS. Destinations: iPhone 17 Pro and iPad Pro 13-inch (M5), both on iOS 27.0. Requirement: Required to pass. |
| Post-actions | None. |

GitHub shows the result in the pull request.

The destinations name an iOS release rather than the latest one. The exporter's WebKit tests record what WebKit does, and that changes between releases: on iOS 26.2 the content rules let a page's `object` and `embed` loads through, which they block on iOS 26.5 and 27.0. A destination that follows the latest release would change the result of the gate without a change of the code. Moving to another release is a change of its own: run the `CI` plan on the new release first (see [Reproducing a test run on a Mac](#reproducing-a-test-run-on-a-mac)), and update the tables of `SecureWebViewTests` where WebKit changed, in the same pull request as this page.

### Main

| Section | Setting |
|---|---|
| General | Name: `Main` |
| Environment | Xcode: Latest Release (Xcode 27). macOS: Latest Release. |
| Start condition | Branch Changes. Branch: `main` only. |
| Action 1 | Test. Same as the Pull Request workflow: scheme `PrestoCV`, test plan `CI`, iPhone 17 Pro and iPad Pro 13-inch (M5) on iOS 27.0. Requirement: Required to pass. |
| Action 2 | Archive. Scheme `PrestoCV`, platform iOS. The scheme archives with the Release configuration. Deployment preparation: TestFlight (Internal Testing Only). |
| Post-actions | TestFlight Internal Testing, with the group of internal testers. |

A build from `main` is for the internal testers only. It cannot be submitted to App Review.

### Release

| Section | Setting |
|---|---|
| General | Name: `Release` |
| Environment | Xcode: Latest Release (Xcode 27). macOS: Latest Release. |
| Start conditions | Two, and either one starts the workflow. Tag Changes: custom, the tag name begins with `v`. Branch Changes: custom, the branch name begins with `release/`. |
| Action 1 | Test. Same as the Pull Request workflow: scheme `PrestoCV`, test plan `CI`, iPhone 17 Pro and iPad Pro 13-inch (M5) on iOS 27.0. Requirement: Required to pass. |
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
4. In App Store Connect, open the app's version 1.2.3 (create it with + if it does not exist), choose the build, and click Add for Review, then submit it to App Review. The texts of the product page and the notes for App Review are in [store-listing.md](store-listing.md).

## Reproducing a test build on a Mac

When the Test action fails while building, run the build Xcode Cloud runs, on a Mac with Xcode 27, from the repository root:

```bash
xcodebuild build-for-testing -scheme PrestoCV -project PrestoCV.xcodeproj \
  -destination 'platform=iOS Simulator,id=<iPhone 17 Pro>' -destination 'platform=iOS Simulator,id=<iPad Pro 13-inch (M5)>' \
  -testPlan CI -derivedDataPath <empty directory> \
  CODE_SIGN_IDENTITY=- AD_HOC_CODE_SIGNING_ALLOWED=YES COMPILER_INDEX_STORE_ENABLE=NO
```

`xcrun simctl list devices available` gives the ids. Take the simulators of iOS 27.0, the release the workflows name; if it has none of that model, create one with `xcrun simctl create "iPhone 17 Pro" "iPhone 17 Pro" <runtime id>`, the runtime id from `xcrun simctl list runtimes`. To run the tests as well, use `test` instead of `build-for-testing`: that runs them next to the sources, which the test machines do not have (see the next section).

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

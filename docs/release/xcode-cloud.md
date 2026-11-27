# Releasing with Xcode Cloud

Xcode Cloud tests version 1 before a store build, archives it, signs it and uploads it to TestFlight (ADR 0022, ADR 0024). It does not check pull requests: a maintainer's Mac does ([Continuous integration](../ci.md#the-pull-request-check), ADR 0029). The workflows are set up in Xcode and App Store Connect with the maintainer's Apple ID, so they are not in the repository. This page holds the settings to enter, the one-time setup and the steps of a release; [Continuous integration](../ci.md) describes the scripts, the test plans and the checks.

The workflows below build with the latest release of Xcode. When Apple ships one with another Swift, every build stops at `ci_pre_xcodebuild.sh` until a pull request moves `.swift-version` and the CI workflow to that Swift, so that a computer, the pull request checks and the release never build with two compilers.

## Workflows

Create the Main and Release workflows with these settings. Anything not listed keeps its default.

### Pull Request (disabled)

The Pull Request workflow exists in App Store Connect and is disabled. Keep it disabled: a maintainer's Mac [checks pull requests](../ci.md#the-pull-request-check). A run took about 14 minutes, 75 runs used 80% of a month's 25 compute hours, and each one repeated what that Mac runs before every push. Main and Release are what the hours are for. Turning the workflow on again, with the settings below, spends them on pull requests again, which changes ADR 0029.

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

A build from `main` is for the internal testers only. It cannot be submitted to App Review. Main has no Test action: a pull request merges only when its branch contains the latest `main` and `Mac mini · CI` is green on that exact head (a pull request that changes only `docs/` or `*.md` files needs only `Linux (local) · CI` and `Android (local) · CI`), so the tree that reaches `main` has already been tested. Each merge to `main` starts a Main run of about 10 minutes of the 25 compute hours a month.

A Main build takes the project's version (`MARKETING_VERSION`), and its build number is the run's number. Once App Review approves a version, App Store Connect closes that version to new builds: every later upload of it fails at "Preparing build for App Store Connect" with ITMS-90186 (the version's train is closed) and ITMS-90062 (the version must be higher than the approved one). So `main` always carries the next version to release, never one already released: see step 5 of [Cutting a release](#cutting-a-release).

### Release

| Section | Setting |
|---|---|
| General | Name: `Release` |
| Environment | Xcode: Latest Release (Xcode 27). macOS: Latest Release. |
| Start conditions | Two, and either one starts the workflow. Tag Changes: custom, the tag name begins with `v`. Branch Changes: custom, the branch name begins with `release/`. |
| Action 1 | Test. Scheme `PrestoCV`, test plan `CI`, platform iOS. Destinations: iPhone 17 Pro and iPad Pro 13-inch (M5), both on the latest iOS release of the selected Xcode. Requirement: Required to pass. |
| Action 2 | Archive. Scheme `PrestoCV`, platform iOS. The scheme archives with the Release configuration. Deployment preparation: TestFlight and App Store. |
| Post-actions | TestFlight Internal Testing, with the group of internal testers. |

The Release workflow tests the exact commit it archives. Its Test action is required to pass, so a failing test, package test or architecture check fails the build, and nothing reaches TestFlight, even for a tag on a commit that never went through a pull request. This is the one Xcode Cloud run that tests the tree on machines without the repository. It archives the version the tag or branch names, so a tag `v1.2.3` or a branch `release/1.2.3` gives version 1.2.3. Nothing submits a build for App Review: the maintainer does it by hand.

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
5. Right after the tag or the release branch, raise the version on `main` to the next one (1.2.4 for fixes, 1.3 for new features), in a pull request that sets every `MARKETING_VERSION` of `PrestoCV.xcodeproj/project.xcproj`. The build number stays the one Xcode Cloud sets: it already tells the builds of a version apart (1.2.4 (180) in TestFlight), so the version keeps meaning a release.

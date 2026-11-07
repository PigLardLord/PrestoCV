# 0009. Persisted CVs use a versioned DTO, schema v1, strict decoding, revisions and a store lock

- **Status:** Accepted
- **Date:** 2026-09-28
- **Related:** R6, R7, R12, [ADR 0010](0010-ui-free-presentation-package.md), issues #10, #11, #12, #30, #45, #56

## Context

Persistence today has these problems:
- The domain types are the persisted types.
- Every field is decoded with `decodeIfPresent ?? default`, so any JSON object becomes a CV, and a missing `id` becomes a new random UUID on each load.
- Writes are not atomic and have no data protection.
- A corrupt file disappears without an error, and a storage failure reads as "no CVs".
- A legacy lookup makes some CVs impossible to delete, and saving one duplicates it.
- There is no schema version, no revision and no timestamp. Two windows, or two processes, can silently overwrite each other.

The app is not released, so no user data needs migrating.

## Decision

- **On-disk format: `CVFileV1`.** It is a DTO, separate from the domain `CV`. Fields: `schemaVersion: 1`, `id`, `revision`, `createdAt`, `updatedAt`, and the content, with structured periods and bounded levels.
  - **The envelope is frozen:** `schemaVersion` is a top-level integer in every future version.
- **Strict decoding.** Required fields are required.
  - `revision` must lie in 1…2³¹−1, so incrementing it cannot overflow.
  - Periods are built by the domain's single rule, `Period.make`; every contradictory or incomplete combination is rejected.
  - Text is capped at 10 000 characters, and lists at 500 items.
  - An email must already be in its normalised form.
  - The embedded id must match the file name.
- **Every read has its own outcome.** The repository never guesses:

  | Outcome | What happens |
  |---|---|
  | Newer schema | Left untouched, reported as `upgradeRequired` |
  | I/O failure, or a symbolic link | Left untouched, reported as `unreadable`, retried next time (for example, before first unlock) |
  | Larger than the cap (5 MB) | Not read, reported as `tooLarge` |
  | Decoding failure of a supported version | Moved to `Quarantine/` (a `N~` prefix avoids collisions), reported as `corrupt` with its reason |
  | Quarantine not possible | Reported as `quarantineFailed`; the listing continues |

  Only a store that does not exist yet is empty. A store that cannot be listed is `storeUnavailable`.
- **Revisions, timestamps and the lock.**
  - `create`, `update` and `delete` are conditional on the revision. `update` of a changed CV fails with `conflict(storedRevision:)`; update or delete of a missing CV fails with `notFound`. Nothing is overwritten and nothing is resurrected.
  - Every mutation holds an exclusive `flock` on the store's lock file, so the check and the write are atomic across repository instances and processes. An actor alone only protects one instance.
  - The repository assigns the revision and the timestamps: through the injected `TimeSource`, and via `package`-level API, so callers cannot forge them. The listing is ordered by last change.
- **Maintenance port: `CVStoreMaintenance`.**
  - `restore(quarantined:)`:
    - accepts only names matching `^(\d+~)?<UUID>\.cv\.json\z` inside the quarantine folder, and refuses symbolic links;
    - under the store lock, reads the candidate through the same checks as a listing: size cap, version and strict decoding;
    - moves it back only if that read succeeds and no active CV has the same id. Otherwise it throws the read's outcome, and both folders stay unchanged (review round 3).
  - `erase(_:)` deletes every copy of a CV, whatever its schema or state, including quarantined ones (GDPR erasure).
  - `purgeQuarantine(olderThan:)` enforces retention (30 days).
  - `quarantined()` lists the quarantine, oldest first, with the date each file entered it.
  - `eraseAll(keepingLedger:)` removes, under one hold of the lock, every CV file, the quarantine, the staged copies and, unless the caller keeps it, the ledger. The ledger holds only ids; `EraseEverything` keeps it while a legacy source remains, so that source is not imported again, and names it in the report. A file it cannot remove is named in the report (kind and name) and the rest still go; a second call finishes the work.
- **Nothing is written that could not be read back.** Before replacing a file, the repository encodes the CV and checks the size cap. It then decodes the bytes through the same strict path as a read, and requires the same CV back. Otherwise it throws `wouldNotReadBack`, which becomes `AuthoringError.tooLarge`, and the previous version stays. Without this, a save that exceeded a limit would be acknowledged, then quarantined or reported as `tooLarge` on the next listing (review round 2).
- **Timestamps** are stored with whole-second precision. The repository truncates the clock's value before using it, so the read-back comparison holds for any clock.
- **Writes** are one file per CV, atomic, with `complete` data protection on Apple platforms. The composition root gives the location and the protection class (`StoreOptions`); the default is `complete`, and the app does not change it. Tests of the store's logic (listing, quarantine, restore, purge, dates, sample source, failure causes) give none: a class-A write needs the user's key, and a CI host whose keybag is locked refuses it with `EPERM`, so those tests would pass or fail with the host. The protection itself is pinned by the tests that are about it: a repository built with the defaults writes atomically and asks for complete protection, and, on a device, a stored file has that class.
- **A failed write keeps its cause as far as the repository's callers.**
  - **What is kept.** `writeFailed(file:cause:)` carries the underlying error as a `FailureCause`: a domain (Cocoa, POSIX or other) and a code, and nothing else: no path and no message (R7). A test or a direct caller of the repository can name it (`cocoa 513 (posix 13)`, `posix 28`).
  - **Which outcomes.** Only the failures that map to `writeFailed` keep a cause: the write of a file, and the removal and the move that save, delete, restore, erase and purge make. The other classified outcomes are codes and keep none: `unreadable`, `corrupt`, `tooLarge`, `storeUnavailable(.cannotList)` and `(.cannotLock)`, and a failed move into the quarantine during a listing (`quarantineFailed`).
  - **The errno.** Under a Cocoa error it also keeps the `errno` that Foundation reports there, because Cocoa 513 (no permission) covers both a folder that cannot be written to (`EACCES`, 13) and, expected but not observed, a file the device has locked (`EPERM`, 1). Foundation on macOS 26.6 and 27.0 reports it for a write, a removal and a move into a read-only folder, and a test asserts it for the write on Apple platforms. swift-corelibs-foundation on Linux reports none, so there the errno is empty.
  - **Where it stops.** The use cases translate a repository failure that is not a conflict, a missing CV or a read-back failure to `AuthoringError.unavailable` (R7), and the cause does not cross that line. The text the user sees does not depend on it. No log records the cause yet: a diagnostic boundary that records the coded `FailureCause` before the use case translates it is not built, and belongs to the change that wires the composition root (ADR 0012).
- **Data protection is `complete`, and a locked device is a read error, never an empty store.** Decided in #323.
  - **Can a launch list the store while the device is locked?** It must not, and that is a requirement on the composition root, which does not exist yet (ADR 0012); the wiring change verifies it. Today the reasons it holds are these: prewarming runs the process only up to `UIApplicationMain`; the repository does no I/O when it is built (a test checks this); and the store is first read when the first screen starts. The app has no background mode, background task, widget, intent, notification extension or app delegate that could start it without a screen. No test covers the launch path itself, so the wiring change keeps the repository's construction free of reads and lists from the first screen, not from `App.init`.
  - **If a read did happen while locked,** `list` returns the CVs it can open and an `unreadable(file)` issue for each one it cannot. `load`, `create`, `update` and `delete` of such a CV fail with `unreadable`: nothing is overwritten, removed or quarantined, and the CV is never reported as missing or as a first run. Before the first unlock after a restart even the lock file, which has the default class `completeUntilFirstUserAuthentication`, cannot be opened: a listing or a write then fails with `storeUnavailable(.cannotLock)`, an error as well. The next call reads the files again. Tests: a CV that cannot be opened is listed again once it can; building the repository touches nothing. A file mode of 0 stands for the lock, because Linux and the simulator do not apply protection, so these tests show how the repository reacts to a file it cannot open, not how the real class behaves. They also skip when run as root, which includes the Linux CI container. That the repository asks for the class is asserted on every host, by the test of its default write options. That the system applies it is asserted by one test that reads the protection attribute of a written file, and it runs on a physical device only. No automated gate runs on a device, so nothing in CI checks the class that is applied: it is checked by hand on a device when the protection changes.
  - **Why `complete` stays.** A CV holds contact details and a work history, so it gets the strongest class. Nothing needs it while the device is locked. A save that comes after the device has locked fails with `writeFailed` and its cause. Autosave then keeps the content in memory, shows that it is not stored, and writes it with the next change or flush, which the editor asks for when the app leaves the foreground.
  - **When this changes.** A feature that must read or write while the device is locked (a widget, a background refresh, an extension) moves the CV files to `completeUntilFirstUserAuthentication`, and updates this ADR and the test in the same change. The legacy `FileStorageService` already uses that class; ADR 0012 removes it.
- **User experience.**
  - A `conflict` offers "reload" (take the stored version) or "save as a copy".
  - `notFound` on save (deleted in another window) offers "save as a copy" or "discard".
  - Autosave (#30) will use the same serialised save path ([ADR 0010](0010-ui-free-presentation-package.md)), debounced.
  - On macOS, the app sets `LSMultipleInstancesProhibited`. The lock still protects against other processes, such as extensions.
- **Sample CVs** use the same v1 format and decoder.
- **No compatibility with the current format.** Development data is reset when the new persistence lands.
- **Migrations.** From the first release on, every schema change ships with a migration from every released version, and a test for each.

## Consequences

- Ghost CVs, unstable identities, duplicate-on-save, lost updates and resurrection disappear by construction. Each has a test.
- Presentation has to handle `conflict` and `deletedElsewhere`.
- Anyone running a development build loses their test CVs once.

## Alternatives considered

- **Lenient decoding for robustness.** Rejected: leniency is what turned bad data into invisible bugs.
- **Quarantine every unreadable file.** Rejected after review: before first unlock on iOS it would quarantine every CV.
- **An actor as the only serialisation.** Rejected after review: two instances on one store lost 200 of 200 races.
- **SwiftData or Core Data.** Not needed for a handful of documents per user. It would tie persistence to Apple platforms and break the Linux build. It can be revisited together with iCloud sync (#56).

## Validation

The validation prototype in `Prototypes/ADRValidation/`. Swift 6.3.3, Linux. 27 Core tests pass.

**Decoding**
- Rejected: `{}`, a missing `id`, a missing, zero, negative or `Int.max` revision, an out-of-range level, month 13 with a valid start, an email with a trailing newline.
- Every invalid period shape gives a typed `PeriodError`.
- "May 2020 – 2020" is accepted.

**Listing**
- **Mixed directory:** a healthy file is listed; a corrupt file is quarantined with its reason; a newer-schema file stays byte-for-byte untouched.
- **Unreadable file** (mode 000): reported and left in place, then listed again once readable.
- **Oversized file:** reported without being read.
- **A regular file where `Quarantine/` should be:** the healthy CV is still listed, and the failure is reported.
- **Unreadable store:** an error, while a missing store is a first run.
- **Id and file name disagree:** the file is corrupt.

**Maintenance**
- **Restore:** a repaired file comes back.
  - A file that is still corrupt, or over the size cap, is refused and stays in quarantine.
  - `../` names, `1~../../` names, a name with a trailing newline and a symbolic link are all refused.
- **Erase:** removes the stored newer-schema file and both quarantined copies.
- **Purge:** removes only old entries.
- **Erase everything:** reaches every kind of file, leaves only the lock, creates nothing in a store that was never created, and unlinks a linked quarantine without touching its target.

**Writes**
- A CV whose encoded file exceeds the cap is refused on create and on update:
  - with 4-byte Unicode characters and a small cap;
  - with a single field over the 10 000-character text limit, well under the byte cap.

  Each time the previous version stays, the listing is unchanged, and `SaveCV` reports `tooLarge`.
- A clock with fractional seconds still round-trips.

**Contract and concurrency**
- The contract suite passes on both repositories: round trip with timestamps, create twice, update bumps the revision and keeps `createdAt`, stale update and stale delete, update after delete, listing order.
- **50 concurrent updates** from one revision on one instance: exactly one succeeds.
- **Two instances, 40 concurrent updates:** exactly one succeeds. Before the lock, all of them did.

**Found during validation**
- Review round 2: the writer accepted data that its own reader rejected.
- Fixing that exposed a latent defect: ISO 8601 drops fractional seconds, so with a real clock every write would have failed the read-back check.
- The first quarantine used a `N-` prefix and stripped it with `^\d+-`, which also ate the leading digits of UUID names.
- `completeFileProtection` compiles on Linux, where it has no effect, so no platform check is needed.

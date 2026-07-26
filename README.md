# Cruft

A macOS disk cleanup utility for developers. Finds regenerable caches, build
artifacts, and developer junk — and tells you exactly why each candidate is
safe to remove.

Finding large files is easy. Deciding what is *safe to delete* is the entire
product. `ncdu` answers "what is big"; Cruft answers "what is big and
regenerable". On a working developer's Mac, Xcode DerivedData, iOS
DeviceSupport, simulator runtimes, and package-manager caches routinely
account for 30–60 GB — far more than the system caches consumer cleaners
chase.

## Current status

**Milestone M0 — scan engine and CLI, dry-run only.** This build is
physically incapable of deleting anything: no deletion code path exists yet.
Use it to see what a future version would reclaim, and to sanity-check the
numbers against your own disk.

```console
$ cruft scan --category developer --dry-run
Scanning 9 rule roots…
xcode-derived-data — 607,9 MB [safe]
  Build artifacts, regenerated on next build
  366,9 MB  /Users/you/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
  ...

Total reclaimable: 1,02 GB — dry run, nothing was deleted.
```

## Safety model

Cruft is designed on the assumption that it will one day run with Full Disk
Access on machines that are not yours. Every design decision defers to that.

| Level | Behaviour | Examples |
|---|---|---|
| `safe` | Selected by default | DerivedData, Homebrew/npm/pip caches |
| `review` | Shown, never pre-selected | pnpm store, large & old files |
| `expert` | Hidden behind an explicit toggle | Language files, universal binaries |
| *never* | Never surfaced at all | Keychains, container data, `/System` |

Guarantees, enforced in code and tests:

- **Everything goes to Trash.** When deletion ships (M4), it uses
  `FileManager.trashItem` exclusively — never `unlink`. Everything is
  recoverable.
- **The never-delete list is hardcoded** in `NeverDelete.swift`, not in the
  rules file, so a malformed or malicious rules file cannot widen what the
  tool will touch. It is checked against the final, symlink-resolved URL.
- **iCloud-evicted files are never read.** Scanning uses `stat`-level
  metadata only; reading a dataless file would silently re-download it.
- **Sizes are allocated size**, not logical size — APFS clones and sparse
  files make logical size wrong.
- **Every candidate is traceable.** Each result carries the rule ID and a
  plain-language reason (`cruft rules explain xcode-derived-data`).
- **No telemetry**, no update checks, no network access of any kind.

## Install

Requires macOS 26 and Xcode 26 (Swift 6).

```console
$ git clone https://github.com/alfredoptarigan/cruft.git && cd cruft
$ just install        # builds release, installs to ~/.local/bin
```

Or without [just](https://github.com/casey/just):

```console
$ swift build -c release
$ cp -R .build/release/cruft .build/release/CleanKit_CleanKit.bundle ~/.local/bin/
```

The `CleanKit_CleanKit.bundle` directory must sit next to the binary — it
contains the rules database.

### The app

```console
$ just app && open dist/Cruft.app
```

SwiftUI shell over the same engine: Full Disk Access banner with a deep link
to System Settings, live scan progress, and read-only results grouped by
rule. Selection and deletion are later milestones — the app cannot delete
anything yet.

The bundle is ad-hoc signed. macOS ties Full Disk Access to the bundle ID
*and* code signature, so a rebuilt app must be re-granted FDA each time —
a known tradeoff until real signing lands (M6). The CLI does not have this
problem; grant FDA to your terminal once.

To package a DMG (app + CLI): `just dmg` (output in `dist/`). The DMG is
unsigned and un-notarized; downloaded copies will trip Gatekeeper. Building
from source or a future Homebrew tap is the recommended route.

## Usage

```console
$ cruft scan --category developer --dry-run   # scan one category
$ cruft scan --all --json > report.json       # machine-readable report
$ cruft rules validate                        # sanity-check the rules file
$ cruft rules explain xcode-derived-data      # why is this safe?
$ cruft doctor                                # FDA status, purgeable-space gap
```

**Full Disk Access:** without it, scans silently miss most of `~/Library`.
`cruft doctor` reports your status; grant FDA to your terminal in
System Settings → Privacy & Security → Full Disk Access.

`cruft doctor` also explains why freed space sometimes doesn't show up in
`df`: Time Machine local snapshots keep referencing it until they thin out.

## Rules

Cleanup targets live in `Sources/CleanKit/Rules/Resources/rules.yaml`, not in
code:

```yaml
- id: xcode-derived-data
  path: ~/Library/Developer/Xcode/DerivedData/*
  category: developer
  safety: safe
  min_age_days: 7
  reason: "Build artifacts, regenerated on next build"
```

Contributing a rule means adding YAML plus **two tests**: one proving it
matches the intended path, one proving it does *not* match a neighbouring
dangerous path (see `RuleMatchTests.swift`). A rule without a negative test
does not get merged.

## Architecture

```
CleanKit/            Swift package, zero UI dependencies
  Model/             CleanupItem, SafetyLevel, Category, ScanResult
  Safety/            NeverDelete (hardcoded deny list)
  Scanning/          Scanner actor, FileWalker, DatalessFilter
  Rules/             Rule, RuleStore, rules.yaml
  Reporting/         DryRunReport
cruft-cli/           ArgumentParser executable
```

The CLI is not a demo — it is the primary test surface. Every capability the
future GUI has will be reachable from the CLI first.

## Roadmap

| Milestone | Deliverable |
|---|---|
| M0 ✅ | Scan engine + CLI, dry-run only |
| M1 ✅ | Full Disk Access onboarding, SwiftUI shell, live scan (read-only) |
| M2–M3 | Cancellation polish, results with tri-state selection |
| M4 | Trash-based deletion, undo log, exclusions |
| M5–M6 | Polish, signing, notarization, Homebrew tap |

Deliberately out of scope: malware scanning, browser-privacy cleaning,
root-level cleanup via privileged helper, and anything involving telemetry.

## Development

```console
$ just          # list tasks
$ just test     # 33 tests, all against throwaway fixture trees
$ just scan     # dry-run against your own machine
```

Tests never touch the real filesystem: every test builds a throwaway tree
under a temp directory and treats it as a fake home.

## License

Not yet chosen — will be settled before the first tagged release. Until
then: all rights reserved, but the code is public for review.

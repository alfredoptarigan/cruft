# Cruft

A macOS disk cleanup utility. Finds and removes regenerable caches, build
artifacts, and developer junk. Open source, distributed to individuals — not
a commercial product.

Read `PLAN.md` for full scope, architecture rationale, and the milestone
roadmap. This file covers the rules that apply to every change.

---

## Non-negotiable safety rules

This tool deletes files on other people's machines while holding Full Disk
Access. Every rule below outranks convenience, performance, and feature work.

1. **Never call `FileManager.removeItem`.** Deletion goes through
   `TrashService`, which uses `FileManager.trashItem(at:resultingItemURL:)`.
   Everything is recoverable from Trash. No exceptions, including for
   "obviously safe" temp files.

2. **`NeverDelete` is the last gate before every deletion.** It runs on the
   final URL, not on the rule that produced it. If `NeverDelete.contains(url)`
   returns true, the operation aborts and logs. Never bypass it, never make it
   configurable, never move the check earlier in the pipeline.

3. **Never read file contents during a scan.** Scanning uses `stat`-level
   metadata only. Reading a dataless iCloud file triggers a download —
   potentially tens of gigabytes without the user's knowledge. Every candidate
   passes through `DatalessFilter` before it enters a `ScanResult`.

4. **Use `.totalFileAllocatedSizeKey`, never `.fileSizeKey`.** APFS clones and
   sparse files make logical size wrong. Reporting inflated numbers destroys
   trust in the tool.

5. **Every new rule needs two tests**: one proving it matches its intended
   path, and one proving it does *not* match a neighbouring dangerous path.
   A rule without a negative test does not get merged.

6. **Tests never touch the real filesystem.** Use `TestFixture` to build a
   throwaway tree under a temp directory. No test may reference `~` or `/`
   directly.

---

## Architecture

```
CleanKit/                       Swift Package, zero UI dependencies
  Sources/
    CleanKit/
      Model/          CleanupItem, SafetyLevel, Category, ScanResult
      Safety/         NeverDelete, Guard, TrashService, UndoLog
      Scanning/       Scanner (actor), FileWalker, DatalessFilter
      Rules/          Rule, RuleStore, Resources/rules.yaml
      Reporting/      DryRunReport
    cruft-cli/        ArgumentParser executable
  Tests/CleanKitTests/
```

`CleanKit` must never import SwiftUI or AppKit. The GUI (a later milestone)
depends on CleanKit; CleanKit depends on nothing but Foundation, Yams, and
ArgumentParser.

The CLI is not a demo — it is the primary test surface. Any capability the GUI
will have should be reachable from the CLI first.

---

## Conventions

- Swift 6, strict concurrency enabled. Deployment target macOS 26.
- `Scanner` is an `actor`. Progress is delivered via
  `AsyncThrowingStream<ScanEvent, Error>` — never a completion handler,
  never a polled property.
- Prefer `@Observable` over `ObservableObject`.
- No `if #available` checks. The minimum target is high enough that everything
  in the SDK is available.
- Public types are `Sendable`. If something can't be `Sendable`, that's a
  design smell — reconsider before reaching for `@unchecked`.
- `CleanupItem.ruleID` is mandatory on every item. Users must be able to trace
  any candidate back to the rule that produced it.

---

## Rules file

Cleanup rules live in `Rules/Resources/rules.yaml`, not in Swift code. Adding
a cleanup target means adding YAML plus tests — it should not require touching
the scanner.

```yaml
- id: xcode-derived-data
  path: ~/Library/Developer/Xcode/DerivedData/*
  category: developer
  safety: safe
  min_age_days: 7
  reason: "Build artifacts, regenerated on next build"
```

`safety` is one of `safe`, `review`, `expert`. There is no `never` value —
the never-delete list is hardcoded in `NeverDelete.swift` specifically so a
malformed YAML file cannot widen the blast radius.

---

## Commands

```
swift build
swift test
swift run cruft scan --category developer --dry-run
swift run cruft rules validate
swift run cruft doctor
```

---

## Scope boundaries

Not in scope, do not add without discussion:

- Malware or adware scanning (requires a signature database with ongoing
  maintenance)
- Privileged helper / root-level cleanup of `/Library` (SMAppService + XPC;
  large complexity for modest gain — user-level covers most of the value)
- Analytics, telemetry, update checkers, licensing
- Any operation on `/System` (blocked by SIP anyway)
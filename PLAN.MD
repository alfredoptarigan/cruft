# Cruft — plan

## What this is

A macOS cleanup utility in the spirit of CleanMyMac, built around one
observation: finding large files is easy, and deciding what is *safe to
delete* is the entire product.

`ncdu` and its relatives answer "what is big". Cruft answers "what is big and
regenerable". The difference is a curated rules database, not a clever
algorithm.

The differentiator is developer junk. On a working developer's Mac, Xcode
DerivedData, iOS DeviceSupport, simulator runtimes, Docker images, and package
manager caches routinely account for 30–60 GB — far more than system caches.
Most consumer cleaners handle these poorly or not at all.

---

## Scope

### In v1

| Module | Why |
|---|---|
| Smart scan | The product's front door — one action, combined results |
| System junk | Caches, logs, app leftovers |
| Developer junk | Xcode, npm, Docker, Homebrew, Gradle — the highest-value category |
| Large & old files | Cheap to build, immediately useful |

### Later

- **Uninstaller** (v1.5) — bundle-ID reverse lookup across `~/Library/*`
- **Space lens** (v2) — treemap visualisation

### Never

- Malware / adware scanning — needs a signature database maintained forever
- Privacy module (browser history, cookies) — low value, high creepiness
- Root-level cleanup via privileged helper — see "Deliberate omissions"

---

## Platform constraints

These are the macOS-specific realities that shape the design. Each one has
cost someone a weekend.

**Full Disk Access (TCC).** Without it, the app cannot read other apps'
directories under `~/Library`. TCC binds permission to bundle identifier plus
code signature, so ad-hoc-signed debug builds lose the grant on rebuild. This
is a large part of why the CLI comes first — grant FDA to your terminal once
and iterate freely.

**Dataless iCloud files.** Files evicted to iCloud remain visible with full
metadata. Reading their contents triggers a re-download. A naive scanner can
silently pull down tens of gigabytes. Detection: `stat` and check
`st_flags & SF_DATALESS` (`0x40000000`), or read
`URLResourceKey.ubiquitousItemDownloadingStatusKey`. `stat` itself does not
materialise the file — only reading contents does.

**APFS clones and sparse files.** Two files reporting 1 GB each may occupy
1 GB total. Always use `.totalFileAllocatedSizeKey`.

**Purgeable space.** Freed space may not appear in `df` because Time Machine
local snapshots still reference it. `cruft doctor` should surface this by
comparing `df` output against `tmutil listlocalsnapshots /`.

**SIP.** `/System` is untouchable. Not worth a single line of code.

**Gatekeeper.** Since the app is distributed to other people, it needs
Developer ID signing plus notarization. Without it, recipients get a scary
dialog. Requires Apple Developer Program membership. Alternative for the
open-source audience: distribute via a Homebrew tap that builds from source,
which sidesteps Gatekeeper entirely and is often preferred by developers.

---

## Architecture

```
Scanner engine     Walk filesystem, collect metadata, filter dataless
      ↓
Rules engine       Match paths against rules.yaml, assign safety level
      ↓
Safety layer       Dry-run, exclusions, NeverDelete gate, move to Trash
      ↓
Interface          CLI (M0) → SwiftUI app (M1+)
```

`CleanKit` is a standalone Swift Package with no UI dependency. This is not
tidiness for its own sake — it means the engine is testable without launching
a GUI, and the CLI can ship as a first-class product.

### API contract

```swift
public actor Scanner {
    public init(rules: RuleStore, guard: Guard)
    public func scan(categories: Set<Category>)
        -> AsyncThrowingStream<ScanEvent, Error>
}

public enum ScanEvent: Sendable {
    case started(estimatedRoots: Int)
    case progress(scanned: Int, currentPath: String)
    case found(CleanupItem)
    case finished(ScanResult)
}

public struct CleanupItem: Sendable, Identifiable {
    public let id: UUID
    public let url: URL
    public let allocatedSize: Int64
    public let modifiedAt: Date
    public let category: Category
    public let safety: SafetyLevel
    public let ruleID: String
    public let reason: String
}
```

`ruleID` and `reason` are the trust mechanism. Every candidate can be traced
back to the rule that produced it and explained in plain language. In an open
source tool that runs with Full Disk Access, this is not optional polish.

### Enumeration performance

`getattrlistbulk` is the fast path and can be roughly an order of magnitude
faster than `FileManager.enumerator`. Start with `FileManager.enumerator` and
prefetched resource keys — correctness first — and optimise only if scans
exceed a few seconds.

```swift
let keys: [URLResourceKey] = [
    .totalFileAllocatedSizeKey,
    .contentModificationDateKey,
    .isDirectoryKey,
    .isSymbolicLinkKey,
]
```

---

## Safety model

Four levels. The first three come from `rules.yaml`; the fourth is hardcoded.

| Level | UI behaviour | Examples |
|---|---|---|
| `safe` | Selected by default | Regenerable caches, DerivedData, unused Docker images |
| `review` | Shown, unselected | Large & old files, old iOS backups |
| `expert` | Hidden behind a Settings toggle | Language files, universal binaries |
| *never* | Never surfaced at all | `~/Library/Keychains`, `~/Library/Containers/*/Data`, `/System`, `/private/var/db` |

The never-delete list lives in `NeverDelete.swift`, not in YAML, so a
malformed or malicious rules file cannot widen what the tool will touch. It is
checked against the final resolved URL immediately before the Trash call —
after symlink resolution, not before.

Additional guarantees:

- Deletion always goes to Trash via `FileManager.trashItem`, never `unlink`
- Every operation is written to an undo log before it happens
- User exclusion list, honoured by both scan and clean
- Dry-run is the default; deleting requires an explicit flag

---

## Interface plan

### Screens

1. **Onboarding / FDA permission** — detect status, explain why it's needed,
   deep link to `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`
2. Dashboard — disk summary, scan CTA
3. Scanning — progress, current path, cancel
4. Results — categorised tree, tri-state selection
5. Cleaning — progress
6. Done — reclaimed total, undo button
7. Per-module detail
8. Settings — exclusions, safety level, minimum size

Screen 1 is the most commonly botched and the most important. If permission
handling is confusing, nothing else matters.

### Structure

`NavigationSplitView` with a `.listStyle(.sidebar)` sidebar and a detail pane.
Window uses `.windowStyle(.hiddenTitleBar)` with a unified toolbar. Bottom
action bar via `.safeAreaInset(edge: .bottom)`.

Selection is tri-state (all / partial / none) per category. Model it
explicitly — a `Bool` binding will not survive first contact with a user
unchecking one child item.

### State

```swift
enum ScanState {
    case idle
    case requestingPermission
    case scanning(progress: Double, currentPath: String)
    case results(ScanResult)
    case cleaning(progress: Double)
    case finished(reclaimed: Int64, undoToken: UUID)
    case failed(CleanError)
}
```

One enum, not a set of booleans. `isScanning` + `isCleaning` + `hasResults`
produces impossible combinations and untraceable bugs.

### Design tokens

Defined in `DesignSystem/Tokens.swift` from day one; no raw numbers in views.

- Spacing: 4 / 8 / 12 / 16 / 24 / 32
- Radius: 8 controls, 12 cards, 16 panels
- Type: `.system(_, design: .rounded)` for large numerals
- Material: `.regularMaterial` sidebar, `.thinMaterial` bottom bar
- Motion: `.smooth`, `.snappy`, `.symbolEffect(.variableColor.iterative)`
  while scanning

Targeting macOS 26 means Liquid Glass materials come from the system rather
than being reimplemented.

---

## Milestones

| ID | Deliverable | Estimate |
|---|---|---|
| M0 | CleanKit + CLI, dry-run only, no deletion capability | 1 week |
| M1 | PermissionsManager, onboarding, UI shell | 4 days |
| M2 | Scanner actor, AsyncStream progress, cancellation | 1–2 weeks |
| M3 | Results UI, tri-state selection | 1 week |
| M4 | TrashService, undo log, exclusions | 4 days |
| M5 | Visual polish, animation, iconography | 1 week |
| M6 | Signing, notarization, DMG, Homebrew tap | 2 days |

### M0 in detail

M0 deliberately ships **without a `clean` command**. For the first week the
tool is physically incapable of deleting anything. This creates room to
validate the numbers against reality with zero risk.

Build order within M0:

1. `SafetyLevel.swift`, `Category.swift`, `CleanupItem.swift`
2. `NeverDelete.swift` + `NeverDeleteTests.swift` — before the scanner exists
3. `TestFixture` — temp-directory tree builder for all later tests
4. `FileWalker` + `DatalessFilter`
5. `Rule`, `RuleStore`, initial `rules.yaml` (developer category only)
6. `Scanner` actor emitting `ScanEvent`
7. `DryRunReport` + CLI

CLI surface for M0:

```
cruft scan --category developer --dry-run
cruft scan --all --json > report.json
cruft rules validate
cruft rules explain xcode-derived-data
cruft doctor
```

`cruft doctor` earns its place early: it explains the gap between what `df`
reports and what Finder shows, which is otherwise baffling.

### Initial rule targets

Highest value first, all in the `developer` category:

- `~/Library/Developer/Xcode/DerivedData`
- `~/Library/Developer/Xcode/iOS DeviceSupport`
- Unavailable simulators (`xcrun simctl delete unavailable`)
- Docker unused images and build cache
- Homebrew cache
- npm / pnpm / yarn stores
- pip cache
- `~/.gradle/caches`

---

## Open source considerations

The project runs with Full Disk Access on other people's machines. That raises
the bar on a few things:

- `SECURITY.md` with a disclosure process
- README states plainly what the tool does and does not touch
- Rule contributions require a negative test — proof the rule does not match
  an adjacent dangerous path
- Undo path documented prominently: everything goes to Trash
- No telemetry of any kind

**Name check before publishing:** `cruft` exists as a Python package on PyPI.
That's a different ecosystem and likely fine, but verify GitHub, Homebrew
formula names, and any `.app`/`.dev` domain before committing to it publicly.

---

## Deliberate omissions

Recorded here so they don't get relitigated:

- **Privileged helper (SMAppService + XPC)** for root-level `/Library`
  cleanup. Substantial complexity: a separately signed helper bundle, XPC
  protocol, and install/update lifecycle. User-level cleanup captures the
  large majority of reclaimable space on a developer machine.
- **Mac App Store distribution.** The sandbox blocks the core functionality.
  Direct distribution plus notarization is the only viable route.
- **Anything named with "Mac" in it.** Apple's trademark guidelines prohibit
  incorporating their marks into product names.
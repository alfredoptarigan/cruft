import CleanKit
import Foundation
import Observation

/// One enum for the whole flow — PLAN.md forbids isScanning/hasResults
/// boolean soup. Cases for cleaning arrive with deletion in M4.
enum ScanState: Sendable {
    case idle
    case scanning(scanned: Int, currentPath: String, items: [CleanupItem])
    case results(ScanResult)
    case failed(String)

    var scanningItems: [CleanupItem] {
        if case .scanning(_, _, let items) = self { items } else { [] }
    }
}

/// Pure fold of scan events into UI state; unit-tested in ScanReducerTests.
func reduce(_ state: ScanState, event: ScanEvent) -> ScanState {
    switch event {
    case .started:
        return .scanning(scanned: 0, currentPath: "", items: [])
    case .progress(let scanned, let currentPath):
        return .scanning(scanned: scanned, currentPath: currentPath, items: state.scanningItems)
    case .found(let item):
        guard case .scanning(let scanned, let currentPath, var items) = state else { return state }
        items.append(item)
        return .scanning(scanned: scanned, currentPath: currentPath, items: items)
    case .finished(let result):
        return .results(result)
    }
}

@MainActor
@Observable
final class AppState {
    var state: ScanState = .idle
    var hasFullDiskAccess = FullDiskAccess.probe()
    /// nil scans every category (Smart Scan); sidebar modules narrow it.
    var scanScope: CleanKit.Category?
    var selection = SelectionModel()

    @ObservationIgnored private var scanTask: Task<Void, Never>?

    func startScan() {
        scanTask?.cancel()
        let categories = scanScope.map { Set([$0]) } ?? Set(CleanKit.Category.allCases)
        state = .scanning(scanned: 0, currentPath: "", items: [])
        scanTask = Task {
            do {
                let scanner = CleanKit.Scanner(rules: try RuleStore.bundled())
                let stream = await scanner.scan(categories: categories)
                for try await event in stream {
                    // A cancelled task must not overwrite state cancelScan reset.
                    guard !Task.isCancelled else { return }
                    state = reduce(state, event: event)
                    if case .finished(let result) = event {
                        selection.resetToDefault(for: result)
                    }
                }
            } catch is CancellationError {
                // cancelScan already reset the state.
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(String(describing: error))
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        state = .idle
    }

    func refreshPermission() {
        hasFullDiskAccess = FullDiskAccess.probe()
    }
}

/// Same TCC probe the CLI's `doctor` uses: Safari's directory is unreadable
/// without Full Disk Access.
enum FullDiskAccess {
    static func probe() -> Bool {
        let probe = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari")
        return (try? FileManager.default.contentsOfDirectory(atPath: probe.path)) != nil
    }

    static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
}

enum DiskSpace {
    static func freeIncludingPurgeable() -> Int64? {
        (try? URL(fileURLWithPath: "/").resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage
    }
}

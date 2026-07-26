import CleanKit
import Foundation
import Observation

/// One enum for the whole flow — PLAN.md forbids isScanning/hasResults
/// boolean soup. Cases for cleaning arrive with deletion in M4.
enum ScanState: Sendable {
    case idle
    case scanning(scanned: Int, currentPath: String)
    case results(ScanResult)
    case failed(String)
}

/// Pure fold of scan events into UI state; unit-tested in ScanReducerTests.
func reduce(_ state: ScanState, event: ScanEvent) -> ScanState {
    switch event {
    case .started:
        .scanning(scanned: 0, currentPath: "")
    case .progress(let scanned, let currentPath):
        .scanning(scanned: scanned, currentPath: currentPath)
    case .found:
        // Items are presented from the final ScanResult; live item feed is M3.
        state
    case .finished(let result):
        .results(result)
    }
}

@MainActor
@Observable
final class AppState {
    var state: ScanState = .idle
    var hasFullDiskAccess = FullDiskAccess.probe()

    @ObservationIgnored private var scanTask: Task<Void, Never>?

    func startScan() {
        scanTask?.cancel()
        state = .scanning(scanned: 0, currentPath: "")
        scanTask = Task {
            do {
                let scanner = CleanKit.Scanner(rules: try RuleStore.bundled())
                let stream = await scanner.scan(categories: Set(CleanKit.Category.allCases))
                for try await event in stream {
                    // A cancelled task must not overwrite state cancelScan reset.
                    guard !Task.isCancelled else { return }
                    state = reduce(state, event: event)
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

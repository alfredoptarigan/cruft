import CleanKit
import Foundation
import Testing
@testable import CruftApp

@Suite struct ScanReducerTests {
    @Test func foldsEventStreamIntoStates() {
        var state = ScanState.idle

        state = reduce(state, event: .started(estimatedRoots: 9))
        guard case .scanning(0, "") = state else {
            Issue.record("started should enter scanning with zeroed counters")
            return
        }

        state = reduce(state, event: .progress(scanned: 3, currentPath: "/x/y"))
        guard case .scanning(3, "/x/y") = state else {
            Issue.record("progress should update counters")
            return
        }

        let item = CleanupItem(
            url: URL(fileURLWithPath: "/synthetic/a"),
            allocatedSize: 10,
            modifiedAt: .distantPast,
            category: .developer,
            safety: .safe,
            ruleID: "r",
            reason: "why")
        state = reduce(state, event: .found(item))
        guard case .scanning = state else {
            Issue.record("found must not change phase")
            return
        }

        state = reduce(state, event: .finished(ScanResult(items: [item])))
        guard case .results(let result) = state, result.totalSize == 10 else {
            Issue.record("finished should carry the result")
            return
        }
    }
}

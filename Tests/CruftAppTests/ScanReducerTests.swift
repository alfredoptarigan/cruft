import CleanKit
import Foundation
import Testing
@testable import CruftApp

@Suite struct ScanReducerTests {
    @Test func foldsEventStreamIntoStates() {
        var state = ScanState.idle

        state = reduce(state, event: .started(estimatedRoots: 9))
        guard case .scanning(0, "", let empty) = state, empty.isEmpty else {
            Issue.record("started should enter scanning with zeroed counters and no items")
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
        guard case .scanning(_, _, let found) = state, found.map(\.id) == [item.id] else {
            Issue.record("found should append the item to the live feed")
            return
        }

        state = reduce(state, event: .progress(scanned: 3, currentPath: "/x/y"))
        guard case .scanning(3, "/x/y", let kept) = state, kept.count == 1 else {
            Issue.record("progress should update counters and keep live items")
            return
        }

        state = reduce(state, event: .finished(ScanResult(items: [item])))
        guard case .results(let result) = state, result.totalSize == 10 else {
            Issue.record("finished should carry the result")
            return
        }
    }
}

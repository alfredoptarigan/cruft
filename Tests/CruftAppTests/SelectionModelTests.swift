import CleanKit
import Foundation
import Testing
@testable import CruftApp

@Suite struct SelectionModelTests {
    private func item(_ name: String, safety: SafetyLevel, size: Int64 = 100) -> CleanupItem {
        CleanupItem(
            url: URL(fileURLWithPath: "/synthetic/\(name)"),
            allocatedSize: size,
            modifiedAt: .distantPast,
            category: .developer,
            safety: safety,
            ruleID: "rule-\(name)",
            reason: "test")
    }

    @Test func defaultSelectsOnlySafeItems() {
        let safe = item("safe", safety: .safe)
        let review = item("review", safety: .review)
        let expert = item("expert", safety: .expert)
        let result = ScanResult(items: [safe, review, expert])

        let selected = SelectionModel.defaultSelection(for: result)
        #expect(selected == [safe.id])
    }

    @Test func triStateIsDerivedFromSet() {
        let a = item("a", safety: .safe)
        let b = item("b", safety: .safe)
        var model = SelectionModel()

        #expect(model.triState(for: [a, b]) == .none)
        model.toggle(a)
        #expect(model.triState(for: [a, b]) == .some)
        model.toggle(b)
        #expect(model.triState(for: [a, b]) == .all)
    }

    @Test func groupToggleCyclesAllToNone() {
        let a = item("a", safety: .safe)
        let b = item("b", safety: .review)
        var model = SelectionModel()

        model.toggle(a)  // partial
        model.toggleGroup([a, b])
        #expect(model.triState(for: [a, b]) == .all, "partial -> all")
        model.toggleGroup([a, b])
        #expect(model.triState(for: [a, b]) == .none, "all -> none")
    }

    @Test func untogglingOneItemMakesGroupPartial() {
        let a = item("a", safety: .safe, size: 30)
        let b = item("b", safety: .safe, size: 70)
        var model = SelectionModel()
        model.resetToDefault(for: ScanResult(items: [a, b]))

        #expect(model.triState(for: [a, b]) == .all)
        model.toggle(b)
        #expect(model.triState(for: [a, b]) == .some)
        #expect(model.selectedCount(in: [a, b]) == 1)
        #expect(model.selectedSize(in: [a, b]) == 30)
    }
}

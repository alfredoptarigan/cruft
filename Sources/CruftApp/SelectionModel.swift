import CleanKit
import Foundation

enum TriState {
    case none, some, all
}

/// Single source of truth for what is checked: a Set of item IDs. Group
/// checkbox state is always derived, never stored — PLAN.md's warning about
/// Bool bindings not surviving a child untick.
struct SelectionModel {
    private(set) var selected: Set<UUID> = []

    /// PLAN safety table: safe pre-selected, review shown unchecked,
    /// expert hidden entirely (and therefore never selected).
    static func defaultSelection(for result: ScanResult) -> Set<UUID> {
        Set(result.items.filter { $0.safety == .safe }.map(\.id))
    }

    mutating func resetToDefault(for result: ScanResult) {
        selected = Self.defaultSelection(for: result)
    }

    func isSelected(_ item: CleanupItem) -> Bool {
        selected.contains(item.id)
    }

    func triState(for items: [CleanupItem]) -> TriState {
        let count = items.filter { selected.contains($0.id) }.count
        if count == 0 { return .none }
        return count == items.count ? .all : .some
    }

    mutating func toggle(_ item: CleanupItem) {
        if !selected.insert(item.id).inserted {
            selected.remove(item.id)
        }
    }

    /// all -> none; some/none -> all.
    mutating func toggleGroup(_ items: [CleanupItem]) {
        if triState(for: items) == .all {
            for item in items { selected.remove(item.id) }
        } else {
            for item in items { selected.insert(item.id) }
        }
    }

    func selectedCount(in items: [CleanupItem]) -> Int {
        items.filter { selected.contains($0.id) }.count
    }

    func selectedSize(in items: [CleanupItem]) -> Int64 {
        items.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.allocatedSize }
    }
}

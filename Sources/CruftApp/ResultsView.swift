import CleanKit
import SwiftUI

/// Results grouped by rule. Live during a scan (no checkboxes yet); tri-state
/// selectable once finished. Deletion is M4 — the bar shows totals only.
struct ResultsView: View {
    @Environment(AppState.self) private var app
    let items: [CleanupItem]
    var live = false
    var rescan: () -> Void = {}

    private struct RuleGroup: Identifiable {
        let ruleID: String
        let reason: String
        let safety: SafetyLevel
        let items: [CleanupItem]
        var subtotal: Int64 { items.reduce(0) { $0 + $1.allocatedSize } }
        var id: String { ruleID }
    }

    /// PLAN safety table: expert-level items are hidden entirely for now.
    private var visible: [CleanupItem] {
        items.filter { $0.safety != .expert }
    }

    private var groups: [RuleGroup] {
        Dictionary(grouping: visible, by: \.ruleID)
            .map { ruleID, items in
                RuleGroup(
                    ruleID: ruleID,
                    reason: items[0].reason,
                    safety: items[0].safety,
                    items: items.sorted { $0.allocatedSize > $1.allocatedSize })
            }
            .sorted { $0.subtotal > $1.subtotal }
    }

    private var total: Int64 { visible.reduce(0) { $0 + $1.allocatedSize } }

    var body: some View {
        SwiftUI.Group {
            if visible.isEmpty && !live {
                ContentUnavailableView(
                    "No junk found",
                    systemImage: "checkmark.seal",
                    description: Text("Nothing matched the current rules."))
            } else {
                List {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.items) { item in
                                row(item)
                            }
                        } header: {
                            header(group)
                        } footer: {
                            Text(group.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    private func row(_ item: CleanupItem) -> some View {
        HStack {
            if !live {
                checkbox(isOn: app.selection.isSelected(item), mixed: false) {
                    app.selection.toggle(item)
                }
            }
            Text(item.url.path)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(item.url.path)
            Spacer()
            Text(DryRunReport.format(item.allocatedSize))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func header(_ group: RuleGroup) -> some View {
        HStack {
            if !live {
                let tri = app.selection.triState(for: group.items)
                checkbox(isOn: tri == .all, mixed: tri == .some) {
                    app.selection.toggleGroup(group.items)
                }
            }
            Text(group.ruleID)
            Text(group.safety.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
            Spacer()
            Text(DryRunReport.format(group.subtotal))
        }
    }

    private func checkbox(isOn: Bool, mixed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: mixed ? "minus.square.fill" : isOn ? "checkmark.square.fill" : "square")
                .foregroundStyle(isOn || mixed ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityValue(mixed ? "mixed" : isOn ? "checked" : "unchecked")
    }

    private var bottomBar: some View {
        HStack {
            if live {
                Text("Found \(DryRunReport.format(total)) so far…")
                    .font(.headline)
                Spacer()
            } else {
                Text(
                    "Selected \(app.selection.selectedCount(in: visible)) items — \(DryRunReport.format(app.selection.selectedSize(in: visible))) of \(DryRunReport.format(total))"
                )
                .font(.headline)
                Spacer()
                Text("Dry run — nothing was deleted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Rescan") { rescan() }
            }
        }
        .padding(12)
        .background(.thinMaterial)
    }
}

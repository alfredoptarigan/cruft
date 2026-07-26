import CleanKit
import SwiftUI

/// Read-only results grouped by rule. Tri-state selection is M3; deletion M4.
struct ResultsView: View {
    let result: ScanResult
    let rescan: () -> Void

    private struct Group: Identifiable {
        let ruleID: String
        let reason: String
        let safety: SafetyLevel
        let items: [CleanupItem]
        var subtotal: Int64 { items.reduce(0) { $0 + $1.allocatedSize } }
        var id: String { ruleID }
    }

    private var groups: [Group] {
        Dictionary(grouping: result.items, by: \.ruleID)
            .map { ruleID, items in
                Group(
                    ruleID: ruleID,
                    reason: items[0].reason,
                    safety: items[0].safety,
                    items: items.sorted { $0.allocatedSize > $1.allocatedSize })
            }
            .sorted { $0.subtotal > $1.subtotal }
    }

    var body: some View {
        VStack(spacing: 0) {
            if result.items.isEmpty {
                ContentUnavailableView(
                    "No junk found",
                    systemImage: "checkmark.seal",
                    description: Text("Nothing matched the current rules."))
            } else {
                List {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.items) { item in
                                HStack {
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
                        } header: {
                            HStack {
                                Text(group.ruleID)
                                Text(group.safety.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(.quaternary, in: Capsule())
                                Spacer()
                                Text(DryRunReport.format(group.subtotal))
                            }
                        } footer: {
                            Text(group.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Text("Total reclaimable: \(DryRunReport.format(result.totalSize))")
                    .font(.headline)
                Spacer()
                Text("Dry run — nothing was deleted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Rescan") { rescan() }
            }
            .padding(12)
            .background(.thinMaterial)
        }
    }
}

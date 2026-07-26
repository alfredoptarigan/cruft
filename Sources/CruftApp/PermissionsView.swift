import SwiftUI

/// PLAN.md screen 1: explain why Full Disk Access is needed, deep-link to
/// System Settings, allow re-checking without restarting the app.
struct PermissionsBanner: View {
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Full Disk Access not granted")
                    .font(.headline)
                Text("Without it, scans miss most of ~/Library. Cruft reads metadata only, and this build cannot delete anything.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") { openURL(FullDiskAccess.settingsURL) }
            Button("Re-check") { app.refreshPermission() }
        }
        .padding(12)
        .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}

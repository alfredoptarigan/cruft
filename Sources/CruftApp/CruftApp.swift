import CleanKit
import SwiftUI

@main
struct CruftApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 620)
    }
}

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Label("Smart Scan", systemImage: "sparkles")
                Section("Modules") {
                    ForEach(CleanKit.Category.allCases, id: \.self) { category in
                        Label(category.label, systemImage: category.icon)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Cruft")
        } detail: {
            DashboardView()
        }
    }
}

extension CleanKit.Category {
    var label: String {
        switch self {
        case .developer: "Developer junk"
        case .system: "System junk"
        case .largeFiles: "Large & old files"
        }
    }

    var icon: String {
        switch self {
        case .developer: "hammer"
        case .system: "gearshape.2"
        case .largeFiles: "externaldrive"
        }
    }
}

struct DashboardView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 16) {
            if !app.hasFullDiskAccess {
                PermissionsBanner()
            }
            switch app.state {
            case .idle:
                idle
            case .scanning(let scanned, let currentPath):
                scanning(scanned: scanned, currentPath: currentPath)
            case .results(let result):
                ResultsView(result: result) { app.startScan() }
            case .failed(let message):
                failed(message)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idle: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "internaldrive")
                .font(.system(size: 56, design: .rounded))
                .foregroundStyle(.secondary)
            if let free = DiskSpace.freeIncludingPurgeable() {
                Text("\(DryRunReport.format(free)) free (including purgeable)")
                    .foregroundStyle(.secondary)
            }
            Button("Scan for junk") { app.startScan() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Text("Dry run only — this build cannot delete anything.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func scanning(scanned: Int, currentPath: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "rays")
                .font(.largeTitle)
                .symbolEffect(.variableColor.iterative)
            Text("Scanned \(scanned) candidates…")
            Text(currentPath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 480)
            Button("Cancel") { app.cancelScan() }
            Spacer()
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text("Scan failed").font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
            Button("Try again") { app.startScan() }
            Spacer()
        }
    }
}

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

enum SidebarItem: Hashable {
    case smartScan
    case module(CleanKit.Category)
}

struct ContentView: View {
    @Environment(AppState.self) private var app
    @State private var sidebarSelection: SidebarItem? = .smartScan

    var body: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                Label("Smart Scan", systemImage: "sparkles")
                    .tag(SidebarItem.smartScan)
                Section("Modules") {
                    ForEach(CleanKit.Category.allCases, id: \.self) { category in
                        Label(category.label, systemImage: category.icon)
                            .tag(SidebarItem.module(category))
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Cruft")
        } detail: {
            DashboardView()
        }
        .onChange(of: sidebarSelection) { _, selection in
            app.scanScope = if case .module(let category) = selection { category } else { nil }
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
            case .scanning(let scanned, let currentPath, let items):
                scanHeader(scanned: scanned, currentPath: currentPath)
                ResultsView(items: items, live: true)
            case .results(let result):
                ResultsView(items: result.items) { app.startScan() }
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
            Button(app.scanScope.map { "Scan \($0.label)" } ?? "Scan for junk") {
                app.startScan()
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Text("Dry run only — this build cannot delete anything.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func scanHeader(scanned: Int, currentPath: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "rays")
                .symbolEffect(.variableColor.iterative)
            Text("Scanned \(scanned)…")
                .monospacedDigit()
            Text(currentPath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("Cancel") { app.cancelScan() }
        }
        .padding(.horizontal, 4)
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

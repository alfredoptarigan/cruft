import ArgumentParser
import CleanKit
import Foundation

@main
struct Cruft: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cruft",
        abstract: "Finds regenerable caches and developer junk. This build is dry-run only: it cannot delete anything.",
        subcommands: [Scan.self, Rules.self, Doctor.self]
    )
}

// MARK: - scan

struct Scan: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Scan for cleanup candidates (always a dry run in this build).")

    @Option(
        name: .customLong("category"),
        help: "Category to scan (\(CleanKit.Category.allCases.map(\.rawValue).joined(separator: ", "))). Repeatable.")
    var categories: [String] = []

    @Flag(help: "Scan all categories.")
    var all = false

    @Flag(help: "Output the report as JSON.")
    var json = false

    @Flag(
        name: .customLong("dry-run"),
        help: "Accepted for forward compatibility; this build is always a dry run.")
    var dryRun = false

    func run() async throws {
        let selected: Set<CleanKit.Category>
        if all || categories.isEmpty {
            selected = Set(CleanKit.Category.allCases)
        } else {
            selected = Set(
                try categories.map {
                    guard let category = CleanKit.Category(rawValue: $0) else {
                        throw ValidationError("Unknown category '\($0)'.")
                    }
                    return category
                })
        }

        let scanner = CleanKit.Scanner(rules: try RuleStore.bundled())
        var finished: ScanResult?
        for try await event in await scanner.scan(categories: selected) {
            switch event {
            case .started(let roots):
                if !json {
                    FileHandle.standardError.write(Data("Scanning \(roots) rule roots…\n".utf8))
                }
            case .progress, .found:
                break
            case .finished(let result):
                finished = result
            }
        }
        guard let result = finished else {
            throw ValidationError("Scan produced no result.")
        }
        let report = DryRunReport(result: result)
        print(json ? try report.json() : report.text())
    }
}

// MARK: - rules

struct Rules: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Inspect the bundled cleanup rules.",
        subcommands: [Validate.self, Explain.self])

    struct Validate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Validate the bundled rules file.")

        func run() throws {
            let store = try RuleStore.bundled()
            print("OK — \(store.rules.count) rules valid.")
        }
    }

    struct Explain: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show what a rule matches and why it is considered safe.")

        @Argument(help: "Rule id, e.g. xcode-derived-data.")
        var id: String

        func run() throws {
            guard let rule = try RuleStore.bundled().rule(id: id) else {
                throw ValidationError("No rule with id '\(id)'.")
            }
            print(
                """
                id:        \(rule.id)
                path:      \(rule.path)
                category:  \(rule.category.rawValue)
                safety:    \(rule.safety.rawValue)
                min age:   \(rule.minAgeDays.map { "\($0) days" } ?? "none")
                reason:    \(rule.reason)
                """)
        }
    }
}

// MARK: - doctor

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Diagnose permissions and explain disk-space discrepancies.")

    func run() throws {
        // TCC probe: Safari's directory is unreadable without Full Disk Access.
        let probe = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari")
        let hasFullDiskAccess =
            (try? FileManager.default.contentsOfDirectory(atPath: probe.path)) != nil
        if hasFullDiskAccess {
            print("Full Disk Access: granted")
        } else {
            print(
                """
                Full Disk Access: NOT granted
                  Scans will miss most of ~/Library. Grant it to your terminal in
                  System Settings > Privacy & Security > Full Disk Access.
                """)
        }

        let snapshots = Self.localSnapshotCount()
        print("Time Machine local snapshots: \(snapshots)")
        if snapshots > 0 {
            print("  Freed space may not show up in `df` until snapshots thin out.")
        }

        if let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [
            .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]) {
            let strict = Int64(values.volumeAvailableCapacity ?? 0)
            let withPurgeable = values.volumeAvailableCapacityForImportantUsage ?? 0
            print("Free space (df-style): \(DryRunReport.format(strict))")
            print("Free space (Finder-style, incl. purgeable): \(DryRunReport.format(withPurgeable))")
        }
    }

    static func localSnapshotCount() -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["listlocalsnapshots", "/"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return 0
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .filter { $0.contains("com.apple.TimeMachine") }
            .count
    }
}

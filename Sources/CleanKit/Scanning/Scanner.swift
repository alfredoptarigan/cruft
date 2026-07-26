import Foundation

private let secondsPerDay: TimeInterval = 86_400

public actor Scanner {
    private let rules: RuleStore

    public init(rules: RuleStore) {
        self.rules = rules
    }

    /// Streams scan progress. Scanning never mutates anything; cancellation
    /// is honoured between candidates.
    public func scan(
        categories: Set<Category>,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> AsyncThrowingStream<ScanEvent, Error> {
        let matching = rules.rules(in: categories)
        return AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                do {
                    try Self.run(rules: matching, home: home, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func run(
        rules: [Rule],
        home: URL,
        continuation: AsyncThrowingStream<ScanEvent, Error>.Continuation
    ) throws {
        continuation.yield(.started(estimatedRoots: rules.count))
        var scanned = 0
        var items: [CleanupItem] = []
        let now = Date()
        for rule in rules {
            for candidate in FileWalker.expand(pattern: rule.path, home: home) {
                try Task.checkCancellation()
                scanned += 1
                continuation.yield(.progress(scanned: scanned, currentPath: candidate.path))
                // Never-level paths are never surfaced at all — the same list
                // also guards the (future) deletion pipeline as its last gate.
                if NeverDelete.contains(candidate, home: home) { continue }
                if DatalessFilter.isDataless(candidate) { continue }
                let modified = FileWalker.modificationDate(of: candidate)
                if let minAge = rule.minAgeDays,
                    modified > now.addingTimeInterval(-TimeInterval(minAge) * secondsPerDay) {
                    continue
                }
                let item = CleanupItem(
                    url: candidate,
                    allocatedSize: FileWalker.allocatedSize(of: candidate),
                    modifiedAt: modified,
                    category: rule.category,
                    safety: rule.safety,
                    ruleID: rule.id,
                    reason: rule.reason)
                items.append(item)
                continuation.yield(.found(item))
            }
        }
        continuation.yield(.finished(ScanResult(items: items)))
    }
}

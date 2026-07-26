import Foundation

public struct DryRunReport: Sendable {
    public let result: ScanResult

    public init(result: ScanResult) {
        self.result = result
    }

    public func text() -> String {
        guard !result.items.isEmpty else {
            return "Nothing to clean up (dry run)."
        }
        var lines: [String] = []
        let groups = Dictionary(grouping: result.items, by: \.ruleID)
            .sorted { $0.key < $1.key }
        for (ruleID, items) in groups {
            let subtotal = items.reduce(0) { $0 + $1.allocatedSize }
            lines.append("\(ruleID) — \(Self.format(subtotal)) [\(items[0].safety.rawValue)]")
            lines.append("  \(items[0].reason)")
            for item in items.sorted(by: { $0.allocatedSize > $1.allocatedSize }) {
                lines.append("  \(Self.format(item.allocatedSize))  \(item.url.path)")
            }
            lines.append("")
        }
        lines.append("Total reclaimable: \(Self.format(result.totalSize)) — dry run, nothing was deleted.")
        return lines.joined(separator: "\n")
    }

    public func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(result), as: UTF8.self)
    }

    public static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

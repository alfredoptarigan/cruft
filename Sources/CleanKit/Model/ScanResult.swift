import Foundation

public struct ScanResult: Sendable, Codable {
    public let items: [CleanupItem]
    public let totalSize: Int64
    public let scannedAt: Date

    public init(items: [CleanupItem], scannedAt: Date = Date()) {
        self.items = items
        self.totalSize = items.reduce(0) { $0 + $1.allocatedSize }
        self.scannedAt = scannedAt
    }
}

import Foundation

/// One cleanup candidate. `ruleID` and `reason` are the trust mechanism:
/// every item traces back to the rule that produced it.
public struct CleanupItem: Sendable, Identifiable, Codable {
    public let id: UUID
    public let url: URL
    /// Allocated (on-disk) size — never logical size; APFS clones and sparse
    /// files make logical size wrong.
    public let allocatedSize: Int64
    public let modifiedAt: Date
    public let category: Category
    public let safety: SafetyLevel
    public let ruleID: String
    public let reason: String

    public init(
        url: URL,
        allocatedSize: Int64,
        modifiedAt: Date,
        category: Category,
        safety: SafetyLevel,
        ruleID: String,
        reason: String
    ) {
        self.id = UUID()
        self.url = url
        self.allocatedSize = allocatedSize
        self.modifiedAt = modifiedAt
        self.category = category
        self.safety = safety
        self.ruleID = ruleID
        self.reason = reason
    }
}

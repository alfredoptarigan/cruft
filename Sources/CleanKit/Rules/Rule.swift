/// One entry from rules.yaml. Adding a cleanup target means adding YAML plus
/// its positive/negative match tests — never touching the scanner.
public struct Rule: Sendable, Codable, Identifiable {
    public let id: String
    public let path: String
    public let category: Category
    public let safety: SafetyLevel
    public let minAgeDays: Int?
    public let reason: String

    enum CodingKeys: String, CodingKey {
        case id, path, category, safety, reason
        case minAgeDays = "min_age_days"
    }

    public init(
        id: String,
        path: String,
        category: Category,
        safety: SafetyLevel,
        minAgeDays: Int? = nil,
        reason: String
    ) {
        self.id = id
        self.path = path
        self.category = category
        self.safety = safety
        self.minAgeDays = minAgeDays
        self.reason = reason
    }
}

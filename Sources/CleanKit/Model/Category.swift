/// Scan module a rule belongs to.
public enum Category: String, Sendable, Codable, CaseIterable {
    case developer
    case system
    case largeFiles = "large-files"
}

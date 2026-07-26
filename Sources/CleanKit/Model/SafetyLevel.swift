/// Rule-assigned safety of a cleanup candidate. There is deliberately no
/// `never` case — the never-delete list is hardcoded in `NeverDelete.swift`
/// so a malformed rules file cannot widen the blast radius.
public enum SafetyLevel: String, Sendable, Codable, CaseIterable {
    /// Selected by default: regenerable caches and build artifacts.
    case safe
    /// Shown, unselected: needs a human look (large & old files, backups).
    case review
    /// Hidden behind a settings toggle.
    case expert
}

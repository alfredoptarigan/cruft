import Foundation
import Yams

public struct RuleStore: Sendable {
    public let rules: [Rule]

    public init(yaml: String) throws {
        let decoded = try YAMLDecoder().decode([Rule].self, from: yaml)
        try Self.validate(decoded)
        rules = decoded
    }

    public static func bundled() throws -> RuleStore {
        guard let url = Bundle.module.url(forResource: "rules", withExtension: "yaml") else {
            throw RuleError.missingBundledRules
        }
        return try RuleStore(yaml: String(contentsOf: url, encoding: .utf8))
    }

    public func rule(id: String) -> Rule? {
        rules.first { $0.id == id }
    }

    public func rules(in categories: Set<Category>) -> [Rule] {
        rules.filter { categories.contains($0.category) }
    }

    private static func validate(_ rules: [Rule]) throws {
        var ids = Set<String>()
        for rule in rules {
            guard ids.insert(rule.id).inserted else {
                throw RuleError.duplicateID(rule.id)
            }
            guard rule.path.hasPrefix("~/") || rule.path.hasPrefix("/") else {
                throw RuleError.invalidPath(rule.id)
            }
            guard !rule.path.contains("..") else {
                throw RuleError.invalidPath(rule.id)
            }
            guard !rule.reason.isEmpty else {
                throw RuleError.missingReason(rule.id)
            }
            if let age = rule.minAgeDays, age < 0 {
                throw RuleError.invalidAge(rule.id)
            }
        }
    }
}

public enum RuleError: Error, Sendable, CustomStringConvertible {
    case missingBundledRules
    case duplicateID(String)
    case invalidPath(String)
    case missingReason(String)
    case invalidAge(String)

    public var description: String {
        switch self {
        case .missingBundledRules:
            "bundled rules.yaml is missing from CleanKit resources"
        case .duplicateID(let id):
            "duplicate rule id '\(id)'"
        case .invalidPath(let id):
            "rule '\(id)': path must start with ~/ or / and contain no '..'"
        case .missingReason(let id):
            "rule '\(id)': reason is required"
        case .invalidAge(let id):
            "rule '\(id)': min_age_days must be >= 0"
        }
    }
}

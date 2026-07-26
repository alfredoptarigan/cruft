import Foundation
import Testing
@testable import CleanKit

@Suite struct RuleStoreTests {
    @Test func bundledRulesLoadAndValidate() throws {
        let store = try RuleStore.bundled()
        #expect(store.rules.count == 9)
        #expect(store.rule(id: "xcode-derived-data") != nil)
        #expect(store.rule(id: "no-such-rule") == nil)
        #expect(store.rules(in: [.developer]).count == store.rules.count)
        #expect(store.rules(in: [.system]).isEmpty)
    }

    @Test func duplicateIDThrows() {
        let yaml = """
            - {id: a, path: ~/x, category: developer, safety: safe, reason: r}
            - {id: a, path: ~/y, category: developer, safety: safe, reason: r}
            """
        #expect(throws: RuleError.self) { try RuleStore(yaml: yaml) }
    }

    @Test func relativePathThrows() {
        let yaml = "- {id: a, path: x/y, category: developer, safety: safe, reason: r}"
        #expect(throws: RuleError.self) { try RuleStore(yaml: yaml) }
    }

    @Test func parentTraversalThrows() {
        let yaml = "- {id: a, path: ~/x/../y, category: developer, safety: safe, reason: r}"
        #expect(throws: RuleError.self) { try RuleStore(yaml: yaml) }
    }

    @Test func emptyReasonThrows() {
        let yaml = "- {id: a, path: ~/x, category: developer, safety: safe, reason: \"\"}"
        #expect(throws: RuleError.self) { try RuleStore(yaml: yaml) }
    }

    @Test func negativeAgeThrows() {
        let yaml = "- {id: a, path: ~/x, category: developer, safety: safe, min_age_days: -1, reason: r}"
        #expect(throws: RuleError.self) { try RuleStore(yaml: yaml) }
    }

    @Test func unknownSafetyFailsToDecode() {
        // There is no 'never' safety level in YAML by design.
        let yaml = "- {id: a, path: ~/x, category: developer, safety: never, reason: r}"
        #expect(throws: (any Error).self) { try RuleStore(yaml: yaml) }
    }
}

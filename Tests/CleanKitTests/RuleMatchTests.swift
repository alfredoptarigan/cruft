import Foundation
import Testing
@testable import CleanKit

/// CLAUDE.md rule 5: every rule needs a positive match test and a negative
/// test against a neighbouring dangerous path.
@Suite struct RuleMatchTests {
    struct MatchCase: Sendable, CustomTestStringConvertible {
        let ruleID: String
        let positive: String
        let negative: String

        var testDescription: String { ruleID }
    }

    static let cases: [MatchCase] = [
        .init(
            ruleID: "xcode-derived-data",
            positive: "Library/Developer/Xcode/DerivedData/MyApp-gdxqzabc",
            negative: "Library/Developer/Xcode/Archives/MyApp 2026-07-01.xcarchive"),
        .init(
            ruleID: "xcode-ios-device-support",
            positive: "Library/Developer/Xcode/iOS DeviceSupport/iPhone15,2 17.5 (21F79)",
            negative: "Library/Developer/Xcode/UserData/KeyBindings"),
        .init(
            ruleID: "simulator-caches",
            positive: "Library/Developer/CoreSimulator/Caches/dyld",
            negative: "Library/Developer/CoreSimulator/Devices/AAAA-BBBB"),
        .init(
            ruleID: "homebrew-cache",
            positive: "Library/Caches/Homebrew/wget--1.24.tar.gz",
            negative: "Library/Caches/CloudKit/records"),
        .init(
            ruleID: "npm-cache",
            positive: ".npm/_cacache",
            negative: ".npm/_logs"),
        .init(
            ruleID: "pnpm-store",
            positive: "Library/pnpm/store",
            negative: "Library/pnpm/global"),
        .init(
            ruleID: "yarn-cache",
            positive: "Library/Caches/Yarn",
            negative: "Library/Caches/Firefox"),
        .init(
            ruleID: "pip-cache",
            positive: "Library/Caches/pip",
            negative: "Library/Caches/pip-tools"),
        .init(
            ruleID: "gradle-caches",
            positive: ".gradle/caches",
            negative: ".gradle/gradle.properties"),
    ]

    @Test func everyBundledRuleHasAMatchCase() throws {
        let covered = Set(Self.cases.map(\.ruleID))
        let bundled = Set(try RuleStore.bundled().rules.map(\.id))
        #expect(covered == bundled)
    }

    @Test(arguments: cases)
    func ruleMatchesIntendedPathAndNotNeighbour(_ matchCase: MatchCase) throws {
        let fixture = try TestFixture()
        let store = try RuleStore.bundled()
        let rule = try #require(store.rule(id: matchCase.ruleID))

        try fixture.dir(matchCase.positive)
        try fixture.dir(matchCase.negative)

        let matches = FileWalker.expand(pattern: rule.path, home: fixture.root).map(\.path)
        #expect(matches.contains(fixture.url(matchCase.positive).path))
        #expect(!matches.contains(fixture.url(matchCase.negative).path))
    }
}

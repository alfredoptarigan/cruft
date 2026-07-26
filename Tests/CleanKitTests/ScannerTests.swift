import Foundation
import Testing
@testable import CleanKit

@Suite struct ScannerTests {
    @Test func scanFindsOldDerivedDataOnly() async throws {
        let fixture = try TestFixture()
        try fixture.file("Library/Developer/Xcode/DerivedData/OldApp-abc/app.o", bytes: 8192)
        try fixture.setModified(
            "Library/Developer/Xcode/DerivedData/OldApp-abc",
            Date(timeIntervalSinceNow: -30 * 86_400))
        // NewApp keeps its just-created mtime and must be filtered by min_age_days: 7.
        try fixture.file("Library/Developer/Xcode/DerivedData/NewApp-def/app.o", bytes: 8192)

        let scanner = CleanKit.Scanner(rules: try RuleStore.bundled())
        var events: [ScanEvent] = []
        for try await event in await scanner.scan(categories: [.developer], home: fixture.root) {
            events.append(event)
        }

        guard case .started(let roots) = events.first else {
            Issue.record("first event was not .started")
            return
        }
        #expect(roots == 9)
        guard case .finished(let result) = events.last else {
            Issue.record("last event was not .finished")
            return
        }
        #expect(result.items.count == 1)
        let item = try #require(result.items.first)
        #expect(item.ruleID == "xcode-derived-data")
        #expect(item.url.lastPathComponent == "OldApp-abc")
        #expect(item.allocatedSize >= 8192)
        #expect(item.safety == .safe)
        #expect(result.totalSize == result.items.reduce(0) { $0 + $1.allocatedSize })
    }

    @Test func scannerNeverSurfacesNeverDeletePaths() async throws {
        let fixture = try TestFixture()
        try fixture.file("Library/Keychains/login.keychain-db")
        // A malicious or broken rule pointing straight at Keychains.
        let yaml = "- {id: evil, path: ~/Library/Keychains, category: developer, safety: safe, reason: nope}"

        let scanner = CleanKit.Scanner(rules: try RuleStore(yaml: yaml))
        var found = 0
        for try await event in await scanner.scan(categories: [.developer], home: fixture.root) {
            if case .found = event { found += 1 }
        }
        #expect(found == 0)
    }
}

@Suite struct DryRunReportTests {
    private func sampleResult() -> ScanResult {
        let item = CleanupItem(
            url: URL(fileURLWithPath: "/synthetic/DerivedData/App-abc"),
            allocatedSize: 42,
            modifiedAt: Date(timeIntervalSince1970: 0),
            category: .developer,
            safety: .safe,
            ruleID: "xcode-derived-data",
            reason: "Build artifacts")
        return ScanResult(items: [item], scannedAt: Date(timeIntervalSince1970: 86_400))
    }

    @Test func jsonRoundTrips() throws {
        let json = try DryRunReport(result: sampleResult()).json()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScanResult.self, from: Data(json.utf8))
        #expect(decoded.totalSize == 42)
        #expect(decoded.items.first?.ruleID == "xcode-derived-data")
    }

    @Test func textReportStatesDryRunAndTotals() {
        let text = DryRunReport(result: sampleResult()).text()
        #expect(text.contains("xcode-derived-data"))
        #expect(text.contains("dry run"))
        #expect(text.contains("/synthetic/DerivedData/App-abc"))
    }

    @Test func emptyResultReportsNothingToClean() {
        let text = DryRunReport(result: ScanResult(items: [])).text()
        #expect(text.contains("Nothing to clean up"))
    }
}

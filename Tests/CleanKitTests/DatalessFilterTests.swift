import Foundation
import Testing
@testable import CleanKit

@Suite struct DatalessFilterTests {
    @Test func flagMathDetectsDatalessBit() {
        #expect(DatalessFilter.isDataless(flags: 0x4000_0000))
        #expect(DatalessFilter.isDataless(flags: 0x4000_0020))
        #expect(!DatalessFilter.isDataless(flags: 0))
        #expect(!DatalessFilter.isDataless(flags: 0x0000_0020))
    }

    @Test func regularFileIsNotDataless() throws {
        let fixture = try TestFixture()
        let file = try fixture.file("plain.bin")
        #expect(!DatalessFilter.isDataless(file))
    }

    @Test func missingFileIsNotDataless() throws {
        let fixture = try TestFixture()
        #expect(!DatalessFilter.isDataless(fixture.url("does-not-exist")))
    }
}

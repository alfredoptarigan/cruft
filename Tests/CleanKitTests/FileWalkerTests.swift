import Foundation
import Testing
@testable import CleanKit

@Suite struct FileWalkerTests {
    let fixture: TestFixture

    init() throws {
        fixture = try TestFixture()
    }

    @Test func trailingGlobExpandsChildrenOnly() throws {
        try fixture.dir("Library/Developer/Xcode/DerivedData/AppA-abc")
        try fixture.dir("Library/Developer/Xcode/DerivedData/AppB-def")
        try fixture.dir("Library/Developer/Xcode/Archives/2026-07-01")
        let names = FileWalker
            .expand(pattern: "~/Library/Developer/Xcode/DerivedData/*", home: fixture.root)
            .map(\.lastPathComponent)
        #expect(names == ["AppA-abc", "AppB-def"])
    }

    @Test func literalPathExpandsToItselfOnlyWhenPresent() throws {
        try fixture.dir(".gradle/caches")
        let paths = FileWalker
            .expand(pattern: "~/.gradle/caches", home: fixture.root)
            .map(\.path)
        #expect(paths == [fixture.url(".gradle/caches").path])
        #expect(FileWalker.expand(pattern: "~/.gradle/missing", home: fixture.root).isEmpty)
    }

    @Test func midGlobExpandsEachContainer() throws {
        try fixture.dir("Library/Containers/com.a/Data")
        try fixture.dir("Library/Containers/com.b/Data")
        try fixture.dir("Library/Containers/com.c/NotData")
        let paths = FileWalker
            .expand(pattern: "~/Library/Containers/*/Data", home: fixture.root)
            .map(\.path)
        #expect(paths.count == 2)
        #expect(paths.allSatisfy { $0.hasSuffix("/Data") })
    }

    @Test func allocatedSizeSumsRecursively() throws {
        try fixture.file("cache/a.bin", bytes: 8192)
        try fixture.file("cache/sub/b.bin", bytes: 8192)
        #expect(FileWalker.allocatedSize(of: fixture.url("cache")) >= 16384)
    }

    @Test func allocatedSizeOfSingleFile() throws {
        let file = try fixture.file("one.bin", bytes: 4096)
        #expect(FileWalker.allocatedSize(of: file) >= 4096)
    }
}

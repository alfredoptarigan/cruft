import Foundation
import Testing
@testable import CleanKit

@Suite struct NeverDeleteTests {
    let fixture: TestFixture
    var home: URL { fixture.root }

    init() throws {
        fixture = try TestFixture()
    }

    func blocked(_ url: URL) -> Bool {
        NeverDelete.contains(url, home: home)
    }

    // MARK: - Absolute system paths

    @Test func rootIsBlocked() {
        #expect(blocked(URL(fileURLWithPath: "/")))
    }

    @Test func systemIsBlocked() {
        #expect(blocked(URL(fileURLWithPath: "/System")))
        #expect(blocked(URL(fileURLWithPath: "/System/Library/CoreServices")))
    }

    @Test func varDBIsBlocked() {
        #expect(blocked(URL(fileURLWithPath: "/private/var/db")))
        #expect(blocked(URL(fileURLWithPath: "/var/db/dslocal")))
    }

    // MARK: - Home structural roots

    @Test func homeAndAncestorsAreBlocked() {
        #expect(blocked(home))
        #expect(blocked(home.deletingLastPathComponent()))
    }

    @Test func userDataDirsAreBlocked() {
        for dir in ["Documents", "Desktop", "Downloads", "Pictures", "Movies", "Music", "Library"] {
            #expect(blocked(fixture.url(dir)), "\(dir) should be blocked")
        }
    }

    @Test func filesInsideUserDataDirsAreAllowed() {
        // The gate is a deny-list, not an allow-list: a review-level rule may
        // legitimately surface a large old file in Documents.
        #expect(!blocked(fixture.url("Documents/old-video.mov")))
    }

    // MARK: - Sensitive subtrees (dir + descendants)

    @Test func keychainsSubtreeIsBlocked() {
        #expect(blocked(fixture.url("Library/Keychains")))
        #expect(blocked(fixture.url("Library/Keychains/login.keychain-db")))
    }

    @Test func sshAndGnupgSubtreesAreBlocked() {
        #expect(blocked(fixture.url(".ssh")))
        #expect(blocked(fixture.url(".ssh/id_ed25519")))
        #expect(blocked(fixture.url(".gnupg/private-keys-v1.d")))
    }

    // MARK: - Container data

    @Test func containerDataIsBlocked() {
        #expect(blocked(fixture.url("Library/Containers")))
        #expect(blocked(fixture.url("Library/Containers/com.example.app")))
        #expect(blocked(fixture.url("Library/Containers/com.example.app/Data")))
        #expect(blocked(fixture.url("Library/Containers/com.example.app/Data/Documents")))
    }

    // MARK: - Legitimate cleanup targets stay allowed

    @Test func cleanupTargetsAreAllowed() {
        #expect(!blocked(fixture.url("Library/Developer/Xcode/DerivedData/MyApp-abcdef")))
        #expect(!blocked(fixture.url("Library/Caches/Homebrew/wget.tar.gz")))
        #expect(!blocked(fixture.url(".gradle/caches")))
        #expect(!blocked(fixture.url(".npm/_cacache")))
    }

    // MARK: - Symlinks

    @Test func symlinkResolvesBeforeCheck() throws {
        // The gate runs on the final resolved URL, after symlink resolution.
        let target = try fixture.dir("Library/Keychains")
        let link = fixture.url("innocent-link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(blocked(link))
    }
}

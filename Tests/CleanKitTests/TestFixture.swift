import Foundation

/// Builds a throwaway directory tree under the system temp dir. Tests use the
/// fixture root as a fake home — no test touches `~` or `/` directly.
final class TestFixture {
    let root: URL

    init() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cruft-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // Canonicalise (/var -> /private/var) so fixture paths compare equal
        // to URLs the scanner gets back from directory enumeration.
        let canonical = try base.resourceValues(forKeys: [.canonicalPathKey]).canonicalPath
        root = URL(fileURLWithPath: canonical ?? base.path)
    }

    deinit {
        // removeItem is banned in CleanKit (deletion must go to Trash); here it
        // removes only our own temp fixture — trashing it would pollute the
        // user's Trash on every test run.
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    func dir(_ relative: String) throws -> URL {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    func file(_ relative: String, bytes: Int = 4096, modified: Date? = nil) throws -> URL {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0xAB, count: bytes).write(to: url)
        if let modified {
            try setModified(relative, modified)
        }
        return url
    }

    func setModified(_ relative: String, _ date: Date) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: date],
            ofItemAtPath: root.appendingPathComponent(relative).path)
    }

    func url(_ relative: String) -> URL {
        root.appendingPathComponent(relative)
    }
}

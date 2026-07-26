import Foundation

/// Expands rule path patterns and measures candidates using stat-level
/// metadata only — file contents are never read, so dataless (iCloud-evicted)
/// files are never materialised.
public enum FileWalker {
    /// Expands a rule path. Supports a leading `~` and `*` as a whole path
    /// component (`.../DerivedData/*`, `.../Containers/*/Data`).
    public static func expand(pattern: String, home: URL) -> [URL] {
        var path = pattern
        if path == "~" || path.hasPrefix("~/") {
            path = home.path + path.dropFirst(1)
        }
        let fileManager = FileManager.default
        var urls = [URL(fileURLWithPath: "/")]
        for component in path.split(separator: "/").map(String.init) {
            if component == "*" {
                urls = urls.flatMap {
                    (try? fileManager.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? []
                }
            } else {
                urls = urls.map { $0.appendingPathComponent(component) }
            }
        }
        return urls
            .filter { fileManager.fileExists(atPath: $0.path) }
            .sorted { $0.path < $1.path }
    }

    /// Recursive allocated (on-disk) size. Uses `.totalFileAllocatedSizeKey`,
    /// never logical size — APFS clones and sparse files lie otherwise.
    public static func allocatedSize(of url: URL) -> Int64 {
        var total = allocatedSizeOfNode(url)
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
              let enumerator = FileManager.default.enumerator(
                  at: url,
                  includingPropertiesForKeys: [.totalFileAllocatedSizeKey])
        else { return total }
        for case let child as URL in enumerator {
            total += allocatedSizeOfNode(child)
        }
        return total
    }

    public static func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? .distantPast
    }

    private static func allocatedSizeOfNode(_ url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?
            .totalFileAllocatedSize ?? 0)
    }
}

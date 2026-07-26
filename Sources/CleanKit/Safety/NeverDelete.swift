import Foundation

/// Hardcoded last-gate deny list, checked against the final resolved URL
/// immediately before any destructive operation. Deliberately not
/// configurable and independent of rules.yaml, so a malformed rules file
/// cannot widen what the tool will touch.
public enum NeverDelete {
    public static func contains(_ url: URL) -> Bool {
        contains(url, home: FileManager.default.homeDirectoryForCurrentUser)
    }

    /// `home` is injectable for tests only; production callers go through the
    /// public overload, which always uses the real home.
    static func contains(_ url: URL, home: URL) -> Bool {
        // Both sides go through the same canonicalisation, or the
        // /var <-> /private/var alias makes prefix checks silently miss.
        let path = canonicalPath(url)
        let homePath = canonicalPath(home)

        if path == "/" { return true }

        // Sensitive subtrees: the node and everything inside it. /var/db is
        // listed both ways because resolvingSymlinksInPath is inconsistent
        // about the /private prefix.
        let subtrees = [
            "/System",
            "/private/var/db",
            "/var/db",
            homePath + "/Library/Keychains",
            homePath + "/.ssh",
            homePath + "/.gnupg",
        ]
        for root in subtrees where path == root || path.hasPrefix(root + "/") {
            return true
        }

        // ~/Library/Containers/<bundle-id> and its Data subtree. The container
        // dir itself is blocked because deleting it deletes Data with it.
        let containers = homePath + "/Library/Containers/"
        if path.hasPrefix(containers) {
            let rest = path.dropFirst(containers.count).split(separator: "/")
            if rest.count == 1 { return true }
            if rest.count >= 2 && rest[1] == "Data" { return true }
        }

        // Structural nodes: blocked themselves, and so is any ancestor —
        // deleting an ancestor would take the protected node with it.
        // Descendants stay allowed: this is a deny-list, not an allow-list.
        let nodes = [
            homePath,
            homePath + "/Library",
            homePath + "/Library/Application Support",
            homePath + "/Library/Containers",
            homePath + "/Documents",
            homePath + "/Desktop",
            homePath + "/Downloads",
            homePath + "/Pictures",
            homePath + "/Movies",
            homePath + "/Music",
        ]
        for node in nodes where path == node || node.hasPrefix(path + "/") {
            return true
        }
        return false
    }

    /// Symlink-resolved path with the /var <-> /private/var alias pinned to
    /// one form. `resolvingSymlinksInPath` strips /private inconsistently
    /// (existing vs nonexistent tails), so we normalise it ourselves.
    private static func canonicalPath(_ url: URL) -> String {
        var path = url.standardizedFileURL.resolvingSymlinksInPath().path
        for alias in ["/private/var", "/private/tmp", "/private/etc"]
        where path == alias || path.hasPrefix(alias + "/") {
            path = String(path.dropFirst("/private".count))
            break
        }
        return path
    }
}

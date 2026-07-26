import Darwin
import Foundation

/// Detects dataless (cloud-evicted) files. Their contents live in iCloud or
/// another file provider; *reading* them triggers a download — potentially
/// tens of gigabytes. `lstat` itself never materialises the file.
public enum DatalessFilter {
    /// SF_DATALESS from <sys/stat.h>.
    static let datalessFlag: UInt32 = 0x4000_0000

    public static func isDataless(_ url: URL) -> Bool {
        var status = stat()
        guard lstat(url.path, &status) == 0 else { return false }
        return isDataless(flags: status.st_flags)
    }

    static func isDataless(flags: UInt32) -> Bool {
        flags & datalessFlag != 0
    }
}

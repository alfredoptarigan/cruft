public enum ScanEvent: Sendable {
    case started(estimatedRoots: Int)
    case progress(scanned: Int, currentPath: String)
    case found(CleanupItem)
    case finished(ScanResult)
}

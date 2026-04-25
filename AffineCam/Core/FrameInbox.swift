import CoreMedia

/// Thread-safe single-slot buffer for camera frames.
/// The producer overwrites old frames; consumers always read the latest frame.
/// Access is protected by NSLock. Safe for cross-thread use.
nonisolated final class FrameInbox: @unchecked Sendable {
    private let frameLock = NSLock()
    private var latestSampleBuffer: CMSampleBuffer?
    
    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        frameLock.lock()
        defer { frameLock.unlock() }
        latestSampleBuffer = sampleBuffer
    }
    
    func latest() -> CMSampleBuffer? {
        frameLock.lock()
        defer { frameLock.unlock() }
        return latestSampleBuffer
    }
}

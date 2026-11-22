import Foundation
import CoreGraphics

public struct WindowPreSnapState {
    public let originalFrame: CGRect
    public var lastSnappedZone: SnapZone?
    public var lastSnappedFrame: CGRect?
    public var snappedAt: Date
    
    public init(originalFrame: CGRect, lastSnappedZone: SnapZone? = nil, lastSnappedFrame: CGRect? = nil, snappedAt: Date = Date()) {
        self.originalFrame = originalFrame
        self.lastSnappedZone = lastSnappedZone
        self.lastSnappedFrame = lastSnappedFrame
        self.snappedAt = snappedAt
    }
}

public class WindowHistoryTracker {
    public static let shared = WindowHistoryTracker()
    
    // Keyed by a composite identifier: e.g. "\(bundleId)_\(windowTitle)" or process ID
    private var history: [String: WindowPreSnapState] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    public func recordPreSnapState(for windowKey: String, currentFrame: CGRect, requestedZone: SnapZone) -> (original: CGRect, shouldToggleBack: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        if let existing = history[windowKey] {
            // Check if user clicked the same zone again -> toggle back to original size!
            if existing.lastSnappedZone == requestedZone {
                // Return original frame and toggle
                history.removeValue(forKey: windowKey)
                return (existing.originalFrame, true)
            }
            // Keep original frame, update zone
            var updated = existing
            updated.lastSnappedZone = requestedZone
            updated.snappedAt = Date()
            history[windowKey] = updated
            return (existing.originalFrame, false)
        } else {
            // First time snapping this window: store current frame as original frame
            let state = WindowPreSnapState(originalFrame: currentFrame, lastSnappedZone: requestedZone, snappedAt: Date())
            history[windowKey] = state
            return (currentFrame, false)
        }
    }
    
    public func updateLastSnappedFrame(for windowKey: String, frame: CGRect) {
        lock.lock()
        defer { lock.unlock() }
        if var existing = history[windowKey] {
            existing.lastSnappedFrame = frame
            history[windowKey] = existing
        }
    }
    
    public func getOriginalFrame(for windowKey: String) -> CGRect? {
        lock.lock()
        defer { lock.unlock() }
        return history[windowKey]?.originalFrame
    }
    
    public func removeHistory(for windowKey: String) {
        lock.lock()
        defer { lock.unlock() }
        history.removeValue(forKey: windowKey)
    }
    
    public func getState(for windowKey: String) -> WindowPreSnapState? {
        lock.lock()
        defer { lock.unlock() }
        return history[windowKey]
    }
}

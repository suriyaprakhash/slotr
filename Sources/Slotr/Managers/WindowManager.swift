import Cocoa
import ApplicationServices

public struct TargetWindowDetails: Equatable {
    public let appName: String
    public let bundleId: String
    public let title: String
    public let frame: CGRect
    public let isSnapped: Bool
    public let lastZone: SnapZone?
    public let originalFrame: CGRect?
}

public class WindowManager: ObservableObject {
    public static let shared = WindowManager()
    
    @Published public var targetWindowDetails: TargetWindowDetails?
    
    /// Tracks the application that was active right before Slotr took focus
    public var lastActiveApp: NSRunningApplication?
    
    private var pollTimer: Timer?
    private var axObserver: AXObserver?
    private var observedPID: pid_t = 0
    private var pendingAXRefresh: DispatchWorkItem?
    private var pendingPostSnapRefresh: DispatchWorkItem?
    
    private init() {
        setupObservers()
        startPolling()
    }
    
    deinit {
        stopPolling()
        teardownAXObserver()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    private func setupObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(didActivateApplication(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }
    
    private func startPolling() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshTargetWindow()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
    
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    @objc private func didActivateApplication(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if app.bundleIdentifier != Bundle.main.bundleIdentifier && app.activationPolicy == .regular {
            self.lastActiveApp = app
            self.refreshTargetWindow()
        }
    }
    
    @objc private func activeSpaceDidChange(_ notification: Notification) {
        refreshTargetWindow()
    }
    
    // MARK: - Live AX Resize / Move Observer
    
    private func ensureAXObserver(for pid: pid_t) {
        guard AccessibilityManager.shared.isTrusted else {
            teardownAXObserver()
            return
        }
        guard pid > 0, pid != observedPID else { return }
        teardownAXObserver()
        
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon = refcon else { return }
            let manager = Unmanaged<WindowManager>.fromOpaque(refcon).takeUnretainedValue()
            manager.scheduleLiveRefreshFromAX()
        }
        
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else {
            return
        }
        
        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let notifications: [CFString] = [
            kAXWindowResizedNotification as CFString,
            kAXWindowMovedNotification as CFString,
            kAXFocusedWindowChangedNotification as CFString,
            kAXTitleChangedNotification as CFString
        ]
        for notif in notifications {
            AXObserverAddNotification(observer, appElement, notif, refcon)
        }
        
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        self.axObserver = observer
        self.observedPID = pid
    }
    
    private func teardownAXObserver() {
        if let observer = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        axObserver = nil
        observedPID = 0
    }
    
    private func scheduleLiveRefreshFromAX() {
        pendingAXRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refreshTargetWindow()
            DesktopManager.shared.refresh()
        }
        pendingAXRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
    }
    
    // MARK: - Target App & Window Resolution
    
    public func getTargetApplication() -> NSRunningApplication? {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier,
           front.activationPolicy == .regular {
            return front
        }
        return lastActiveApp
    }
    
    public func getTargetWindowElement() -> (app: NSRunningApplication, window: AXUIElement)? {
        guard let app = getTargetApplication() else { return nil }
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // 1. Try focused window
        var focusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success,
           let win = focusedRef {
            return (app, win as! AXUIElement)
        }
        
        // 2. Try main window
        var mainRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainRef) == .success,
           let win = mainRef {
            return (app, win as! AXUIElement)
        }
        
        // 3. Fallback: First window in windows list
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windowList = windowsRef as? [AXUIElement],
           let firstWin = windowList.first {
            return (app, firstWin)
        }
        
        return nil
    }
    
    public func refreshTargetWindow() {
        guard let (app, win) = getTargetWindowElement() else {
            DispatchQueue.main.async {
                if self.targetWindowDetails != nil {
                    self.targetWindowDetails = nil
                }
            }
            return
        }
        
        ensureAXObserver(for: app.processIdentifier)
        
        let appName = app.localizedName ?? "App"
        let bundleId = app.bundleIdentifier ?? ""
        let title = getWindowTitle(win)
        guard let frame = getWindowFrame(win) else { return }
        
        let windowKey = "\(bundleId)_\(title)_\(app.processIdentifier)"
        let historyState = WindowHistoryTracker.shared.getState(for: windowKey)
        
        let details = TargetWindowDetails(
            appName: appName,
            bundleId: bundleId,
            title: title,
            frame: frame,
            isSnapped: historyState?.lastSnappedZone != nil,
            lastZone: historyState?.lastSnappedZone,
            originalFrame: historyState?.originalFrame
        )
        
        DispatchQueue.main.async {
            if self.targetWindowDetails != details {
                self.targetWindowDetails = details
            }
        }
    }
    
    // MARK: - Frame & Attribute Helpers
    
    public func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posVal = posRef, CFGetTypeID(posVal) == AXValueGetTypeID(),
              let sizeVal = sizeRef, CFGetTypeID(sizeVal) == AXValueGetTypeID() else {
            return nil
        }
        
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posVal as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }
    
    public func setWindowFrame(_ window: AXUIElement, frame: CGRect) {
        var point = frame.origin
        var size = frame.size
        
        // Pass 1: Set position first
        if let posVal = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        }
        // Pass 2: Set size
        if let sizeVal = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
        }
        // Pass 3: Re-apply position (in case previous size limited repositioning)
        if let posVal = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        }
    }
    
    public func getWindowTitle(_ window: AXUIElement) -> String {
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
           let title = titleRef as? String {
            return title
        }
        return ""
    }
    
    // MARK: - Screen Calculations
    
    /// Converts NSScreen visible frames into Accessibility (Quartz) coordinate space
    public func getQuartzUsableRect(for screen: NSScreen) -> CGRect {
        guard let primary = NSScreen.screens.first else {
            return screen.visibleFrame
        }
        let primaryHeight = primary.frame.height
        let qX = screen.visibleFrame.origin.x
        let qY = primaryHeight - (screen.visibleFrame.origin.y + screen.visibleFrame.height)
        let qW = screen.visibleFrame.width
        let qH = screen.visibleFrame.height
        return CGRect(x: qX, y: qY, width: qW, height: qH)
    }
    
    /// Finds which screen currently hosts the given window frame
    public func getScreen(for windowFrame: CGRect) -> NSScreen {
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        
        // Check which screen's quartz frame contains the center
        guard let primary = NSScreen.screens.first else { return NSScreen.main ?? NSScreen() }
        let primaryHeight = primary.frame.height
        
        for screen in NSScreen.screens {
            let sX = screen.frame.origin.x
            let sY = primaryHeight - (screen.frame.origin.y + screen.frame.height)
            let sFrame = CGRect(x: sX, y: sY, width: screen.frame.width, height: screen.frame.height)
            if sFrame.contains(center) {
                return screen
            }
        }
        
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }
    
    // MARK: - Snapping Operations
    
    @discardableResult
    public func snapActiveWindow(to zone: SnapZone) -> Bool {
        guard AccessibilityManager.shared.isTrusted else {
            AccessibilityManager.shared.requestPermission()
            return false
        }
        
        guard let (app, window) = getTargetWindowElement(),
              let currentFrame = getWindowFrame(window) else {
            return false
        }
        
        let screen = getScreen(for: currentFrame)
        let usableRect = getQuartzUsableRect(for: screen)
        let gap = CGFloat(AppSettings.shared.windowGapPadding.rawValue)
        let targetFrame = zone.targetFrame(for: usableRect, gap: gap)
        
        let bundleId = app.bundleIdentifier ?? ""
        let title = getWindowTitle(window)
        let windowKey = "\(bundleId)_\(title)_\(app.processIdentifier)"
        
        // Record pre-snap state and check if toggling back to original
        let (originalFrame, shouldToggle) = WindowHistoryTracker.shared.recordPreSnapState(
            for: windowKey,
            currentFrame: currentFrame,
            requestedZone: zone
        )
        
        if shouldToggle {
            // Restore back to original pre-snap frame
            setWindowFrame(window, frame: originalFrame)
            triggerImmediateAndSettledRefresh()
            HUDOverlay.shared.show(message: "Restored to Original Size", icon: "arrow.counterclockwise")
            return true
        } else {
            // Apply the snap frame
            setWindowFrame(window, frame: targetFrame)
            WindowHistoryTracker.shared.updateLastSnappedFrame(for: windowKey, frame: targetFrame)
            triggerImmediateAndSettledRefresh()
            HUDOverlay.shared.show(message: "Snapped to \(zone.title)", icon: zone.iconName)
            return true
        }
    }
    
    @discardableResult
    public func restoreOriginalWindowSize() -> Bool {
        guard let (app, window) = getTargetWindowElement() else { return false }
        let bundleId = app.bundleIdentifier ?? ""
        let title = getWindowTitle(window)
        let windowKey = "\(bundleId)_\(title)_\(app.processIdentifier)"
        
        guard let original = WindowHistoryTracker.shared.getOriginalFrame(for: windowKey) else {
            HUDOverlay.shared.show(message: "No previous size recorded", icon: "exclamationmark.circle")
            return false
        }
        
        setWindowFrame(window, frame: original)
        WindowHistoryTracker.shared.removeHistory(for: windowKey)
        triggerImmediateAndSettledRefresh()
        HUDOverlay.shared.show(message: "Restored Original Size & Position", icon: "arrow.counterclockwise")
        return true
    }
    
    private func triggerImmediateAndSettledRefresh() {
        refreshTargetWindow()
        DesktopManager.shared.refresh()
        
        // Re-read after 150ms so apps that clamp or animate AX resize settle accurately.
        pendingPostSnapRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refreshTargetWindow()
            DesktopManager.shared.refresh()
        }
        pendingPostSnapRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
}

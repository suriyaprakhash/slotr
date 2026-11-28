import AppKit
import UniformTypeIdentifiers

// MARK: - Screen Orientation

public enum ScreenOrientation: String, Equatable {
    case landscape
    case portrait
    case square
    
    public var label: String {
        switch self {
        case .landscape: return "Landscape"
        case .portrait: return "Portrait"
        case .square: return "Square"
        }
    }
    
    public var iconName: String {
        switch self {
        case .landscape: return "rectangle"
        case .portrait: return "rectangle.portrait"
        case .square: return "square"
        }
    }
    
    public static func from(frame: CGRect) -> ScreenOrientation {
        guard frame.width > 0, frame.height > 0 else { return .landscape }
        if abs(frame.width - frame.height) < 1 { return .square }
        return frame.width > frame.height ? .landscape : .portrait
    }
}

// MARK: - Desktop Window

public struct DesktopWindow: Identifiable, Hashable {
    public let id: CGWindowID
    public let spaceID: Int64
    public let ownerPID: pid_t
    public let appName: String
    public let bundleId: String
    public let windowName: String
    public let frame: CGRect
    /// Ordinal window index within its app on this desktop (used on restore).
    public let windowIndex: Int
    
    public init(id: CGWindowID, spaceID: Int64, ownerPID: pid_t, appName: String, bundleId: String, windowName: String, frame: CGRect, windowIndex: Int) {
        self.id = id
        self.spaceID = spaceID
        self.ownerPID = ownerPID
        self.appName = appName
        self.bundleId = bundleId
        self.windowName = windowName
        self.frame = frame
        self.windowIndex = windowIndex
    }
}

// MARK: - Desktop Info

public struct DesktopInfo: Identifiable, Equatable {
    /// SLS space id — stable and unique across displays.
    public let id: Int64
    /// 0-based position in Mission Control order (across all displays).
    public let index: Int
    public let displayIndex: Int
    public let isCurrent: Bool
    public let isMultiDisplay: Bool
    public let orientation: ScreenOrientation
    public let displayBounds: CGRect
    public let windows: [DesktopWindow]
    
    public init(id: Int64, index: Int, displayIndex: Int, isCurrent: Bool, isMultiDisplay: Bool, orientation: ScreenOrientation, displayBounds: CGRect = .zero, windows: [DesktopWindow]) {
        self.id = id
        self.index = index
        self.displayIndex = displayIndex
        self.isCurrent = isCurrent
        self.isMultiDisplay = isMultiDisplay
        self.orientation = orientation
        self.displayBounds = displayBounds
        self.windows = windows
    }
    
    public var displayName: String {
        if isMultiDisplay {
            return "Desktop \(index + 1) · Display \(displayIndex + 1)"
        }
        return "Desktop \(index + 1)"
    }
    
    public var isEmpty: Bool {
        windows.isEmpty
    }
    
    /// One representative window per app, deduped by bundle id, in display order.
    public var uniqueApps: [DesktopWindow] {
        var seen = Set<String>()
        return windows.filter {
            let key = $0.bundleId.isEmpty ? $0.appName : $0.bundleId
            return seen.insert(key).inserted
        }
    }
}

// MARK: - Desktop Manager

/// Enumerates the current macOS Spaces (desktops) and the app windows running
/// on each one, using the SkyLight (SLS) private APIs plus the public
/// CGWindowList APIs. This is the same family of APIs Hammerspoon's
/// `hs.spaces` uses; the symbols are resolved with dlsym so the app never
/// links against the private framework directly.
public class DesktopManager: ObservableObject {
    public static let shared = DesktopManager()
    
    @Published public private(set) var desktops: [DesktopInfo] = []
    @Published public private(set) var isAvailable: Bool = false
    
    private var pollTimer: Timer?
    private var windowDetailCache: [CGWindowID: WindowDetail] = [:]
    private var iconCache: [String: NSImage] = [:]
    
    private let skyLightHandle: UnsafeMutableRawPointer?
    private let slsMainConnectionID: SLSMainConnectionIDFn?
    private let slsCopyManagedDisplaySpaces: SLSCopyManagedDisplaySpacesFn?
    private let slsCopyWindowsWithOptionsAndTags: SLSCopyWindowsWithOptionsAndTagsFn?
    
    /// Window server-side details, cached per CGWindowID. Window numbers are
    /// stable, so steady-state refreshes make zero extra WindowServer calls
    /// for windows on inactive spaces.
    private struct WindowDetail {
        let ownerPID: pid_t
        let appName: String
        let bundleId: String
        let windowName: String
        let frame: CGRect
        let layer: Int
        let alpha: Double
    }
    
    private static let skippedOwners: Set<String> = [
        "Dock", "WindowServer", "NotificationCenter", "ControlCenter"
    ]
    
    private init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
        skyLightHandle = handle
        slsMainConnectionID = Self.resolve(handle, "SLSMainConnectionID")
        slsCopyManagedDisplaySpaces = Self.resolve(handle, "SLSCopyManagedDisplaySpaces")
        slsCopyWindowsWithOptionsAndTags = Self.resolve(handle, "SLSCopyWindowsWithOptionsAndTags")
        
        startPolling()
    }
    
    deinit {
        stopPolling()
    }
    
    private static func resolve<T>(_ handle: UnsafeMutableRawPointer?, _ name: String) -> T? {
        guard let handle, let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
    
    // MARK: - Polling
    
    private func startPolling() {
        guard pollTimer == nil else { return }
        
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshInternal()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        
        // Re-check promptly when a display is added, removed, or reconfigured.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshInternal()
        }
        
        // Re-check immediately on Space switches or app activation.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshInternal()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshInternal()
        }
        
        refreshInternal()
    }
    
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    public func refresh() {
        refreshInternal()
    }
    
    // MARK: - Refresh
    
    private func refreshInternal() {
        guard let mainConnectionID = slsMainConnectionID,
              let copyDisplaySpaces = slsCopyManagedDisplaySpaces,
              let copySpaceWindows = slsCopyWindowsWithOptionsAndTags else {
            isAvailable = false
            return
        }
        
        let connectionID = mainConnectionID()
        guard let unmanagedDisplays = copyDisplaySpaces(connectionID) else {
            // Transient failures keep the last known state when we have some.
            if desktops.isEmpty { isAvailable = false }
            return
        }
        let displays = (unmanagedDisplays.takeRetainedValue() as NSArray) as? [[String: Any]] ?? []
        guard !displays.isEmpty else {
            if desktops.isEmpty { isAvailable = false }
            return
        }
        
        isAvailable = true
        
        // 1. Collect user + fullscreen spaces, keeping Mission Control order.
        struct SpaceEntry {
            let spaceID: Int64
            let displayIndex: Int
            let isCurrent: Bool
        }
        var entries: [SpaceEntry] = []
        for (displayIndex, display) in displays.enumerated() {
            // macOS returns "Current Space" as a dict containing id64 / ManagedSpaceID (older versions may use NSNumber).
            let currentSpaceDict = display["Current Space"] as? [String: Any]
            let currentSpaceID = (currentSpaceDict?["id64"] as? NSNumber)?.int64Value
                ?? (currentSpaceDict?["ManagedSpaceID"] as? NSNumber)?.int64Value
                ?? (display["Current Space"] as? NSNumber)?.int64Value
            let spaces = display["Spaces"] as? [[String: Any]] ?? []
            for space in spaces {
                guard let spaceID = (space["id64"] as? NSNumber)?.int64Value
                    ?? (space["ManagedSpaceID"] as? NSNumber)?.int64Value else { continue }
                let spaceType = (space["type"] as? NSNumber)?.intValue ?? 0
                // 0 = user desktop, 4 = fullscreen app space; skip the rest.
                guard spaceType == 0 || spaceType == 4 else { continue }
                
                let isCurrent: Bool
                if let currentSpaceID {
                    isCurrent = (spaceID == currentSpaceID)
                } else {
                    // Older macOS: per-space boolean flags.
                    isCurrent = (space["current"] as? Bool) ?? (space["active"] as? Bool) ?? false
                }
                entries.append(SpaceEntry(spaceID: spaceID, displayIndex: displayIndex, isCurrent: isCurrent))
            }
        }
        
        // 2. Window ids per space (option 0x2 = exclude minimized windows).
        var spaceWindows: [Int64: [CGWindowID]] = [:]
        var allWindowIDs: Set<CGWindowID> = []
        for entry in entries {
            var setTags: UInt64 = 0
            var clearTags: UInt64 = 0
            let spaceIDs = [NSNumber(value: entry.spaceID)] as CFArray
            if let unmanaged = copySpaceWindows(connectionID, 0, spaceIDs, 0x2, &setTags, &clearTags) {
                let ids = (unmanaged.takeRetainedValue() as NSArray) as? [NSNumber] ?? []
                let cgsIDs = ids.map { $0.uint32Value }
                spaceWindows[entry.spaceID] = cgsIDs
                allWindowIDs.formUnion(cgsIDs)
            } else {
                spaceWindows[entry.spaceID] = []
            }
        }
        
        // 3. Window details. Active-space windows are re-fetched every poll so
        //    moving/resizing windows stays accurate; inactive-space windows
        //    come from the cache.
        var currentSpaceWindowIDs: Set<CGWindowID> = []
        for entry in entries where entry.isCurrent {
            currentSpaceWindowIDs.formUnion(spaceWindows[entry.spaceID] ?? [])
        }
        refreshWindowDetails(for: allWindowIDs, alwaysRefresh: currentSpaceWindowIDs)
        
        // 4. Orientation & Quartz bounds per display.
        var orientationByDisplay: [Int: ScreenOrientation] = [:]
        var boundsByDisplay: [Int: CGRect] = [:]
        for (displayIndex, display) in displays.enumerated() {
            let bounds = quartzBounds(forDisplay: display, displayIndex: displayIndex)
            boundsByDisplay[displayIndex] = bounds
            orientationByDisplay[displayIndex] = .from(frame: bounds)
        }
        
        // 5. Build the desktop models.
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let isMultiDisplay = displays.count > 1
        let newDesktops: [DesktopInfo] = entries.enumerated().map { (ordinal, entry) in
            var indexPerApp: [String: Int] = [:]
            var windows: [DesktopWindow] = []
            for windowID in (spaceWindows[entry.spaceID] ?? []) {
                guard let detail = windowDetailCache[windowID] else { continue }
                // Regular app windows only: layer 0, visible, real apps.
                guard detail.layer == 0, detail.alpha > 0.5 else { continue }
                guard detail.ownerPID != selfPID else { continue }
                guard !DesktopManager.skippedOwners.contains(detail.appName) else { continue }
                guard detail.frame.width >= 60, detail.frame.height >= 60 else { continue }
                // Nameless Finder windows are desktop helpers, not app windows.
                if detail.appName == "Finder" && detail.windowName.isEmpty { continue }
                
                let appKey = detail.bundleId.isEmpty ? detail.appName : detail.bundleId
                let windowIndex = indexPerApp[appKey] ?? 0
                indexPerApp[appKey] = windowIndex + 1
                
                windows.append(DesktopWindow(
                    id: windowID,
                    spaceID: entry.spaceID,
                    ownerPID: detail.ownerPID,
                    appName: detail.appName,
                    bundleId: detail.bundleId,
                    windowName: detail.windowName,
                    frame: detail.frame,
                    windowIndex: windowIndex
                ))
            }
            
            return DesktopInfo(
                id: entry.spaceID,
                index: ordinal,
                displayIndex: entry.displayIndex,
                isCurrent: entry.isCurrent,
                isMultiDisplay: isMultiDisplay,
                orientation: orientationByDisplay[entry.displayIndex] ?? .landscape,
                displayBounds: boundsByDisplay[entry.displayIndex] ?? .zero,
                windows: windows
            )
        }
        
        // Only publish on real changes to avoid needless SwiftUI updates.
        if newDesktops != desktops {
            desktops = newDesktops
        }
    }
    
    private func refreshWindowDetails(for windowIDs: Set<CGWindowID>, alwaysRefresh: Set<CGWindowID>) {
        for windowID in windowIDs where alwaysRefresh.contains(windowID) || windowDetailCache[windowID] == nil {
            if let detail = windowDetail(for: windowID) {
                windowDetailCache[windowID] = detail
            }
        }
        // Drop details for windows that no longer exist.
        windowDetailCache = windowDetailCache.filter { windowIDs.contains($0.key) }
    }
    
    private func windowDetail(for windowID: CGWindowID) -> WindowDetail? {
        guard let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let window = info.first else {
            return nil
        }
        let appName = window[kCGWindowOwnerName as String] as? String ?? ""
        let ownerPID = (window[kCGWindowOwnerPID as String] as? NSNumber)?.intValue ?? 0
        let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -99
        let alpha = (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0
        let windowName = window[kCGWindowName as String] as? String ?? ""
        let bundleId: String = {
            guard ownerPID > 0 else { return "" }
            return NSRunningApplication(processIdentifier: Int32(ownerPID))?.bundleIdentifier ?? ""
        }()
        
        var frame = CGRect.zero
        if let bounds = window[kCGWindowBounds as String] as? [String: Any] {
            frame = CGRect(
                x: bounds["X"] as? Double ?? 0,
                y: bounds["Y"] as? Double ?? 0,
                width: bounds["Width"] as? Double ?? 0,
                height: bounds["Height"] as? Double ?? 0
            )
        }
        
        return WindowDetail(
            ownerPID: pid_t(ownerPID),
            appName: appName,
            bundleId: bundleId,
            windowName: windowName,
            frame: frame,
            layer: layer,
            alpha: alpha
        )
    }
    
    // MARK: - Display Geometry & Orientation
    
    private func screen(forDisplay display: [String: Any], displayIndex: Int) -> NSScreen? {
        if let displayUUID = display["Display Identifier"] as? String ?? display["DisplayUUID"] as? String,
           let matched = NSScreen.screens.first(where: { Self.screenUUIDString($0) == displayUUID }) {
            return matched
        }
        return displayIndex < NSScreen.screens.count ? NSScreen.screens[displayIndex] : NSScreen.main
    }
    
    private func quartzBounds(forDisplay display: [String: Any], displayIndex: Int) -> CGRect {
        guard let targetScreen = screen(forDisplay: display, displayIndex: displayIndex) else {
            return .zero
        }
        guard let primary = NSScreen.screens.first else {
            return targetScreen.frame
        }
        let primaryHeight = primary.frame.height
        let qX = targetScreen.frame.origin.x
        let qY = primaryHeight - (targetScreen.frame.origin.y + targetScreen.frame.height)
        return CGRect(x: qX, y: qY, width: targetScreen.frame.width, height: targetScreen.frame.height)
    }
    
    private static func screenUUIDString(_ screen: NSScreen) -> String? {
        if let screenNumber = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
           let uuid = CGDisplayCreateUUIDFromDisplayID(screenNumber)?.takeRetainedValue(),
           let uuidString = CFUUIDCreateString(nil, uuid) as String? {
            return uuidString
        }
        let key = NSDeviceDescriptionKey("NSScreenDeviceUUIDKey")
        if let string = screen.deviceDescription[key] as? String {
            return string
        }
        guard let data = screen.deviceDescription[key] as? Data, data.count == 16 else {
            return nil
        }
        let bytes = [UInt8](data)
        func hex(_ offset: Int, _ count: Int) -> String {
            bytes[offset..<(offset + count)].map { String(format: "%02x", $0) }.joined()
        }
        return "\(hex(0, 8))-\(hex(8, 4))-\(hex(12, 4))-\(hex(16, 4))-\(hex(20, 12))"
    }
    
    // MARK: - App Icons
    
    /// Cached app icon for the app that owns a window.
    public func icon(for window: DesktopWindow) -> NSImage {
        let key = window.bundleId.isEmpty ? window.appName : window.bundleId
        if let cached = iconCache[key] { return cached }
        
        let image: NSImage
        if !window.bundleId.isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: window.bundleId) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            image = NSWorkspace.shared.icon(for: UTType.application)
        }
        iconCache[key] = image
        return image
    }
    
    // MARK: - Slot It
    
    /// Saves this desktop's window layout into the first empty slot.
    public func slotIt(_ desktop: DesktopInfo) {
        guard !desktop.isEmpty else { return }
        
        guard let slotId = SlotManager.shared.firstEmptySlotID() else {
            HUDOverlay.shared.show(message: "All 8 Slots Are In Use", icon: "exclamationmark.triangle")
            return
        }
        
        saveDesktop(desktop, toSlotId: slotId)
    }
    
    /// Saves a desktop's window layout into a specific slot (1...8).
    public func saveDesktop(_ desktop: DesktopInfo, toSlotId slotId: Int) {
        guard !desktop.isEmpty else {
            HUDOverlay.shared.show(message: "\(desktop.displayName) Has No Windows", icon: "macwindow")
            return
        }
        
        let label = desktop.displayName
        if desktop.isCurrent {
            // Active desktop: use the standard Accessibility capture path
            // (same mechanism as the slot Save buttons).
            SlotManager.shared.saveCurrentLayout(to: slotId)
        } else {
            let savedWindows: [SavedWindow] = desktop.windows.map { w in
                SavedWindow(
                    bundleId: w.bundleId,
                    appName: w.appName,
                    windowTitle: w.windowName,
                    x: Double(w.frame.origin.x),
                    y: Double(w.frame.origin.y),
                    width: Double(w.frame.width),
                    height: Double(w.frame.height),
                    windowIndex: w.windowIndex
                )
            }
            SlotManager.shared.saveDesktopWindows(savedWindows, to: slotId, desktopLabel: label)
        }
    }
    
    /// Targets an external application window for Quick Snap when clicked in the Film Roll.
    public func selectTargetWindow(_ window: DesktopWindow) {
        if let app = NSRunningApplication(processIdentifier: window.ownerPID),
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            WindowManager.shared.lastActiveApp = app
            WindowManager.shared.refreshTargetWindow()
        }
    }
    
    // MARK: - Switch Desktop (Space)
    
    /// Switches to the given desktop (macOS Space) by simulating the
    /// Mission Control keyboard shortcut Control+<number>.
    /// Requires Accessibility permission (already granted) and that the
    /// user has the "Switch to Desktop N" shortcuts enabled in
    /// System Settings → Keyboard → Keyboard Shortcuts → Mission Control.
    public func switchToDesktop(_ desktop: DesktopInfo) {
        // Don't switch if it's already the current space.
        guard !desktop.isCurrent else { return }
        
        // The ordinal is 1-based Mission Control order.
        let ordinal = desktop.index + 1
        guard ordinal >= 1, ordinal <= 10 else {
            HUDOverlay.shared.show(message: "Cannot switch: Desktop \(ordinal) out of range", icon: "exclamationmark.triangle")
            return
        }
        
        // macOS virtual keycodes for number keys 1-9, 0
        // 1→18, 2→19, 3→20, 4→21, 5→23, 6→22, 7→26, 8→28, 9→25, 0→29
        let keycodes: [Int: UInt16] = [
            1: 18, 2: 19, 3: 20, 4: 21, 5: 23,
            6: 22, 7: 26, 8: 28, 9: 25, 10: 29
        ]
        
        guard let keycode = keycodes[ordinal] else { return }
        
        let src = CGEventSource(stateID: .combinedSessionState)
        
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keycode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: keycode, keyDown: false) else {
            HUDOverlay.shared.show(message: "Cannot create keyboard event", icon: "exclamationmark.triangle")
            return
        }
        
        keyDown.flags = .maskControl
        keyUp.flags = .maskControl
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        
        // Refresh after a short delay to let the space switch complete.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refreshInternal()
        }
    }
    
    /// Cached app icon for a bundle id / app name.
    public func icon(bundleId: String, appName: String) -> NSImage {
        let key = bundleId.isEmpty ? appName : bundleId
        if let cached = iconCache[key] { return cached }
        
        let image: NSImage
        if !bundleId.isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            image = NSWorkspace.shared.icon(for: UTType.application)
        }
        iconCache[key] = image
        return image
    }
}

// MARK: - SkyLight Function Signatures

typealias SLSMainConnectionIDFn = @convention(c) () -> Int32
typealias SLSCopyManagedDisplaySpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
typealias SLSCopyWindowsWithOptionsAndTagsFn = @convention(c) (Int32, UInt32, CFArray, UInt32, UnsafeMutablePointer<UInt64>, UnsafeMutablePointer<UInt64>) -> Unmanaged<CFArray>?

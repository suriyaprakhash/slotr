import Cocoa
import ApplicationServices

public class SlotManager: ObservableObject {
    public static let shared = SlotManager()
    
    @Published public var slots: [LayoutSlot] = []
    @Published public var editingSlotId: Int? = nil
    @Published public var editingName: String = ""
    
    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Slotr", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("slots.json")
    }()
    
    private init() {
        loadSlots()
    }
    
    // MARK: - Persistence
    
    public func loadSlots() {
        // 1. Try loading from UserDefaults first (always accessible on macOS)
        let savedData = UserDefaults.standard.data(forKey: "slotr_saved_slots") ?? UserDefaults.standard.data(forKey: "macsnap_saved_slots")
        if let data = savedData,
           let decoded = try? JSONDecoder().decode([LayoutSlot].self, from: data),
           decoded.count == 8 {
            self.slots = decoded
            return
        }
        
        // 2. Try loading from Application Support file
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                let decoded = try JSONDecoder().decode([LayoutSlot].self, from: data)
                if decoded.count == 8 {
                    self.slots = decoded
                    return
                }
            }
        } catch {
            print("Slotr: Could not load slots from file: \(error)")
        }
        
        // Default 8 empty slots
        self.slots = (1...8).map { LayoutSlot(id: $0) }
        saveSlots()
    }
    
    public func saveSlots() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(slots)
            
            // 1. Always save to UserDefaults (guaranteed to succeed with zero permission issues)
            UserDefaults.standard.set(data, forKey: "slotr_saved_slots")
            
            // 2. Also try writing to Application Support if available
            try? data.write(to: fileURL, options: .atomic)
        } catch {
            print("Slotr: Failed to encode slots: \(error)")
        }
    }
    
    // MARK: - Slot Actions
    
    public func slot(for id: Int) -> LayoutSlot? {
        slots.first(where: { $0.id == id })
    }
    
    @discardableResult
    public func saveCurrentLayout(to slotId: Int) -> Bool {
        guard AccessibilityManager.shared.isTrusted else {
            AccessibilityManager.shared.requestPermission()
            return false
        }
        
        let capturedWindows = captureOnScreenWindows()
        return storeWindows(capturedWindows, to: slotId, hudMessage: "Slot \(slotId) Saved (\(capturedWindows.count) Windows)")
    }
    
    /// Stores an already-captured window list into a slot.
    /// Shared by the on-screen capture path and the desktop "Slot It" path.
    @discardableResult
    public func storeWindows(_ windows: [SavedWindow], to slotId: Int, hudMessage: String) -> Bool {
        guard let index = slots.firstIndex(where: { $0.id == slotId }) else { return false }
        
        let screen = NSScreen.main ?? NSScreen.screens.first
        let sWidth = screen?.frame.width ?? 0
        let sHeight = screen?.frame.height ?? 0
        
        slots[index].windows = windows
        slots[index].updatedAt = Date()
        slots[index].screenWidth = Double(sWidth)
        slots[index].screenHeight = Double(sHeight)
        
        saveSlots()
        
        HUDOverlay.shared.show(message: hudMessage, icon: "tray.and.arrow.down.fill")
        return true
    }
    
    /// Saves a desktop's window list (captured by DesktopManager) into a slot.
    @discardableResult
    public func saveDesktopWindows(_ windows: [SavedWindow], to slotId: Int, desktopLabel: String) -> Bool {
        storeWindows(
            windows,
            to: slotId,
            hudMessage: "\(desktopLabel) → Slot \(slotId) (\(windows.count) Windows)"
        )
    }
    
    /// ID of the first empty slot, or nil when all 8 are in use.
    public func firstEmptySlotID() -> Int? {
        slots.first(where: { $0.isEmpty })?.id
    }
    
    /// Captures the frames of all on-screen app windows via Accessibility.
    private func captureOnScreenWindows() -> [SavedWindow] {
        var capturedWindows: [SavedWindow] = []
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular &&
            $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        
        for app in apps {
            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windowList = windowsRef as? [AXUIElement] else {
                continue
            }
            
            for (winIdx, win) in windowList.enumerated() {
                // Verify window role
                var roleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, kAXRoleAttribute as CFString, &roleRef) == .success,
                   let role = roleRef as? String, role != (kAXWindowRole as String) {
                    continue
                }
                
                // Skip minimized windows
                var minRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minRef) == .success,
                   let isMin = minRef as? Bool, isMin {
                    continue
                }
                
                guard let frame = WindowManager.shared.getWindowFrame(win),
                      frame.width > 80, frame.height > 80 else {
                    continue
                }
                
                let title = WindowManager.shared.getWindowTitle(win)
                let saved = SavedWindow(
                    bundleId: app.bundleIdentifier ?? "",
                    appName: app.localizedName ?? "App",
                    windowTitle: title,
                    x: Double(frame.origin.x),
                    y: Double(frame.origin.y),
                    width: Double(frame.size.width),
                    height: Double(frame.size.height),
                    windowIndex: winIdx
                )
                capturedWindows.append(saved)
            }
        }
        
        return capturedWindows
    }
    
    @discardableResult
    public func restoreLayout(from slotId: Int) -> Bool {
        guard AccessibilityManager.shared.isTrusted else {
            AccessibilityManager.shared.requestPermission()
            return false
        }
        
        guard let slot = slots.first(where: { $0.id == slotId }) else { return false }
        
        if slot.isEmpty {
            HUDOverlay.shared.show(message: "Slot \(slotId) is empty", icon: "exclamationmark.triangle")
            return false
        }
        
        var restoredCount = 0
        
        for savedWin in slot.windows {
            // Find running app
            let targetApp = NSWorkspace.shared.runningApplications.first {
                ($0.bundleIdentifier != nil && $0.bundleIdentifier == savedWin.bundleId) ||
                ($0.localizedName != nil && $0.localizedName == savedWin.appName)
            }
            
            // If app isn't running, attempt to launch it if enabled in Settings
            if targetApp == nil, !savedWin.bundleId.isEmpty, AppSettings.shared.autoLaunchClosedApps {
                if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: savedWin.bundleId) {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = false
                    NSWorkspace.shared.openApplication(at: appUrl, configuration: config) { app, _ in
                        if let app = app {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                self.applyFrame(savedWin: savedWin, to: app)
                            }
                        }
                    }
                    continue
                }
            }
            
            if let app = targetApp {
                if applyFrame(savedWin: savedWin, to: app) {
                    restoredCount += 1
                }
            }
        }
        
        HUDOverlay.shared.show(
            message: "⚡️ Slot \(slotId) Restored (\(slot.windows.count) Windows)",
            icon: "bolt.fill"
        )
        
        WindowManager.shared.refreshTargetWindow()
        DesktopManager.shared.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            WindowManager.shared.refreshTargetWindow()
            DesktopManager.shared.refresh()
        }
        
        if AppSettings.shared.hideWindowAfterRecall {
            DispatchQueue.main.async {
                AppDelegate.shared?.mainWindow?.orderOut(nil)
            }
        }
        return true
    }
    
    @discardableResult
    private func applyFrame(savedWin: SavedWindow, to app: NSRunningApplication) -> Bool {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windowList = windowsRef as? [AXUIElement], !windowList.isEmpty else {
            return false
        }
        
        // Target specific window by index if available, or first window
        let targetWin: AXUIElement = {
            if savedWin.windowIndex < windowList.count {
                return windowList[savedWin.windowIndex]
            }
            return windowList[0]
        }()
        
        // If minimized, unminimize it
        var isMinRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(targetWin, kAXMinimizedAttribute as CFString, &isMinRef) == .success,
           let isMin = isMinRef as? Bool, isMin {
            AXUIElementSetAttributeValue(targetWin, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        
        let frame = CGRect(x: savedWin.x, y: savedWin.y, width: savedWin.width, height: savedWin.height)
        WindowManager.shared.setWindowFrame(targetWin, frame: frame)
        return true
    }
    
    public func clearSlot(slotId: Int) {
        guard let index = slots.firstIndex(where: { $0.id == slotId }) else { return }
        slots[index].windows = []
        slots[index].updatedAt = nil
        slots[index].screenWidth = nil
        slots[index].screenHeight = nil
        saveSlots()
        HUDOverlay.shared.show(message: "Cleared Slot \(slotId)", icon: "trash")
    }
    
    public func renameSlot(slotId: Int, newName: String) {
        guard let index = slots.firstIndex(where: { $0.id == slotId }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        slots[index].name = trimmed.isEmpty ? "Slot \(slotId)" : trimmed
        saveSlots()
    }
    
    public func startEditing(slot: LayoutSlot) {
        editingSlotId = slot.id
        editingName = slot.name
    }
    
    public func commitEditing() {
        guard let id = editingSlotId else { return }
        renameSlot(slotId: id, newName: editingName)
        editingSlotId = nil
        editingName = ""
    }
    
    public func cancelEditing() {
        editingSlotId = nil
        editingName = ""
    }
}

import Cocoa
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public static var shared: AppDelegate?
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover = NSPopover()
    private var eventMonitor: Any?
    public var mainWindow: NSWindow?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Run as regular GUI app so Dock icon appears and window is visible
        NSApp.setActivationPolicy(.regular)
        
        if AppSettings.shared.showMenuBarIcon {
            setupStatusItem()
        }
        setupPopover()
        setupMainWindow()
        
        // Show main window on launch so user immediately sees the app
        showMainWindow()
        
        // Start services
        HotkeyManager.shared.registerHotkeys()
        AccessibilityManager.shared.checkPermission()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregisterHotkeys()
        AccessibilityManager.shared.stopPolling()
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }
    
    // MARK: - Main Dashboard Window
    
    public func setupMainWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1060, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 880, height: 620)
        window.center()
        window.title = "Slotr"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentViewController = NSHostingController(rootView: MainDashboardView())
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.mainWindow = window
    }
    
    @objc public func showMainWindow() {
        if mainWindow == nil {
            setupMainWindow()
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide window instead of quitting so background hotkeys and menu bar remain active
        sender.orderOut(nil)
        return false
    }
    
    // MARK: - Status Bar Item
    
    public func setStatusItemVisible(_ visible: Bool) {
        if visible {
            if statusItem == nil {
                setupStatusItem()
            }
        } else {
            closePopover(nil)
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }
    
    private func setupStatusItem() {
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Slotr") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "◧"
            }
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            togglePopover(sender)
        }
    }
    
    private func setupPopover() {
        popover.contentSize = NSSize(width: 340, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }
    
    public func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    public func showPopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        
        WindowManager.shared.refreshTargetWindow()
        
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover(nil)
        }
    }
    
    public func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "Slotr", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // Open Full Window
        menu.addItem(NSMenuItem(title: "Open Slotr Window...", action: #selector(showMainWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        
        // Recall Slots submenu
        let recallMenu = NSMenu()
        for i in 1...8 {
            let slot = SlotManager.shared.slot(for: i)
            let name = slot?.name ?? "Slot \(i)"
            let status = (slot?.isEmpty ?? true) ? " (Empty)" : ""
            let item = NSMenuItem(title: "Recall \(name)\(status)", action: #selector(contextRecallSlot(_:)), keyEquivalent: "\(i)")
            item.keyEquivalentModifierMask = [.control, .option]
            item.tag = i
            item.isEnabled = !(slot?.isEmpty ?? true)
            recallMenu.addItem(item)
        }
        let recallItem = NSMenuItem(title: "Recall Layout Slot", action: nil, keyEquivalent: "")
        recallItem.submenu = recallMenu
        menu.addItem(recallItem)
        
        // Save Slots submenu
        let saveMenu = NSMenu()
        for i in 1...8 {
            let slot = SlotManager.shared.slot(for: i)
            let name = slot?.name ?? "Slot \(i)"
            let item = NSMenuItem(title: "Save to \(name)", action: #selector(contextSaveSlot(_:)), keyEquivalent: "\(i)")
            item.keyEquivalentModifierMask = [.control, .option, .shift]
            item.tag = i
            saveMenu.addItem(item)
        }
        let saveItem = NSMenuItem(title: "Save Current Layout to Slot", action: nil, keyEquivalent: "")
        saveItem.submenu = saveMenu
        menu.addItem(saveItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check Accessibility Permission", action: #selector(checkAccessibility), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Slotr", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc private func contextRecallSlot(_ sender: NSMenuItem) {
        SlotManager.shared.restoreLayout(from: sender.tag)
    }
    
    @objc private func contextSaveSlot(_ sender: NSMenuItem) {
        SlotManager.shared.saveCurrentLayout(to: sender.tag)
    }
    
    @objc private func checkAccessibility() {
        AccessibilityManager.shared.requestPermission()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

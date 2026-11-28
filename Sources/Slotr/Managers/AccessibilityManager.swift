import Cocoa
import ApplicationServices

public class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()
    
    @Published public private(set) var isTrusted: Bool = AXIsProcessTrusted()
    
    private var pollTimer: Timer?
    private let distributedNotificationName = NSNotification.Name("com.apple.accessibility.api")
    
    private init() {
        checkPermission()
        startPolling()
        
        // Re-check immediately when switching back to Slotr from System Settings.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkPermission()
        }
        
        // Re-check immediately when macOS broadcasts an Accessibility TCC change.
        DistributedNotificationCenter.default().addObserver(
            forName: distributedNotificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.checkPermission()
            }
        }
    }
    
    deinit {
        stopPolling()
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    public func checkPermission() {
        let trusted = AXIsProcessTrusted()
        if Thread.isMainThread {
            if self.isTrusted != trusted {
                print("Slotr: accessibility trust state changed to \(trusted)")
                self.isTrusted = trusted
            }
        } else {
            DispatchQueue.main.async {
                if self.isTrusted != trusted {
                    print("Slotr: accessibility trust state changed to \(trusted)")
                    self.isTrusted = trusted
                }
            }
        }
    }
    
    public func requestPermission() {
        // Re-check first: if already granted, update state and avoid opening Settings.
        if AXIsProcessTrusted() {
            checkPermission()
            return
        }
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        // Also open System Settings directly to Privacy & Security > Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func startPolling() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPermission()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
    
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

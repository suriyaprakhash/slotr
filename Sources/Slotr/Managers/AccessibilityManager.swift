import Cocoa
import ApplicationServices

public class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()
    
    @Published public private(set) var isTrusted: Bool = false
    
    private var pollTimer: Timer?
    
    private init() {
        checkPermission()
        startPolling()
    }
    
    deinit {
        stopPolling()
    }
    
    public func checkPermission() {
        let trusted = AXIsProcessTrusted()
        if self.isTrusted != trusted {
            DispatchQueue.main.async {
                self.isTrusted = trusted
            }
        }
    }
    
    public func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        // Also open System Settings directly to Privacy & Security > Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkPermission()
        }
    }
    
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

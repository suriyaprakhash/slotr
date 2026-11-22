import Cocoa
import Carbon

public class HotkeyManager {
    public static let shared = HotkeyManager()
    
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    
    private init() {}
    
    public func registerHotkeys() {
        unregisterHotkeys()
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                guard let theEvent = theEvent, let userData = userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                let result = GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if result == noErr {
                    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                    manager.handleHotKey(id: Int(hotKeyID.id))
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )
        
        guard status == noErr else {
            print("Slotr: Failed to install event handler")
            return
        }
        
        // Keycodes for 1..8:
        let numberKeys: [(slot: Int, code: UInt32)] = [
            (1, 18), (2, 19), (3, 20), (4, 21),
            (5, 23), (6, 22), (7, 26), (8, 28)
        ]
        
        let ctrlOpt = UInt32(controlKey | optionKey)
        let ctrlOptShift = UInt32(controlKey | optionKey | shiftKey)
        
        // Register Slot Recall (⌃⌥1..8)
        for (slot, code) in numberKeys {
            registerKey(id: UInt32(100 + slot), keyCode: code, modifiers: ctrlOpt)
        }
        
        // Register Slot Save (⌃⌥⇧1..8)
        for (slot, code) in numberKeys {
            registerKey(id: UInt32(200 + slot), keyCode: code, modifiers: ctrlOptShift)
        }
        
        // Register Quick Snap Hotkeys:
        // Left Arrow (123) -> Left Half
        registerKey(id: 301, keyCode: 123, modifiers: ctrlOpt)
        // Right Arrow (124) -> Right Half
        registerKey(id: 302, keyCode: 124, modifiers: ctrlOpt)
        // Up Arrow (126) -> Maximize
        registerKey(id: 303, keyCode: 126, modifiers: ctrlOpt)
        // Down Arrow (125) -> Restore Original Size / Undo
        registerKey(id: 304, keyCode: 125, modifiers: ctrlOpt)
        // Return (36) -> Maximize
        registerKey(id: 305, keyCode: 36, modifiers: ctrlOpt)
        // C Key (8) -> Center Window
        registerKey(id: 306, keyCode: 8, modifiers: ctrlOpt)
    }
    
    private func registerKey(id: UInt32, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x534C5452), id: id) // 'SLTR'
        let err = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if err == noErr, let ref = hotKeyRef {
            hotKeyRefs.append(ref)
        }
    }
    
    public func unregisterHotkeys() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
    
    private func handleHotKey(id: Int) {
        DispatchQueue.main.async {
            switch id {
            case 101...108:
                let slotId = id - 100
                SlotManager.shared.restoreLayout(from: slotId)
                
            case 201...208:
                let slotId = id - 200
                SlotManager.shared.saveCurrentLayout(to: slotId)
                
            case 301:
                WindowManager.shared.snapActiveWindow(to: .leftHalf)
            case 302:
                WindowManager.shared.snapActiveWindow(to: .rightHalf)
            case 303:
                WindowManager.shared.snapActiveWindow(to: .maximize)
            case 304:
                WindowManager.shared.restoreOriginalWindowSize()
            case 305:
                WindowManager.shared.snapActiveWindow(to: .maximize)
            case 306:
                WindowManager.shared.snapActiveWindow(to: .center)
                
            default:
                break
            }
        }
    }
}

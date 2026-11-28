import Foundation

public enum WindowGapPadding: Int, CaseIterable, Identifiable {
    case flush = 0
    case subtle = 8
    case airy = 16
    
    public var id: Int { rawValue }
    
    public var label: String {
        switch self {
        case .flush: return "0 px (Flush)"
        case .subtle: return "8 px (Subtle)"
        case .airy: return "16 px (Airy)"
        }
    }
}

public class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    private enum Keys {
        static let showMenuBarIcon = "slotr_showMenuBarIcon"
        static let autoLaunchClosedApps = "slotr_autoLaunchClosedApps"
        static let hideWindowAfterRecall = "slotr_hideWindowAfterRecall"
        static let windowGapPadding = "slotr_windowGapPadding"
    }
    
    @Published public var showMenuBarIcon: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
        }
    }
    
    @Published public var autoLaunchClosedApps: Bool {
        didSet {
            UserDefaults.standard.set(autoLaunchClosedApps, forKey: Keys.autoLaunchClosedApps)
        }
    }
    
    @Published public var hideWindowAfterRecall: Bool {
        didSet {
            UserDefaults.standard.set(hideWindowAfterRecall, forKey: Keys.hideWindowAfterRecall)
        }
    }
    
    @Published public var windowGapPadding: WindowGapPadding {
        didSet {
            UserDefaults.standard.set(windowGapPadding.rawValue, forKey: Keys.windowGapPadding)
        }
    }
    
    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.showMenuBarIcon) == nil {
            defaults.set(true, forKey: Keys.showMenuBarIcon)
        }
        if defaults.object(forKey: Keys.autoLaunchClosedApps) == nil {
            defaults.set(true, forKey: Keys.autoLaunchClosedApps)
        }
        if defaults.object(forKey: Keys.hideWindowAfterRecall) == nil {
            defaults.set(true, forKey: Keys.hideWindowAfterRecall)
        }
        if defaults.object(forKey: Keys.windowGapPadding) == nil {
            defaults.set(WindowGapPadding.subtle.rawValue, forKey: Keys.windowGapPadding)
        }
        
        self.showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
        self.autoLaunchClosedApps = defaults.bool(forKey: Keys.autoLaunchClosedApps)
        self.hideWindowAfterRecall = defaults.bool(forKey: Keys.hideWindowAfterRecall)
        let rawGap = defaults.integer(forKey: Keys.windowGapPadding)
        self.windowGapPadding = WindowGapPadding(rawValue: rawGap) ?? .subtle
    }
}

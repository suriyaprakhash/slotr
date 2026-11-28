import Foundation

public struct SavedWindow: Codable, Identifiable, Hashable {
    public var id: String { "\(bundleId)_\(windowIndex)_\(Int(x))_\(Int(y))" }
    public var bundleId: String
    public var appName: String
    public var windowTitle: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var windowIndex: Int
    
    public init(bundleId: String, appName: String, windowTitle: String, x: Double, y: Double, width: Double, height: Double, windowIndex: Int) {
        self.bundleId = bundleId
        self.appName = appName
        self.windowTitle = windowTitle
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.windowIndex = windowIndex
    }
}

public struct LayoutSlot: Codable, Identifiable {
    public var id: Int
    public var name: String
    public var updatedAt: Date?
    public var windows: [SavedWindow]
    public var screenWidth: Double?
    public var screenHeight: Double?
    
    public var isEmpty: Bool {
        windows.isEmpty
    }
    
    public var formattedDate: String {
        guard let date = updatedAt else { return "Empty" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    public var appSummary: String {
        guard !windows.isEmpty else { return "No apps saved" }
        let uniqueApps = Array(Set(windows.map { $0.appName })).prefix(4)
        var summary = uniqueApps.joined(separator: ", ")
        if windows.count > uniqueApps.count {
            summary += " (+\(windows.count - uniqueApps.count))"
        }
        return summary
    }
    
    public init(id: Int, name: String? = nil, updatedAt: Date? = nil, windows: [SavedWindow] = [], screenWidth: Double? = nil, screenHeight: Double? = nil) {
        self.id = id
        self.name = name ?? "Slot \(id)"
        self.updatedAt = updatedAt
        self.windows = windows
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
    }
}

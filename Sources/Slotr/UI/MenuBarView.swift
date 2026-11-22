import SwiftUI
import ServiceManagement

public enum MenuBarTab: String, CaseIterable, Identifiable {
    case slots = "Slots (8)"
    case snap = "Snap Grid"
    case shortcuts = "Shortcuts"
    
    public var id: String { rawValue }
}

public class MenuBarViewModel: ObservableObject {
    public static let shared = MenuBarViewModel()
    
    @Published public var selectedTab: MenuBarTab = .slots
    @Published public var launchAtLogin: Bool = UserDefaults.standard.bool(forKey: "launchAtLogin")
    
    private init() {}
    
    public func toggleLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Slotr: Failed to update launch at login: \(error)")
            }
        }
    }
}

public struct MenuBarView: View {
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    @ObservedObject var windowManager = WindowManager.shared
    @ObservedObject var slotManager = SlotManager.shared
    @ObservedObject var viewModel = MenuBarViewModel.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerView
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)
            
            Divider()
            
            // Target Window Info Banner
            targetWindowBanner
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            
            Divider()
            
            // Tab Selector
            Picker("", selection: $viewModel.selectedTab) {
                ForEach(MenuBarTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            // Tab Content
            ScrollView {
                VStack(spacing: 12) {
                    switch viewModel.selectedTab {
                    case .slots:
                        slotsTabView
                    case .snap:
                        snapTabView
                    case .shortcuts:
                        shortcutsTabView
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: 460)
            
            Divider()
            
            // Footer
            footerView
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(width: 380)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            windowManager.refreshTargetWindow()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Slotr")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("v1.0")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                }
                Text("Window Snapping & 8 Layout Slots")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                AppDelegate.shared?.showMainWindow()
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right.square")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Open Full Dashboard Window")
            
            // Accessibility Status Indicator
            if accessibilityManager.isTrusted {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("Active")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            } else {
                Button(action: {
                    accessibilityManager.requestPermission()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Text("Grant Permission")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Target Window Banner
    
    private var targetWindowBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "macwindow")
                .font(.system(size: 13))
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 1) {
                if let target = windowManager.targetWindowDetails {
                    HStack(spacing: 4) {
                        Text(target.appName)
                            .font(.system(size: 11, weight: .semibold))
                        if !target.title.isEmpty {
                            Text("— \(target.title)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        if let zone = target.lastZone {
                            Text("Snapped: \(zone.title)")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(.blue)
                        } else {
                            Text("Unsnapped")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("(\(Int(target.frame.width))×\(Int(target.frame.height)))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No active target window selected")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Click any window, then open Slotr")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            
            Spacer()
            
            if let target = windowManager.targetWindowDetails, target.isSnapped {
                Button(action: {
                    windowManager.restoreOriginalWindowSize()
                }) {
                    Text("Undo")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Restore to pre-snap size")
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }
    
    // MARK: - Slots Tab
    
    private var slotsTabView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Saved Workspace Slots")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Click Recall to restore instantly")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
            
            // 8 Slots
            ForEach(slotManager.slots) { slot in
                SlotCardView(slot: slot)
            }
        }
    }
    
    // MARK: - Snap Tab
    
    private var snapTabView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Snap Target Window")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            
            SnapGridButtons()
        }
    }
    
    // MARK: - Shortcuts Tab
    
    private var shortcutsTabView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Global Hotkeys")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 6) {
                shortcutRow(title: "Recall Slot 1 to 8", key: "⌃ ⌥ 1..8")
                shortcutRow(title: "Save Layout to Slot 1 to 8", key: "⌃ ⌥ ⇧ 1..8")
                shortcutRow(title: "Snap Left Half", key: "⌃ ⌥ ←")
                shortcutRow(title: "Snap Right Half", key: "⌃ ⌥ →")
                shortcutRow(title: "Maximize Window", key: "⌃ ⌥ ↑ / ↩")
                shortcutRow(title: "Restore Original Size", key: "⌃ ⌥ ↓")
                shortcutRow(title: "Center Window", key: "⌃ ⌥ C")
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            Text("Tip: Clicking the same snap button twice toggles the window back to its original size!")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    private func shortcutRow(title: String, key: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium))
            Spacer()
            Text(key)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(4)
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { viewModel.launchAtLogin },
                set: { viewModel.toggleLaunchAtLogin($0) }
            )) {
                Text("Launch at Login")
                    .font(.system(size: 10.5))
            }
            .toggleStyle(.checkbox)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 10.5))
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
    }
}

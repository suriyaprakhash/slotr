import SwiftUI
import ApplicationServices

public struct MainDashboardView: View {
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    @ObservedObject var windowManager = WindowManager.shared
    @ObservedObject var slotManager = SlotManager.shared
    @ObservedObject var desktopManager = DesktopManager.shared
    @ObservedObject var viewModel = MenuBarViewModel.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Header Bar
            headerView
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main Content Area (Two Columns)
            HStack(alignment: .top, spacing: 18) {
                // Left Column: Target Window & Quick Snapping
                VStack(alignment: .leading, spacing: 14) {
                    targetWindowSection
                    
                    Text("Snap Active Window")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    SnapGridButtons()
                    
                    Spacer()
                    
                    shortcutsLegend
                }
                .frame(width: 290)
                
                Divider()
                
                // Right Column: Current Desktops + 8 Layout Slots Grid
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Desktops")
                                .font(.system(size: 14, weight: .bold))
                            Text("Apps running on each Space. Slot a desktop into a preset in one click.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Horizontally scrollable row of desktop cards
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            if desktopManager.desktops.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.on.square")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Text(desktopManager.isAvailable
                                         ? "Detecting Desktops…"
                                         : "Desktop Detection Unavailable")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 26)
                            } else {
                                ForEach(desktopManager.desktops) { desktop in
                                    DesktopCardView(desktop: desktop)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("8 Workspace Layout Slots")
                                .font(.system(size: 14, weight: .bold))
                            Text("Capture all on-screen apps and restore them instantaneously.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // 2-Column Grid of the 8 Slots
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(slotManager.slots) { slot in
                                SlotCardView(slot: slot)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(18)
            
            Divider()
            
            // Bottom Status / Footer Bar
            footerView
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 780, minHeight: 660)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            windowManager.refreshTargetWindow()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // App Icon & Name
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 36, height: 36)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Slotr")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("v1.0")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                }
                Text("Window Snapping & Instant 8-Slot Layout Presets")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Accessibility Status Banner
            if accessibilityManager.isTrusted {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Accessibility Active")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.12))
                .cornerRadius(12)
            } else {
                VStack(alignment: .trailing, spacing: 3) {
                    Button(action: {
                        // Re-check first (synchronously): the user may have just
                        // granted access in System Settings.
                        if AXIsProcessTrusted() {
                            accessibilityManager.checkPermission()
                        } else {
                            accessibilityManager.requestPermission()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            Text("Grant Accessibility Permission")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.18))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Text("Enable \"Slotr\" in Privacy & Security → Accessibility")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help("Turn on Slotr in System Settings → Privacy & Security → Accessibility.\n\nNote: multiple local builds can appear as separate \"Slotr\" entries — enable the one for this build:\n\(Bundle.main.bundlePath)")
                }
            }
        }
    }
    
    // MARK: - Target Window
    
    private var targetWindowSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Target Window")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Image(systemName: "macwindow")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    if let target = windowManager.targetWindowDetails {
                        Text(target.appName)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        if !target.title.isEmpty {
                            Text(target.title)
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        HStack(spacing: 6) {
                            if let zone = target.lastZone {
                                Text("Snapped: \(zone.title)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.blue)
                            } else {
                                Text("Unsnapped")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Text("(\(Int(target.frame.width))×\(Int(target.frame.height)))")
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No external window focused")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Click any app window to target it")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                
                Spacer()
                
                if let target = windowManager.targetWindowDetails, target.isSnapped {
                    Button(action: {
                        windowManager.restoreOriginalWindowSize()
                    }) {
                        Text("Undo")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Shortcuts Legend
    
    private var shortcutsLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Global Shortcuts")
                .font(.system(size: 11.5, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                legendRow(name: "Recall Slots 1..8", keys: "⌃⌥1..8")
                legendRow(name: "Save Slots 1..8", keys: "⌃⌥⇧1..8")
                legendRow(name: "Left / Right Half", keys: "⌃⌥← / →")
                legendRow(name: "Maximize", keys: "⌃⌥↑ / ↩")
                legendRow(name: "Restore Original Size", keys: "⌃⌥↓")
            }
            .padding(8)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(7)
        }
    }
    
    private func legendRow(name: String, keys: String) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 10.5))
            Spacer()
            Text(keys)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { viewModel.launchAtLogin },
                set: { viewModel.toggleLaunchAtLogin($0) }
            )) {
                Text("Launch Slotr at login")
                    .font(.system(size: 11))
            }
            .toggleStyle(.checkbox)
            
            Spacer()
            
            Text("Slotr also runs in your Menu Bar for quick access.")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Hide Window") {
                NSApp.keyWindow?.orderOut(nil)
            }
            .font(.system(size: 11))
        }
    }
}

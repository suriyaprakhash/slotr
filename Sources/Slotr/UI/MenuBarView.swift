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
    @Published public var hoveredSlotId: Int? = nil
    
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
    var isPreview: Bool = false
    var onClosePreview: (() -> Void)? = nil
    
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    @ObservedObject var windowManager = WindowManager.shared
    @ObservedObject var slotManager = SlotManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    public init(isPreview: Bool = false, onClosePreview: (() -> Void)? = nil) {
        self.isPreview = isPreview
        self.onClosePreview = onClosePreview
    }
    
    private var populatedSlots: [LayoutSlot] {
        slotManager.slots.filter { !$0.isEmpty }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(accessibilityManager.isTrusted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text("Slotr Quick Menu")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                if !isPreview {
                    Button(action: {
                        AppDelegate.shared?.closePopover(nil)
                        AppDelegate.shared?.showMainWindow()
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right.square")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open Full Dashboard")
                }
                
                if let onClosePreview {
                    Button(action: onClosePreview) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            
            Divider()
            
            // Saved Workspaces Section
            VStack(alignment: .leading, spacing: 6) {
                Text("SAVED WORKSPACES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                if populatedSlots.isEmpty {
                    HStack {
                        Text("No saved workspaces yet")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Save Slot 1") {
                            slotManager.saveCurrentLayout(to: 1)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .buttonStyle(.plain)
                        .foregroundColor(.slotrBlue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.slotrSubtleSurface(colorScheme))
                    )
                } else {
                    VStack(spacing: 2) {
                        ForEach(populatedSlots) { slot in
                            MenuBarSlotRow(slot: slot) {
                                slotManager.restoreLayout(from: slot.id)
                                if !isPreview {
                                    AppDelegate.shared?.closePopover(nil)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
            
            Divider()
            
            // Quick Snap Active Window Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("QUICK SNAP ACTIVE WINDOW")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let target = windowManager.targetWindowDetails {
                        Text(target.appName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                HStack(spacing: 6) {
                    quickSnapButton(title: "Left", zone: .leftHalf)
                    quickSnapButton(title: "Right", zone: .rightHalf)
                    quickSnapButton(title: "Center", zone: .center)
                    quickSnapButton(title: "Max", zone: .maximize)
                }
                
                if let target = windowManager.targetWindowDetails, target.isSnapped {
                    Button(action: {
                        windowManager.restoreOriginalWindowSize()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                            Text("Restore Original Size")
                                .font(.system(size: 11, weight: .medium))
                            Spacer()
                            Text("⌃⌥↓")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.slotrBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.slotrBlue.opacity(0.10))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            Divider()
            
            // Footer Actions
            HStack {
                Button(action: captureCurrentSpaceAction) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Capture Current Space")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundColor(.slotrBlue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if !accessibilityManager.isTrusted {
                    Button("Grant Access") {
                        accessibilityManager.requestPermission()
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
                    .buttonStyle(.plain)
                } else if !isPreview {
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 332)
        .background(Color.slotrCardBg(colorScheme))
        .onAppear {
            accessibilityManager.checkPermission()
            windowManager.refreshTargetWindow()
        }
    }
    
    private func quickSnapButton(title: String, zone: SnapZone) -> some View {
        Button(action: {
            windowManager.snapActiveWindow(to: zone)
        }) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.slotrSubtleSurface(colorScheme))
                )
        }
        .buttonStyle(.plain)
    }
    
    private func captureCurrentSpaceAction() {
        if let emptyId = slotManager.firstEmptySlotID() {
            slotManager.saveCurrentLayout(to: emptyId)
        } else {
            if !isPreview {
                AppDelegate.shared?.closePopover(nil)
            }
            AppDelegate.shared?.showMainWindow()
            HUDOverlay.shared.show(message: "All 8 Slots Are In Use", icon: "exclamationmark.triangle")
        }
    }
}

private struct MenuBarSlotRow: View {
    let slot: LayoutSlot
    let onRecall: () -> Void
    
    @ObservedObject private var viewModel = MenuBarViewModel.shared
    @Environment(\.colorScheme) private var colorScheme
    
    private var isHovered: Bool {
        viewModel.hoveredSlotId == slot.id
    }
    
    var body: some View {
        Button(action: onRecall) {
            HStack(spacing: 8) {
                Text("\(slot.id)")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.slotrSubtleSurface(colorScheme))
                    )
                
                Text(slot.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("⌃⌥\(slot.id)")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? Color.slotrBlue.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                viewModel.hoveredSlotId = slot.id
            } else if viewModel.hoveredSlotId == slot.id {
                viewModel.hoveredSlotId = nil
            }
        }
    }
}

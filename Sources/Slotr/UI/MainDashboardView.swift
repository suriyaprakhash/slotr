import SwiftUI
import ApplicationServices

public enum DashboardTab: String, CaseIterable, Identifiable {
    case workspaces = "Workspace"
    case quickSnap = "Quick Snap"
    case shortcuts = "Shortcuts"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .workspaces: return "square.grid.2x2.fill"
        case .quickSnap: return "rectangle.split.2x1"
        case .shortcuts: return "keyboard"
        case .settings: return "gearshape"
        }
    }
    
    var pageTitle: String {
        switch self {
        case .workspaces: return "Workspace"
        case .quickSnap: return "Quick Snap Studio"
        case .shortcuts: return "Global Shortcuts"
        case .settings: return "Settings"
        }
    }
    
    var pageSubtitle: String {
        switch self {
        case .workspaces: return "Capture desktops & restore layouts in one click"
        case .quickSnap: return "Click any zone to preview and snap window geometry"
        case .shortcuts: return "System-wide keyboard triggers for Slots & Snapping"
        case .settings: return "Startup, Menu Bar & Workspace recall preferences"
        }
    }
}

public class DashboardViewModel: ObservableObject {
    public static let shared = DashboardViewModel()
    
    @Published public var selectedTab: DashboardTab = .workspaces
    @Published public var selectedDesktopID: Int64? = nil
    @Published public var selectedFilmWindowID: CGWindowID? = nil
    @Published public var filmRollSelectedOnly: Bool = true
    @Published public var hoveredSnapZone: SnapZone? = nil
    @Published public var hoveredCardZone: SnapZone? = nil
    @Published public var stageSnapZone: SnapZone = .leftHalf
    @Published public var slotSearchText: String = ""
    
    private init() {}
}

public struct MainDashboardView: View {
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    @ObservedObject var windowManager = WindowManager.shared
    @ObservedObject var slotManager = SlotManager.shared
    @ObservedObject var desktopManager = DesktopManager.shared
    @ObservedObject var viewModel = MenuBarViewModel.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var dashboardVM = DashboardViewModel.shared
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    private var filledSlotCount: Int {
        slotManager.slots.filter { !$0.isEmpty }.count
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var selectedDesktop: DesktopInfo? {
        if let id = dashboardVM.selectedDesktopID,
           let match = desktopManager.desktops.first(where: { $0.id == id }) {
            return match
        }
        return desktopManager.desktops.first(where: { $0.isCurrent }) ?? desktopManager.desktops.first
    }

    private var selectedDesktopPosition: Int? {
        guard let selectedDesktop else { return nil }
        return desktopManager.desktops.firstIndex(where: { $0.id == selectedDesktop.id })
    }

    private var filteredSlots: [LayoutSlot] {
        let query = dashboardVM.slotSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedSlots = slotManager.slots.filter { !$0.isEmpty }
        guard !query.isEmpty else { return savedSlots }
        return savedSlots.filter { slot in
            slot.name.localizedCaseInsensitiveContains(query)
                || slot.windows.contains { $0.appName.localizedCaseInsensitiveContains(query) }
        }
    }
    
    private var allDesktopWindows: [(window: DesktopWindow, spaceOrdinal: Int, displayBounds: CGRect)] {
        desktopManager.desktops.flatMap { desktop in
            desktop.windows.map { (window: $0, spaceOrdinal: desktop.index + 1, displayBounds: desktop.displayBounds) }
        }
    }
    
    private var filteredFilmWindows: [(window: DesktopWindow, spaceOrdinal: Int, displayBounds: CGRect)] {
        if dashboardVM.filmRollSelectedOnly, let selected = selectedDesktop {
            return selected.windows.map { (window: $0, spaceOrdinal: selected.index + 1, displayBounds: selected.displayBounds) }
        }
        return allDesktopWindows
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            sidebarView
                .frame(width: 300)
                .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
            
            Rectangle()
                .fill(Color.slotrBorder(colorScheme))
                .frame(width: 1)
            
            mainContentView
                .background(Color.slotrMainBg(colorScheme))
        }
        .frame(minWidth: 880, minHeight: 620)
        .onAppear {
            accessibilityManager.checkPermission()
            windowManager.refreshTargetWindow()
            if dashboardVM.selectedDesktopID == nil {
                dashboardVM.selectedDesktopID = desktopManager.desktops.first(where: { $0.isCurrent })?.id
                    ?? desktopManager.desktops.first?.id
            }
        }
        .onChange(of: desktopManager.desktops) { newDesktops in
            if dashboardVM.selectedDesktopID == nil || !newDesktops.contains(where: { $0.id == dashboardVM.selectedDesktopID }) {
                dashboardVM.selectedDesktopID = newDesktops.first(where: { $0.isCurrent })?.id ?? newDesktops.first?.id
            }
        }
        .onChange(of: windowManager.targetWindowDetails?.lastZone) { zone in
            if let zone {
                dashboardVM.stageSnapZone = zone
            }
        }
    }
    
    // MARK: - Left Sidebar
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // App Identity Header
            HStack(spacing: 10) {
                SlotrLogoMark(size: 36)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Slotr")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Spaces & Window Snap")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 4)
            
            // Sidebar Navigation
            VStack(spacing: 3) {
                ForEach([DashboardTab.workspaces]) { tab in
                    sidebarNavButton(for: tab)
                }
            }
            
            if dashboardVM.selectedTab == .workspaces {
                savedLayoutsSidebar
            } else {
                Spacer(minLength: 10)
            }
            
            // Accessibility Status Banner
            accessibilityFooterCard
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
    
    private func sidebarNavButton(for tab: DashboardTab) -> some View {
        let isSelected = dashboardVM.selectedTab == tab
        return Button(action: {
            dashboardVM.selectedTab = tab
        }) {
            HStack(spacing: 9) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .slotrBlue)
                    .frame(width: 18)
                
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if tab == .workspaces {
                    Text("\(filledSlotCount) Saved")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.22) : Color.slotrSubtleSurface(colorScheme))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.slotrBlue : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var savedLayoutsSidebar: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text("SAVED LAYOUTS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.45)
                    .foregroundColor(.secondary)
                Text("\(filledSlotCount)")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.slotrSubtleSurface(colorScheme)))
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("Search layouts or apps…", text: $dashboardVM.slotSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !dashboardVM.slotSearchText.isEmpty {
                    Button {
                        dashboardVM.slotSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.slotrSubtleSurface(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
            )

            ScrollView {
                LazyVStack(spacing: 7) {
                    if filteredSlots.isEmpty {
                        Text(dashboardVM.slotSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             ? "No saved layouts yet. Save a desktop to add one."
                             : "No layouts match your search.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(filteredSlots) { slot in
                            savedLayoutSidebarRow(slot)
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func savedLayoutSidebarRow(_ slot: LayoutSlot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))
                    .help("Drag to reorder")

                if !slot.isEmpty {
                    MiniLayoutPreview(
                        frames: slot.windows.map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) },
                        referenceSize: slotReferenceSize(for: slot),
                        variant: slot.id,
                        cornerRadius: 5
                    )
                    .frame(width: 40, height: 28)
                } else {
                    Text("\(slot.id)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.slotrSubtleSurface(colorScheme))
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Group {
                        if slotManager.editingSlotId == slot.id {
                            TextField("Layout name", text: $slotManager.editingName, onCommit: {
                                slotManager.commitEditing()
                            })
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                        } else {
                            Text(slot.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .onTapGesture(count: 2) {
                                    slotManager.startEditing(slot: slot)
                                }
                        }
                    }
                    HStack(spacing: 4) {
                        if !slot.isEmpty {
                            ForEach(Array(slot.windows.prefix(3).enumerated()), id: \.offset) { _, window in
                                Image(nsImage: desktopManager.icon(bundleId: window.bundleId, appName: window.appName))
                                    .resizable()
                                    .frame(width: 13, height: 13)
                                    .cornerRadius(3)
                                    .help(window.appName)
                            }
                        }
                        Text(slot.isEmpty ? "Empty preset" : "\(slot.windows.count) windows")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        if slot.id <= 8 {
                            MacKeycapBadge("⌃⌥\(slot.id)", compact: true)
                        }
                    }
                }

                Spacer(minLength: 2)

                Button {
                    if slot.isEmpty {
                        saveSelectedDesktop(to: slot)
                    } else {
                        slotManager.restoreLayout(from: slot.id)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: slot.isEmpty ? "square.and.arrow.down" : "bolt.fill")
                            .font(.system(size: 9, weight: .semibold))
                        Text(slot.isEmpty ? "Save" : "Recall")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(slot.isEmpty ? .primary : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(slot.isEmpty ? Color.slotrSubtleSurface(colorScheme) : Color.slotrBlue)
                    )
                }
                .buttonStyle(.plain)
                .help(slot.isEmpty ? "Save selected desktop to Slot \(slot.id)" : "Recall Slot \(slot.id)")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.slotrCardBg(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(slot.isEmpty ? Color.slotrBorder(colorScheme) : Color.slotrBlue.opacity(0.35), lineWidth: 1)
        )
        .contextMenu {
            Button("Rename Layout") {
                slotManager.startEditing(slot: slot)
            }
            Button(slot.isEmpty ? "Save Selected Desktop" : "Overwrite with Selected Desktop") {
                saveSelectedDesktop(to: slot)
            }
            if !slot.isEmpty {
                Button("Recall Layout") {
                    slotManager.restoreLayout(from: slot.id)
                }
                Button("Clear Layout", role: .destructive) {
                    slotManager.clearSlot(slotId: slot.id)
                }
            }
        }
        .draggable(String(slot.id))
        .dropDestination(for: String.self) { draggedIDs, _ in
            guard let draggedID = draggedIDs.first.flatMap(Int.init) else { return false }
            return slotManager.moveSlot(id: draggedID, before: slot.id)
        }
    }

    private func slotReferenceSize(for slot: LayoutSlot) -> CGSize? {
        guard let width = slot.screenWidth, let height = slot.screenHeight,
              width > 100, height > 100 else { return nil }
        return CGSize(width: width, height: height)
    }

    private func saveSelectedDesktop(to slot: LayoutSlot) {
        if let desktop = selectedDesktop, !desktop.isEmpty {
            desktopManager.saveDesktop(desktop, toSlotId: slot.id)
        } else {
            slotManager.saveCurrentLayout(to: slot.id)
        }
    }

    private func saveSelectedDesktopAsNewLayout() {
        guard let slotID = slotManager.nextSlotID() else {
            HUDOverlay.shared.show(message: "Unable to create another workspace", icon: "exclamationmark.triangle")
            return
        }
        if let desktop = selectedDesktop, !desktop.isEmpty {
            desktopManager.saveDesktop(desktop, toSlotId: slotID)
        } else {
            slotManager.saveCurrentLayout(to: slotID)
        }
    }
    
    // MARK: - Target Window Inspector Card (Sidebar)
    
    private var targetWindowInspectorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("TARGET\nWINDOW")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.4)
                    .foregroundColor(.secondary)
                    .lineSpacing(1)
                
                Spacer()
                
                if let activeDesktop = desktopManager.desktops.first(where: { $0.isCurrent }) ?? selectedDesktop {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.slotrBlue)
                            .frame(width: 5.5, height: 5.5)
                        Text(activeDesktop.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.slotrBlue)
                            .lineLimit(1)
                    }
                }
            }
            
            HStack(spacing: 9) {
                if let target = windowManager.targetWindowDetails {
                    Image(nsImage: desktopManager.icon(bundleId: target.bundleId, appName: target.appName))
                        .resizable()
                        .frame(width: 30, height: 30)
                        .cornerRadius(7)
                    
                    VStack(alignment: .leading, spacing: 1.5) {
                        HStack(spacing: 4) {
                            Text(target.appName)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            
                            if target.isSnapped {
                                Button(action: {
                                    windowManager.restoreOriginalWindowSize()
                                }) {
                                    Text("Undo")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.slotrBlue)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.slotrBlue.opacity(0.12))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Text(target.title.isEmpty ? "Active Window" : target.title)
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text("\(Int(target.frame.width)) × \(Int(target.frame.height))")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.85))
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.slotrBlue.opacity(0.12))
                        Image(systemName: "macwindow")
                            .font(.system(size: 14))
                            .foregroundColor(.slotrBlue)
                    }
                    .frame(width: 30, height: 30)
                    
                    VStack(alignment: .leading, spacing: 1.5) {
                        Text("No Target Window")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Click any app window")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 4 Quick Snap Mini Buttons
            HStack(spacing: 6) {
                miniInspectorSnapButton(zone: .leftHalf, help: "Snap Left Half (⌃⌥←)")
                miniInspectorSnapButton(zone: .rightHalf, help: "Snap Right Half (⌃⌥→)")
                miniInspectorSnapButton(zone: .center, help: "Center Window (⌃⌥C)")
                miniInspectorSnapButton(zone: .maximize, help: "Maximize Window (⌃⌥↩)")
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.slotrCardBg(colorScheme).opacity(colorScheme == .dark ? 0.65 : 0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
        )
    }
    
    private func miniInspectorSnapButton(zone: SnapZone, help: String) -> some View {
        Button(action: {
            windowManager.snapActiveWindow(to: zone)
        }) {
            SnapZoneDiagram(
                zone: zone,
                width: 16,
                height: 12,
                isActive: windowManager.targetWindowDetails?.lastZone == zone
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.slotrSubtleSurface(colorScheme))
            )
        }
        .buttonStyle(.plain)
        .help(help)
    }
    
    // MARK: - Accessibility Footer Card
    
    private var accessibilityFooterCard: some View {
        Group {
            if accessibilityManager.isTrusted {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Accessibility Active")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .green : Color(red: 0.08, green: 0.45, blue: 0.18))
                        Text("Window snapping ready")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.green.opacity(colorScheme == .dark ? 0.14 : 0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.green.opacity(0.32), lineWidth: 1)
                )
            } else {
                Button(action: {
                    accessibilityManager.requestPermission()
                }) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Grant Accessibility")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .orange : Color(red: 0.68, green: 0.34, blue: 0.02))
                            Text("Enable Slotr in System Settings")
                                .font(.system(size: 10))
                                .foregroundColor(colorScheme == .dark ? .orange.opacity(0.8) : Color(red: 0.68, green: 0.34, blue: 0.02).opacity(0.8))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orange.opacity(colorScheme == .dark ? 0.16 : 0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.orange.opacity(0.32), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Turn on Slotr in System Settings → Privacy & Security → Accessibility.\n\nBuild path: \(Bundle.main.bundlePath)")
            }
        }
    }
    
    // MARK: - Main Content Area
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            topToolbar
            
            Rectangle()
                .fill(Color.slotrBorder(colorScheme))
                .frame(height: 1)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch dashboardVM.selectedTab {
                    case .workspaces:
                        workspacesTabContent
                    case .quickSnap:
                        quickSnapTabContent
                    case .shortcuts:
                        shortcutsTabContent
                    case .settings:
                        settingsTabContent
                    }
                }
                .padding(20)
            }
        }
    }
    
    private var topToolbar: some View {
        HStack(spacing: 8) {
            Text(dashboardVM.selectedTab.pageTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)

            if dashboardVM.selectedTab == .workspaces, let desktop = selectedDesktop {
                Text(desktopPositionLabel(desktop))
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()

            toolbarTabButton(.shortcuts)
            toolbarTabButton(.settings)
            
            Button(action: {
                NSApp.appearance = NSAppearance(named: colorScheme == .dark ? .aqua : .darkAqua)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: colorScheme == .dark ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.slotrSkyDeep)
                    Text(colorScheme == .dark ? "Light" : "Dark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.slotrCardBg(colorScheme))
                )
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.slotrBorder(colorScheme), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    private func toolbarTabButton(_ tab: DashboardTab) -> some View {
        Button {
            dashboardVM.selectedTab = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.slotrBlue)
                Text(tab.rawValue)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.slotrCardBg(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tab 1: Workspaces & Live Spaces
    
    private var workspacesTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            activeDesktopStageSection
            targetWindowsFilmRollSection
            workspaceSnapSection
        }
    }
    
    private var activeDesktopStageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(selectedDesktop?.isCurrent == true ? Color.slotrBlue : Color.green)
                            .frame(width: 6, height: 6)
                        Text(selectedDesktop.map(desktopPositionLabel) ?? "Finding desktops…")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }
                    Text("\(selectedDesktop?.windows.count ?? 0) windows · Click any window below to target")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 7) {
                    Button {
                        if let selectedDesktop {
                            desktopManager.switchToDesktop(selectedDesktop)
                        }
                    } label: {
                        Label("View", systemImage: "eye")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.slotrSubtleSurface(colorScheme))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedDesktop == nil)
                    .help("Switch to this macOS desktop")

                    Button(action: saveSelectedDesktopAsNewLayout) {
                        Label("Slot", systemImage: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.slotrBlue)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Save this desktop as a new slot")
                }
            }

            HStack(spacing: 10) {
                desktopStageArrow(direction: .leading)
                    .disabled((selectedDesktopPosition ?? 0) <= 0)
                    .opacity((selectedDesktopPosition ?? 0) <= 0 ? 0.45 : 1)

                Group {
                    if let desktop = selectedDesktop {
                        MiniLayoutPreview(
                            frames: desktop.windows.map(\.frame),
                            referenceBounds: desktop.displayBounds,
                            variant: desktop.index,
                            cornerRadius: 8
                        )
                    } else {
                        ZStack {
                            Color.slotrSubtleSurface(colorScheme)
                            Text(desktopManager.isAvailable ? "No desktop available" : "Desktop detection unavailable")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 214)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
                )

                desktopStageArrow(direction: .trailing)
                    .disabled((selectedDesktopPosition ?? -1) >= desktopManager.desktops.count - 1)
                    .opacity((selectedDesktopPosition ?? -1) >= desktopManager.desktops.count - 1 ? 0.45 : 1)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.slotrCardBg(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
        )
    }

    private func desktopStageArrow(direction: HorizontalEdge) -> some View {
        Button {
            selectAdjacentDesktop(direction == .leading ? -1 : 1)
        } label: {
            Image(systemName: direction == .leading ? "chevron.left" : "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 36, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.slotrSubtleSurface(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(direction == .leading ? "Previous desktop" : "Next desktop")
    }

    private func selectAdjacentDesktop(_ offset: Int) {
        guard let currentPosition = selectedDesktopPosition else { return }
        let nextPosition = currentPosition + offset
        guard desktopManager.desktops.indices.contains(nextPosition) else { return }
        let nextDesktop = desktopManager.desktops[nextPosition]
        withAnimation(.easeInOut(duration: 0.25)) {
            dashboardVM.selectedDesktopID = nextDesktop.id
        }
    }

    private func desktopPositionLabel(_ desktop: DesktopInfo) -> String {
        let displayLabel = desktop.isMultiDisplay ? " · Display \(desktop.displayIndex + 1)" : ""
        return "Desktop \(desktop.index + 1) of \(desktopManager.desktops.count)\(displayLabel)"
    }
    
    private var targetWindowsFilmRollSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollViewReader { proxy in
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Text("Target Windows Film Roll")
                            .font(.system(size: 13.5, weight: .semibold))
                        
                        Text("\(filteredFilmWindows.count) Windows")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.slotrSubtleSurface(colorScheme))
                            .cornerRadius(99)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // This Desktop vs All Spaces segmented pill
                        HStack(spacing: 2) {
                            filterSegmentButton(title: "This Desktop", active: dashboardVM.filmRollSelectedOnly) {
                                dashboardVM.filmRollSelectedOnly = true
                            }
                            filterSegmentButton(title: "All Spaces", active: !dashboardVM.filmRollSelectedOnly) {
                                dashboardVM.filmRollSelectedOnly = false
                            }
                        }
                        .padding(3)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.slotrSubtleSurface(colorScheme))
                        )
                        
                        carouselStepButtons(
                            onPrev: {
                                if let first = filteredFilmWindows.first {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        proxy.scrollTo(first.window.id, anchor: .leading)
                                    }
                                }
                            },
                            onNext: {
                                if let last = filteredFilmWindows.last {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        proxy.scrollTo(last.window.id, anchor: .trailing)
                                    }
                                }
                            }
                        )
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        if filteredFilmWindows.isEmpty {
                            Text("No open windows found on this Space.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 18)
                                .padding(.horizontal, 12)
                        } else {
                            ForEach(filteredFilmWindows, id: \.window.id) { item in
                                TargetWindowFilmCardView(
                                    window: item.window,
                                    spaceOrdinal: item.spaceOrdinal,
                                    displayBounds: item.displayBounds,
                                    isSelected: isFilmWindowSelected(item.window),
                                    onSelect: {
                                        dashboardVM.selectedFilmWindowID = item.window.id
                                        desktopManager.selectTargetWindow(item.window)
                                    }
                                )
                                .id(item.window.id)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private func isFilmWindowSelected(_ w: DesktopWindow) -> Bool {
        if let selectedFilmWindowID = dashboardVM.selectedFilmWindowID {
            return selectedFilmWindowID == w.id
        }
        if let target = windowManager.targetWindowDetails {
            return target.bundleId == w.bundleId && (target.title == w.windowName || target.title.isEmpty)
        }
        return false
    }

    private var workspaceSnapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Text("Snap & Tile Focused Window")
                    .font(.system(size: 12.5, weight: .semibold))
                if let target = windowManager.targetWindowDetails {
                    Text("\(target.appName) · Desktop \(selectedDesktop.map { $0.index + 1 } ?? 1)")
                        .font(.system(size: 10))
                        .foregroundColor(.slotrBlue)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.slotrBlue.opacity(colorScheme == .dark ? 0.18 : 0.10))
                        )
                }
                Spacer()
                Text("Hover to preview · Click to snap")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8),
                spacing: 6
            ) {
                ForEach(SnapZone.allCases) { zone in
                    Button {
                        windowManager.snapActiveWindow(to: zone)
                        dashboardVM.stageSnapZone = zone
                    } label: {
                        SnapZoneDiagram(
                            zone: zone,
                            width: 23,
                            height: 15,
                            isActive: windowManager.targetWindowDetails?.lastZone == zone
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.slotrCardBg(colorScheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(
                                    windowManager.targetWindowDetails?.lastZone == zone
                                        ? Color.slotrBlue.opacity(0.75)
                                        : Color.slotrBorder(colorScheme),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help(zone.title)
                    .onHover { hovering in
                        dashboardVM.hoveredSnapZone = hovering ? zone : nil
                    }
                }

                Button {
                    windowManager.restoreOriginalWindowSize()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.slotrCardBg(colorScheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Restore original window size and position (⌃⌥↓)")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.slotrCardBg(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
        )
    }
    
    private func filterSegmentButton(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: active ? .semibold : .medium))
                .foregroundColor(active ? .primary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(active ? Color.slotrCardBg(colorScheme) : Color.clear)
                )
                .shadow(color: active ? Color.black.opacity(0.06) : .clear, radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func carouselStepButtons(
        onPrev: @escaping () -> Void,
        onNext: @escaping () -> Void,
        previousEnabled: Bool = true,
        nextEnabled: Bool = true
    ) -> some View {
        HStack(spacing: 4) {
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.slotrCardBg(colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!previousEnabled)
            .opacity(previousEnabled ? 1 : 0.45)
            
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.slotrCardBg(colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!nextEnabled)
            .opacity(nextEnabled ? 1 : 0.45)
        }
    }
    
    // MARK: - Tab 2: Quick Snap Studio
    
    private var quickSnapTabContent: some View {
        let previewZone = dashboardVM.hoveredSnapZone ?? windowManager.targetWindowDetails?.lastZone ?? dashboardVM.stageSnapZone
        
        return VStack(alignment: .leading, spacing: 20) {
            SnapGridButtons(
                activeZone: previewZone,
                onHoverZone: { zone in
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        dashboardVM.hoveredSnapZone = zone
                    }
                },
                onSnapZone: { zone in
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        dashboardVM.stageSnapZone = zone
                    }
                }
            )
            
            activeDisplayStage(zone: previewZone)
        }
    }
    
    private func activeDisplayStage(zone: SnapZone) -> some View {
        let liveTarget = windowManager.targetWindowDetails
        let isHoverPreview = (dashboardVM.hoveredSnapZone != nil)
        let screen: NSScreen? = {
            if let liveFrame = liveTarget?.frame {
                return windowManager.getScreen(for: liveFrame)
            }
            return NSScreen.main ?? NSScreen.screens.first
        }()
        let usable = screen.map { windowManager.getQuartzUsableRect(for: $0) } ?? CGRect(x: 0, y: 28, width: 1512, height: 954)
        
        let stageRect: CGRect = {
            if isHoverPreview {
                return zone.targetFrame(for: usable, gap: CGFloat(settings.windowGapPadding.rawValue))
            }
            if let liveFrame = liveTarget?.frame {
                return liveFrame
            }
            return zone.targetFrame(for: usable, gap: CGFloat(settings.windowGapPadding.rawValue))
        }()
        
        let normalizedStageRect: CGRect = {
            if isHoverPreview || liveTarget == nil {
                return zone.normalizedPreviewRect
            }
            let nx = max(0, min(0.92, (stageRect.minX - usable.minX) / max(1, usable.width)))
            let ny = max(0, min(0.92, (stageRect.minY - usable.minY) / max(1, usable.height)))
            let nw = max(0.10, min(1.0 - nx, stageRect.width / max(1, usable.width)))
            let nh = max(0.12, min(1.0 - ny, stageRect.height / max(1, usable.height)))
            return CGRect(x: nx, y: ny, width: nw, height: nh)
        }()
        
        let targetAppName = liveTarget?.appName ?? "Target Window"
        let targetWinTitle = liveTarget?.title ?? "Ready to Snap"
        let stageSubtitle = isHoverPreview ? zone.title : (liveTarget?.lastZone?.title ?? "Current Position")
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Active Display Stage")
                    .font(.system(size: 12.5, weight: .semibold))
                
                if let activeDesktop = selectedDesktop {
                    Text("• \(activeDesktop.displayName)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("x: \(Int(stageRect.minX)), y: \(Int(stageRect.minY)), w: \(Int(stageRect.width)), h: \(Int(stageRect.height))")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                let screenAspect = max(0.50, min(2.9, usable.width / max(1, usable.height)))
                let fittedW = usable.height > usable.width
                    ? min(geo.size.width, geo.size.height * screenAspect)
                    : geo.size.width
                let fittedH = usable.height > usable.width
                    ? geo.size.height
                    : min(geo.size.height, max(160, geo.size.width / screenAspect))
                let menuH: CGFloat = 22
                let pad: CGFloat = 8
                let contentW = max(20, fittedW - pad * 2)
                let contentH = max(20, fittedH - menuH - pad * 2)
                
                ZStack {
                    Color.slotrSubtleSurface(colorScheme)
                    
                    ZStack(alignment: .topLeading) {
                        SequoiaWallpaperView(variant: 0)
                        
                        // Simulated macOS Menu Bar
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 10))
                            Text(targetAppName)
                                .font(.system(size: 10, weight: .semibold))
                            if fittedW > 260 {
                                Text("File   Edit   View")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            Spacer()
                            Image(systemName: "rectangle.split.2x1")
                                .font(.system(size: 10))
                            Text("Slotr")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(height: menuH)
                        .background(Color.black.opacity(0.26))
                        
                        // Animated Preview Window
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 5) {
                                Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 7, height: 7)
                                Circle().fill(Color(red: 0.99, green: 0.74, blue: 0.18)).frame(width: 7, height: 7)
                                Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25)).frame(width: 7, height: 7)
                                Spacer()
                                Text("\(targetAppName) — \(stageSubtitle)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 22)
                            .background(Color.slotrSubtleSurface(colorScheme))
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(targetAppName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(targetWinTitle.isEmpty ? "Zone: \(stageSubtitle)" : targetWinTitle)
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(10)
                        }
                        .frame(
                            width: max(60, normalizedStageRect.width * contentW),
                            height: max(50, normalizedStageRect.height * contentH)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.slotrCardBg(colorScheme).opacity(0.95))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.6), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 4)
                        .offset(
                            x: pad + normalizedStageRect.minX * contentW,
                            y: menuH + pad + normalizedStageRect.minY * contentH
                        )
                        .animation(.spring(response: 0.30, dampingFraction: 0.84), value: normalizedStageRect)
                    }
                    .frame(width: fittedW, height: fittedH)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Tab 3: Global Shortcuts
    
    private var shortcutsTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Workspace Recall & Capture")
                    .font(.system(size: 13.5, weight: .semibold))
                Text("Trigger any saved desktop slot globally from any Space.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                
                groupedCard {
                    shortcutRow(title: "Recall Workspace Slots 1 – 8", keys: ["⌃", "⌥", "1..8"])
                    Divider().padding(.horizontal, 14)
                    shortcutRow(title: "Capture Current Space to Slot 1 – 8", keys: ["⌃", "⌥", "⇧", "1..8"])
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Window Snapping")
                    .font(.system(size: 13.5, weight: .semibold))
                Text("Instant window tiling shortcuts for the active frontmost window.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                
                groupedCard {
                    shortcutRow(title: "Snap Left Half / Right Half", keys: ["⌃", "⌥", "← / →"])
                    Divider().padding(.horizontal, 14)
                    shortcutRow(title: "Maximize Window", keys: ["⌃", "⌥", "↑ / ↩"])
                    Divider().padding(.horizontal, 14)
                    shortcutRow(title: "Center Window", keys: ["⌃", "⌥", "C"])
                    Divider().padding(.horizontal, 14)
                    shortcutRow(title: "Restore Original Size & Position", keys: ["⌃", "⌥", "↓"])
                }
            }
        }
    }
    
    private func shortcutRow(title: String, keys: [String]) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
            ShortcutKeySequence(keys)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
    
    // MARK: - Tab 4: Settings
    
    private var settingsTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("General & Startup")
                    .font(.system(size: 13.5, weight: .semibold))
                
                groupedCard {
                    settingToggleRow(
                        title: "Launch Slotr at login",
                        subtitle: "Automatically start in the Menu Bar when you log into your Mac.",
                        isOn: Binding(
                            get: { viewModel.launchAtLogin },
                            set: { viewModel.toggleLaunchAtLogin($0) }
                        )
                    )
                    Divider().padding(.horizontal, 14)
                    settingToggleRow(
                        title: "Show Slotr icon in Menu Bar",
                        subtitle: "Quickly recall workspaces and snap windows without opening this window.",
                        isOn: Binding(
                            get: { settings.showMenuBarIcon },
                            set: { newValue in
                                settings.showMenuBarIcon = newValue
                                AppDelegate.shared?.setStatusItemVisible(newValue)
                            }
                        )
                    )
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Workspace Recall Behavior")
                    .font(.system(size: 13.5, weight: .semibold))
                
                groupedCard {
                    settingToggleRow(
                        title: "Auto-launch closed apps on Recall",
                        subtitle: "If an app saved in a slot isn't running, open it before tiling.",
                        isOn: $settings.autoLaunchClosedApps
                    )
                    Divider().padding(.horizontal, 14)
                    settingToggleRow(
                        title: "Hide Slotr window after recalling a slot",
                        subtitle: "Focus immediately on your restored workspace apps.",
                        isOn: $settings.hideWindowAfterRecall
                    )
                    Divider().padding(.horizontal, 14)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Window Gap Padding")
                                .font(.system(size: 12.5, weight: .semibold))
                            Text("Leave clean breathing room between snapped windows.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.windowGapPadding) {
                            ForEach(WindowGapPadding.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 145)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("About Slotr")
                    .font(.system(size: 13.5, weight: .semibold))

                groupedCard {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            SlotrLogoMark(size: 38)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Slotr")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("Spaces & Window Snap")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("Version \(appVersion)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        Divider().padding(.horizontal, 14)

                        HStack {
                            Text("Developer")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Suriya Prakhash Deenadayalan")
                                .font(.system(size: 11.5))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        Divider().padding(.horizontal, 14)

                        HStack {
                            Text("License")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("MIT License")
                                .font(.system(size: 11.5))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        Divider().padding(.horizontal, 14)

                        HStack(spacing: 12) {
                            Text("More information and latest updates")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Link(destination: URL(string: "https://www.slotr.suriyaprakhash.com")!) {
                                Label("Visit website", systemImage: "arrow.up.right")
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }
    
    private func settingToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.checkbox)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
    
    private func groupedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.slotrCardBg(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
        )
    }
}

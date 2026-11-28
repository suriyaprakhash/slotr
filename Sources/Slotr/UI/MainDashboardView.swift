import SwiftUI
import ApplicationServices

public enum DashboardTab: String, CaseIterable, Identifiable {
    case workspaces = "Workspaces"
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
        case .workspaces: return "Workspaces & Live Spaces"
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
    @Published public var filmRollSelectedOnly: Bool = false
    @Published public var showingMenuBarPreview: Bool = false
    @Published public var hoveredSnapZone: SnapZone? = nil
    @Published public var hoveredCardZone: SnapZone? = nil
    @Published public var stageSnapZone: SnapZone = .leftHalf
    
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
    
    private var selectedDesktop: DesktopInfo? {
        if let id = dashboardVM.selectedDesktopID,
           let match = desktopManager.desktops.first(where: { $0.id == id }) {
            return match
        }
        return desktopManager.desktops.first(where: { $0.isCurrent }) ?? desktopManager.desktops.first
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
                .frame(width: 236)
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
            // Traffic light row + version tag
            HStack {
                Spacer()
                Text("v1.0")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.75))
            }
            .padding(.top, 12)
            
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
            .padding(.bottom, 4)
            
            // Sidebar Navigation
            VStack(spacing: 3) {
                ForEach(DashboardTab.allCases) { tab in
                    sidebarNavButton(for: tab)
                }
            }
            
            Spacer(minLength: 10)
            
            // Target Window Inspector Card
            targetWindowInspectorCard
            
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
                    Text("\(filledSlotCount)/8")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.22) : Color.slotrSubtleSurface(colorScheme))
                        )
                } else if tab == .quickSnap {
                    Text("⌃⌥←")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary.opacity(0.75))
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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(dashboardVM.selectedTab.pageTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("— \(dashboardVM.selectedTab.pageSubtitle)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                windowManager.refreshTargetWindow()
                dashboardVM.showingMenuBarPreview.toggle()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.split.2x1.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.slotrBlue)
                    Text("Menu Bar Preview")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.slotrCardBg(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            dashboardVM.showingMenuBarPreview ? Color.orange.opacity(0.8) : Color.slotrBorder(colorScheme),
                            lineWidth: dashboardVM.showingMenuBarPreview ? 1.5 : 1
                        )
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $dashboardVM.showingMenuBarPreview, arrowEdge: .bottom) {
                MenuBarView(isPreview: true) {
                    dashboardVM.showingMenuBarPreview = false
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }
    
    // MARK: - Tab 1: Workspaces & Live Spaces
    
    private var workspacesTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section 1: Current Desktops
            currentDesktopsSection
            
            // Section 2: Target Windows Film Roll
            targetWindowsFilmRollSection
            
            // Section 3: 8 Workspace Layout Slots
            workspaceSlotsGridSection
        }
    }
    
    private var currentDesktopsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollViewReader { proxy in
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("Current Desktops")
                                .font(.system(size: 13.5, weight: .semibold))
                            
                            Text("\(desktopManager.desktops.count) Desktops")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(.slotrBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.slotrBlue.opacity(colorScheme == .dark ? 0.18 : 0.11))
                                .cornerRadius(99)
                        }
                        
                        Text("Click a Desktop to inspect its windows. Double-click to switch to that Space.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            if let desktop = selectedDesktop {
                                desktopManager.slotIt(desktop)
                            }
                        }) {
                            Text("+ Capture Selected Desktop")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5.5)
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
                        .disabled(selectedDesktop?.isEmpty ?? true)
                        
                        carouselStepButtons(
                            onPrev: {
                                if let first = desktopManager.desktops.first {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        proxy.scrollTo(first.id, anchor: .leading)
                                    }
                                }
                            },
                            onNext: {
                                if let last = desktopManager.desktops.last {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        proxy.scrollTo(last.id, anchor: .trailing)
                                    }
                                }
                            }
                        )
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if desktopManager.desktops.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "square.on.square")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Text(desktopManager.isAvailable
                                     ? "Detecting Desktops…"
                                     : "Desktop Detection Unavailable")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 30)
                            .padding(.horizontal, 16)
                        } else {
                            ForEach(desktopManager.desktops) { desktop in
                                DesktopCardView(
                                    desktop: desktop,
                                    isSelected: selectedDesktop?.id == desktop.id,
                                    onSelect: {
                                        dashboardVM.selectedDesktopID = desktop.id
                                    },
                                    onNavigate: {
                                        desktopManager.switchToDesktop(desktop)
                                    }
                                )
                                .id(desktop.id)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
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
                        // All Spaces vs Selected Desktop Only segmented pill
                        HStack(spacing: 2) {
                            filterSegmentButton(title: "All Spaces", active: !dashboardVM.filmRollSelectedOnly) {
                                dashboardVM.filmRollSelectedOnly = false
                            }
                            let label = selectedDesktop.map { "Desktop \($0.index + 1) Only" } ?? "Selected Only"
                            filterSegmentButton(title: label, active: dashboardVM.filmRollSelectedOnly) {
                                dashboardVM.filmRollSelectedOnly = true
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
    
    private var workspaceSlotsGridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("8 Workspace Layout Slots")
                        .font(.system(size: 13.5, weight: .semibold))
                    
                    HStack(spacing: 4) {
                        Text("Click Recall or press")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                        MacKeycapBadge("⌃⌥1–8", compact: true)
                        Text("to restore all apps and window positions.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("Double-click any slot name to rename")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(slotManager.slots) { slot in
                    SlotCardView(slot: slot, selectedDesktop: selectedDesktop)
                }
            }
        }
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
    
    private func carouselStepButtons(onPrev: @escaping () -> Void, onNext: @escaping () -> Void) -> some View {
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

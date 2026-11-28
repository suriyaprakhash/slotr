import SwiftUI

public struct DesktopCardView: View {
    let desktop: DesktopInfo
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    var onNavigate: (() -> Void)? = nil
    
    @ObservedObject var desktopManager = DesktopManager.shared
    @ObservedObject var slotManager = SlotManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    public init(desktop: DesktopInfo, isSelected: Bool = false, onSelect: (() -> Void)? = nil, onNavigate: (() -> Void)? = nil) {
        self.desktop = desktop
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onNavigate = onNavigate
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: status dot + Desktop name + orientation icon + window count
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                
                Text(desktop.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                HStack(spacing: 4) {
                    Image(systemName: desktop.orientation.iconName)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("\(desktop.windows.count)w")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .help("\(desktop.orientation.label) display")
            }
            
            // Orientation-Aware Visual Thumbnail Preview
            previewStage
            
            // Footer: App Icons + Save to Slot Menu
            HStack(spacing: 6) {
                if desktop.isEmpty {
                    Text("No open apps")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .italic()
                    
                    Spacer()
                    
                    Text("No Apps")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.slotrSubtleSurface(colorScheme))
                        .cornerRadius(6)
                } else {
                    let apps = desktop.uniqueApps
                    HStack(spacing: -4) {
                        ForEach(apps.prefix(4)) { app in
                            Image(nsImage: desktopManager.icon(for: app))
                                .resizable()
                                .frame(width: 18, height: 18)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.slotrCardBg(colorScheme), lineWidth: 1)
                                )
                                .help(app.appName)
                        }
                    }
                    
                    if apps.count > 4 {
                        Text("+\(apps.count - 4)")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button("First Empty Slot") {
                            desktopManager.slotIt(desktop)
                        }
                        Divider()
                        ForEach(slotManager.slots) { slot in
                            Button {
                                desktopManager.saveDesktop(desktop, toSlotId: slot.id)
                            } label: {
                                Text(slot.isEmpty ? "Slot \(slot.id) (Empty)" : "Overwrite Slot \(slot.id) — \(slot.name)")
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("Save to Slot")
                                .font(.system(size: 10.5, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.slotrBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.slotrBlue.opacity(colorScheme == .dark ? 0.18 : 0.10))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
        .padding(10)
        .frame(width: 218)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.slotrCardBg(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected ? Color.slotrBlue : Color.slotrBorder(colorScheme),
                    lineWidth: isSelected ? 1.8 : 1
                )
        )
        .shadow(
            color: isSelected ? Color.slotrBlue.opacity(0.14) : Color.black.opacity(colorScheme == .dark ? 0.18 : 0.04),
            radius: isSelected ? 6 : 2,
            x: 0,
            y: 1
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onNavigate?()
        }
        .onTapGesture(count: 1) {
            onSelect?()
        }
    }
    
    private var previewStage: some View {
        let stageSize = fittedPreviewSize(maxWidth: 198, maxHeight: 68)
        
        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.slotrSubtleSurface(colorScheme).opacity(0.65))
            
            if desktop.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.slotrSubtleSurface(colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.slotrBorder(colorScheme), lineWidth: 0.75)
                        )
                    Text("Empty")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: stageSize.width, height: stageSize.height)
            } else {
                MiniLayoutPreview(
                    frames: desktop.windows.map(\.frame),
                    referenceBounds: desktop.displayBounds,
                    variant: desktop.index,
                    cornerRadius: 6
                )
                .frame(width: stageSize.width, height: stageSize.height)
            }
        }
        .frame(width: 198, height: 68)
    }
    
    private func fittedPreviewSize(maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        let bounds = desktop.displayBounds
        let aspect: CGFloat
        if bounds.width > 100 && bounds.height > 100 {
            aspect = bounds.width / bounds.height
        } else {
            switch desktop.orientation {
            case .landscape: aspect = 16.0 / 10.0
            case .portrait: aspect = 10.0 / 16.0
            case .square: aspect = 1.0
            }
        }
        let clampedAspect = max(0.50, min(2.9, aspect))
        let widthAtMaxHeight = maxHeight * clampedAspect
        if widthAtMaxHeight <= maxWidth {
            return CGSize(width: max(34, widthAtMaxHeight), height: maxHeight)
        } else {
            return CGSize(width: maxWidth, height: max(36, maxWidth / clampedAspect))
        }
    }
    
    private var statusColor: Color {
        if desktop.isCurrent { return .slotrBlue }
        if !desktop.isEmpty { return .green }
        return .secondary.opacity(0.45)
    }
}

public struct TargetWindowFilmCardView: View {
    let window: DesktopWindow
    let spaceOrdinal: Int
    var displayBounds: CGRect = .zero
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    
    @ObservedObject var desktopManager = DesktopManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        window: DesktopWindow,
        spaceOrdinal: Int,
        displayBounds: CGRect = .zero,
        isSelected: Bool = false,
        onSelect: (() -> Void)? = nil
    ) {
        self.window = window
        self.spaceOrdinal = spaceOrdinal
        self.displayBounds = displayBounds
        self.isSelected = isSelected
        self.onSelect = onSelect
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(nsImage: desktopManager.icon(for: window))
                    .resizable()
                    .frame(width: 18, height: 18)
                    .cornerRadius(4)
                
                Text(window.appName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                Text("D\(spaceOrdinal)")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isSelected ? Color.slotrBlue : Color.slotrSubtleSurface(colorScheme))
                    )
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(window.windowName.isEmpty ? window.appName : window.windowName)
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text("\(Int(window.frame.width)) × \(Int(window.frame.height))")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.85))
                }
                
                Spacer(minLength: 4)
                
                miniWindowPositionThumb
            }
        }
        .padding(10)
        .frame(width: 204)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.slotrCardBg(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(
                    isSelected ? Color.slotrBlue : Color.slotrBorder(colorScheme),
                    lineWidth: isSelected ? 1.6 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect?()
        }
    }
    
    private var miniWindowPositionThumb: some View {
        let bounds: CGRect = {
            if displayBounds.width > 100 && displayBounds.height > 100 {
                return displayBounds
            }
            let primarySize = NSScreen.screens.first?.frame.size ?? CGSize(width: 1512, height: 982)
            return CGRect(origin: .zero, size: primarySize)
        }()
        
        let normX = max(0, min(0.82, (window.frame.minX - bounds.minX) / max(1, bounds.width)))
        let normY = max(0, min(0.82, (window.frame.minY - bounds.minY) / max(1, bounds.height)))
        let normW = max(0.16, min(1.0 - normX, window.frame.width / max(1, bounds.width)))
        let normH = max(0.18, min(1.0 - normY, window.frame.height / max(1, bounds.height)))
        
        let aspect = max(0.55, min(2.4, bounds.width / max(1, bounds.height)))
        let maxH: CGFloat = 24
        let maxW: CGFloat = 38
        let thumbW = min(maxW, maxH * aspect)
        let thumbH = min(maxH, thumbW / aspect)
        
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.slotrSubtleSurface(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.slotrBorder(colorScheme), lineWidth: 0.75)
                    )
                
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? Color.slotrBlue : Color.primary.opacity(0.55))
                    .frame(width: max(5, normW * (w - 4)), height: max(5, normH * (h - 4)))
                    .offset(x: 2 + normX * (w - 4), y: 2 + normY * (h - 4))
            }
        }
        .frame(width: thumbW, height: thumbH)
    }
}

import SwiftUI

public struct SnapGridButtons: View {
    @ObservedObject var windowManager = WindowManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var activeZone: SnapZone? = nil
    var onHoverZone: ((SnapZone?) -> Void)? = nil
    var onSnapZone: ((SnapZone) -> Void)? = nil
    
    public init(
        activeZone: SnapZone? = nil,
        onHoverZone: ((SnapZone?) -> Void)? = nil,
        onSnapZone: ((SnapZone) -> Void)? = nil
    ) {
        self.activeZone = activeZone
        self.onHoverZone = onHoverZone
        self.onSnapZone = onSnapZone
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Halves & Full
            sectionBlock(title: "Halves & Full") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 10
                ) {
                    snapCard(.leftHalf, shortcut: "⌃⌥←")
                    snapCard(.maximize, shortcut: "⌃⌥↩")
                    snapCard(.rightHalf, shortcut: "⌃⌥→")
                    snapCard(.topHalf)
                    snapCard(.center, shortcut: "⌃⌥C")
                    snapCard(.bottomHalf)
                }
            }
            
            // Quarters (Corners)
            sectionBlock(title: "Quarters (Corners)") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                    spacing: 10
                ) {
                    snapCard(.topLeftQuarter)
                    snapCard(.topRightQuarter)
                    snapCard(.bottomLeftQuarter)
                    snapCard(.bottomRightQuarter)
                }
            }
            
            // Thirds & Two-Thirds
            sectionBlock(title: "Thirds & Two-Thirds") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 10
                ) {
                    snapCard(.leftThird)
                    snapCard(.centerThird)
                    snapCard(.rightThird)
                    snapCard(.leftTwoThirds)
                    snapCard(.rightTwoThirds)
                }
            }
            
            // Restore Original Size & Position
            Button(action: {
                windowManager.restoreOriginalWindowSize()
                onHoverZone?(nil)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Restore Original Size & Position")
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer()
                    MacKeycapBadge("⌃⌥↓", compact: true)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.slotrCardBg(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func sectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.primary)
            content()
        }
    }
    
    private func snapCard(_ zone: SnapZone, shortcut: String? = nil) -> some View {
        SnapZoneCardButton(
            zone: zone,
            shortcut: shortcut,
            isActive: activeZone == zone,
            onHover: { hovering in
                onHoverZone?(hovering ? zone : nil)
            },
            onTap: {
                windowManager.snapActiveWindow(to: zone)
                onSnapZone?(zone)
            }
        )
    }
}

private struct SnapZoneCardButton: View {
    let zone: SnapZone
    var shortcut: String? = nil
    var isActive: Bool = false
    var onHover: (Bool) -> Void
    var onTap: () -> Void
    
    @ObservedObject private var dashboardVM = DashboardViewModel.shared
    @Environment(\.colorScheme) private var colorScheme
    
    private var isHovered: Bool {
        dashboardVM.hoveredCardZone == zone
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                SnapZoneDiagram(zone: zone, width: 26, height: 18, isActive: isActive || isHovered)
                
                Text(zone.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text(" ")
                        .font(.system(size: 9.5))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.slotrCardBg(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        (isActive || isHovered) ? Color.slotrBlue.opacity(0.75) : Color.slotrBorder(colorScheme),
                        lineWidth: (isActive || isHovered) ? 1.5 : 1
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.03), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                dashboardVM.hoveredCardZone = zone
            } else if dashboardVM.hoveredCardZone == zone {
                dashboardVM.hoveredCardZone = nil
            }
            onHover(hovering)
        }
        .help(shortcut != nil ? "\(zone.title) (\(shortcut!))" : zone.title)
    }
}
